# Writes the occurrences of the household's chores for a local week (lot 4),
# from what each chore says about itself: `frequency`, `times_per_period` and
# `anchor_on` (see Recurrence). Everything is read in the household's time
# zone, through Week.
#
#   RecurringChoreScheduler.sync_chore(chore)         one chore, current week
#   RecurringChoreScheduler.sync_household(household) every chore of one home
#   RecurringChoreScheduler.run_all                   every household (the job)
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
  def self.run_all
    Household.where(id: Chore.active.select(:household_id)).find_each { |household| sync_household(household) }
  end

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
