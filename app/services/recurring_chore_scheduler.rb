# Writes the occurrences of the household's chores for a local week (lot 4),
# from what each chore says about itself: `frequency`, `times_per_period` and
# `anchor_on` (see Recurrence). Everything is read in the household's time
# zone, through Week.
#
#   RecurringChoreScheduler.sync_chore(chore)         one chore, current week
#   RecurringChoreScheduler.sync_household(household) every chore of one home
#   RecurringChoreScheduler.run_household(household)  one home, its current week,
#                                                     then marked as done for it
#   RecurringChoreScheduler.enqueue_due               the dispatcher (below)
#   RecurringChoreScheduler.run_all                   every household, inline
#                                                     (dev, tests, runner)
#
# Fan-out: ChoreSchedulerDispatchJob (every 15 min) calls enqueue_due, which
# picks the households whose current local week was not scheduled yet
# (households.chores_scheduled_week < the Monday of their zone), zone by zone:
# the local Monday is computed once per distinct time zone, and the selection
# is a range scan on (time_zone, chores_scheduled_week). Households without
# an active chore are marked in one UPDATE; the others get one
# HouseholdChoreSchedulerJob each, in batches (perform_all_later), claimed
# like EngineCycle's households. A chore saved mid-week schedules itself
# (sync_chore), so nothing else has to wake the household.
#
# Idempotent: a slot is (chore, week, index) under a unique index, so a rerun,
# a concurrent run or a chore saved twice writes nothing new. When a chore
# changes mid-week the open occurrences follow it (moved, added, removed);
# one that already has a log is never touched, it is history.
#
# A chore starts on the day it was made: no occurrence is written for the
# days before it (nothing is « late » on the day a chore is created).
class RecurringChoreScheduler
  def self.sync_chore(chore, week = chore.household.current_week)
    new(chore, week).sync
  end

  def self.sync_household(household, week = household.current_week)
    household.chores.find_each do |chore|
      chore.association(:household).target = household
      sync_chore(chore, week)
    end
  end

  # Every household with a chore, each in its own current week.
  def self.run_all(now: Time.current)
    Household.where(id: Chore.active.select(:household_id)).find_each { |household| run_household(household, now: now) }
  end

  def self.run_household(household, now: Time.current)
    week = household.week_containing(now)
    sync_household(household, week)
    Household.where(id: household.id).update_all(chores_scheduled_week: week.monday, chores_claimed_at: nil)
  end

  BATCH_SIZE = 1_000
  CLAIM_TTL = 30.minutes

  # Returns how many households were enqueued.
  def self.enqueue_due(now: Time.current, batch_size: BATCH_SIZE)
    total = 0
    Household.distinct.pluck(:time_zone).each do |time_zone|
      monday = Week.containing(now, time_zone).monday
      mark_without_chores(time_zone, monday)
      loop do
        ids = claim_due(time_zone, monday, now, batch_size)
        break if ids.empty?

        ActiveJob.perform_all_later(ids.map { |id| HouseholdChoreSchedulerJob.new(id) })
        total += ids.size
        break if ids.size < batch_size
      end
    rescue ArgumentError => e # a household with an unknown time zone: skip its zone
      Rails.error.report(e, context: { time_zone: time_zone })
    end
    total
  end

  def self.mark_without_chores(time_zone, monday)
    Household.where(time_zone: time_zone)
             .where("chores_scheduled_week IS NULL OR chores_scheduled_week < ?", monday)
             .where.not(id: Chore.active.select(:household_id))
             .update_all(chores_scheduled_week: monday)
  end

  def self.claim_due(time_zone, monday, now, limit)
    sql = Household.sanitize_sql_array([ <<~SQL, { zone: time_zone, monday: monday, now: now, stale: now - CLAIM_TTL, limit: limit } ])
      UPDATE households SET chores_claimed_at = :now
      WHERE id IN (
        SELECT id FROM households
        WHERE time_zone = :zone
          AND (chores_scheduled_week IS NULL OR chores_scheduled_week < :monday)
          AND (chores_claimed_at IS NULL OR chores_claimed_at < :stale)
        LIMIT :limit
        FOR UPDATE SKIP LOCKED
      )
      RETURNING id
    SQL
    # Uncached: the query cache (on inside jobs) would replay the UPDATE's result.
    Household.uncached { Household.connection.select_values(sql) }
  end
  private_class_method :mark_without_chores, :claim_due

  def initialize(chore, week)
    @chore = chore
    @week = week
  end

  def sync
    ChoreOccurrence.transaction do
      remove_stale
      write_missing
    end
  end

  # { slot => date } the chore plans in the week. Empty when retired.
  def planned
    @planned ||= begin
      dates = @chore.active? ? Recurrence.due_dates(
        frequency: @chore.frequency, times_per_period: @chore.times_per_period,
        anchor_on: @chore.anchor_on, week: @week, base_on: started_on
      ) : []
      dates.each_with_index.reject { |date, _| @chore.repeating? && date < started_on }.to_h { |date, slot| [ slot, date ] }
    end
  end

  private

  def started_on
    @started_on ||= @chore.created_at.in_time_zone(@week.time_zone).to_date
  end

  def existing
    @existing ||= ChoreOccurrence.where(chore_id: @chore.id, week_start: @week.monday).includes(:chore_logs).index_by(&:slot)
  end

  def remove_stale
    existing.each do |slot, occurrence|
      next if occurrence.chore_logs.any?

      if !planned.key?(slot)
        occurrence.destroy
      elsif occurrence.due_on != planned[slot]
        occurrence.update!(due_on: planned[slot])
      end
    end
  end

  def write_missing
    rows = planned.except(*existing.keys).map do |slot, date|
      { household_id: @chore.household_id, chore_id: @chore.id, week_start: @week.monday, slot: slot, due_on: date }
    end
    return if rows.empty?

    ChoreOccurrence.insert_all(rows, unique_by: :index_chore_occurrences_unique_slot)
  end
end
