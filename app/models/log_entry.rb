# What a person fills in to log a task (D6, D7, D10) or to correct a log
# (E12). Not persisted: it checks the rules, then writes one ChoreLog.
#
#   entry = LogEntry.new(user: current_user, chore_id: 4, mental_load: true,
#                        time_spent: 20, day: "2026-11-06", idempotency_key: "…")
#   entry.save   # => true / false (entry.errors)
#   entry.log    # => the ChoreLog (an earlier one when the key was already used)
#
#   LogEntry.update(log, user: current_user, time_spent: 25)   # E12
#
# Rules (docs/plan-de-travail.md, lot 4):
# - The author is `user`, always: nobody logs on someone else's behalf.
# - The day is today or up to MAX_DAYS_BACK days back, read in the household's
#   zone. A log in a week whose final report is stored goes to the journal and
#   leaves the report as it is (ChoreLog#counts_in_report?).
# - A task not in the household (or retired) is refused. No task at all is
#   fine: a name and a category typed by hand, logged « hors répartition » (D6),
#   like a task that was not in the week's split (D14), see `off_split`.
# - At least one load, a duration of 1 minute or more.
# - The idempotency key makes a double tap, or a « Réessayer » after an error,
#   write one log: a second submit with the same key returns the first log.
class LogEntry
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_DAYS_BACK = 7
  STEP_MINUTES = 5
  MAX_MINUTES = 24 * 60

  attribute :chore_id, :integer
  attribute :occurrence_id, :integer
  attribute :custom_name, :string
  attribute :category, :string
  attribute :mental_load, :boolean, default: false
  attribute :execution_load, :boolean, default: false
  attribute :time_spent, :integer
  attribute :day, :date
  attribute :idempotency_key, :string

  attr_reader :user, :log

  def self.model_name
    ActiveModel::Name.new(self, nil, "LogEntry")
  end

  def self.update(log, user:, **attributes)
    new(user: user, log: log, **attributes).update
  end

  # `user`: the author. `log`: set when correcting an existing log.
  def initialize(user:, log: nil, **attributes)
    @user = user
    @log = log
    super(attributes)
  end

  def household
    user.household
  end

  def zone
    log ? ActiveSupport::TimeZone[log.time_zone] : household&.zone || ActiveSupport::TimeZone["Europe/Paris"]
  end

  def today
    zone.today
  end

  # The day it is for: the one given, else the log's own (an edit), else today.
  def day
    super || log&.completed_on || today
  end

  def chore
    return @chore if defined?(@chore)

    @chore = household&.chores&.active&.find_by(id: chore_id) if chore_id
  end

  # The days that can be picked, today first.
  def selectable_days
    (0..MAX_DAYS_BACK).map { |back| today - back }
  end

  # True once the same key was used: nothing new was written.
  def duplicate?
    @duplicate == true
  end

  def save
    existing = existing_log
    if existing
      @log = existing
      @duplicate = true
      return true
    end

    return false unless valid_for_create?

    @log = ChoreLog.new(user: user, household: household, chore: chore, occurrence: occurrence,
                        chore_name: chore&.effective_name || custom_name.to_s.squish,
                        category: chore&.effective_category || category.presence || "other",
                        mental_load: mental_load, execution_load: execution_load,
                        time_spent: time_spent, completed_at: completed_at_for(day),
                        idempotency_key: idempotency_key.presence, off_split: off_split?)
    @log.save || copy_errors
  rescue ActiveRecord::RecordNotUnique
    # A second tap raced the first one past the check above.
    @log = existing_log
    @duplicate = true
    @log.present?
  end

  # E12: loads, duration and day of a log of the author's own.
  def update
    return forbid unless log&.author?(user)

    @editing = true
    validate_loads
    validate_time
    # A week whose report is final keeps the day: only the journal changes.
    validate_day unless day_locked?
    return false if errors.any?

    attributes = { mental_load: mental_load, execution_load: execution_load, time_spent: time_spent }
    attributes[:completed_at] = completed_at_for(day, keep_clock_of: log.completed_at) unless day_locked?
    log.update(attributes) || copy_errors
  end

  # E12 shows the day as fixed when the week is closed.
  def day_locked?
    log.present? && !log.counts_in_report? && log.household_id.present?
  end

  # Whether the week a day falls in still counts in its report (its final
  # report is not stored yet). Otherwise the log only reaches the journal.
  def week_open?(date = day)
    household.nil? || !HouseholdWeek.final.exists?(household_id: household.id, week_start: week_of(date).monday)
  end

  def week_of(date)
    Week.containing(date, zone.name)
  end

  # Outside the split: no task behind it, or a task the week's plan does not
  # carry (added after the validation, D14).
  def off_split?
    return true if chore.nil?

    plan = household.week_plan_for(week_of(day))
    plan.present? && plan.planned_chore_ids.exclude?(chore.id)
  end

  def occurrence
    return @occurrence if defined?(@occurrence)

    @occurrence = (ChoreOccurrence.find_by(id: occurrence_id, chore_id: chore&.id, household_id: household&.id) if occurrence_id)
    # Only the person carrying it ticks it off, once.
    @occurrence = nil if @occurrence && (!chore.assigned_to?(user) || @occurrence.done_by?(user.id))
    @occurrence
  end

  private

  def existing_log
    return if idempotency_key.blank? || user.nil?

    ChoreLog.find_by(user_id: user.id, idempotency_key: idempotency_key)
  end

  def valid_for_create?
    errors.clear
    errors.add(:base, message(:no_household)) if household.nil?
    validate_task
    validate_loads
    validate_time
    validate_day
    errors.empty?
  end

  def validate_task
    return if household.nil?

    if chore_id.present?
      errors.add(:chore_id, message(:unknown_chore)) if chore.nil?
    elsif custom_name.to_s.squish.blank?
      errors.add(:custom_name, message(:name_blank))
    elsif custom_name.to_s.squish.length > Chore::CUSTOM_NAME_MAX_LENGTH
      errors.add(:custom_name, message(:name_long, max: Chore::CUSTOM_NAME_MAX_LENGTH))
    elsif category.present? && Chore::CATEGORIES.exclude?(category)
      errors.add(:category, message(:category_unknown))
    end
  end

  def validate_loads
    errors.add(:loads, message(:no_load)) unless mental_load || execution_load
  end

  def validate_time
    if time_spent.nil? || time_spent < 1
      errors.add(:time_spent, message(:time_blank))
    elsif time_spent > MAX_MINUTES
      errors.add(:time_spent, message(:time_long))
    end
  end

  def validate_day
    # An old log being corrected keeps its day: only a changed day is judged.
    return if log && day == log.completed_on

    first = today - MAX_DAYS_BACK
    if day > today
      errors.add(:day, message(:day_future))
    elsif day < first
      errors.add(:day, message(:day_too_old, days: MAX_DAYS_BACK))
    end
  end

  # The local day at the clock time of `keep_clock_of` (an edit keeps the
  # time of day), or now for today. Never later than now. Built from local
  # fields so a daylight-saving change does not move the day.
  def completed_at_for(date, keep_clock_of: nil)
    now = Time.current
    return now if date == today && keep_clock_of.nil?

    clock = (keep_clock_of || now).in_time_zone(zone)
    moment = zone.local(date.year, date.month, date.day, clock.hour, clock.min, clock.sec)
    [ moment, now ].min
  end

  def copy_errors
    log.errors.each { |error| errors.add(error.attribute, error.message) }
    false
  end

  def forbid
    errors.add(:base, message(:not_author))
    false
  end

  def message(key, **options)
    I18n.t("log_entries.errors.#{key}", **options)
  end
end
