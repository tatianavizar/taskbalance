# A declared absence of one member: from `starts_on`, until `ends_on`
# (inclusive) or open-ended. Any member can declare one, for themselves or for
# an absent member (`declared_by`), as many times as they want. A paused
# member is not an active member for any week the pause overlaps, even by one
# day *(default)*: that week never counts as empty for them, and they are left
# out of the fair share. `reason` is private to the member concerned.
#
# Whole weeks only, and never a week with a log (decision 2026-11-13): a pause
# cannot be created, nor extended, so that it covers a local week (household
# zone) in which the member already logged a task, current week included. A
# one-day pause on the Sunday would otherwise neutralise a weak week. The
# error names the next possible start, the Monday after the latest such week.
#
# Retroactive pauses are limited (product decisions 2026-11-08 and D3,
# 2026-11-12): the start can go back 14 days at most, or to the first week of
# an absence inquiry or regression about that member while it is open (until
# the next final report after its deadline). Over final weeks, the engine then
# records a correction and may cancel a regression (WeeklyEngine, D3).
class MemberPause < ApplicationRecord
  RETROACTIVE_DAYS = HouseholdRules::PAUSE_RETROACTIVE_DAYS

  belongs_to :household_member
  belongs_to :declared_by, class_name: "User", optional: true

  validates :starts_on, presence: true
  validate :ends_after_start
  validate :retroactive_limits, on: :create
  validate :covers_no_logged_week
  validate :declared_for_someone_else_stays_in_the_inquiry, if: :declared_for_someone_else?
  validate :extension_limits, on: :update

  after_create :notify_engine
  # Every pause path notifies through the outbox: the engine recorded
  # member_pause.declared (and any outcome); deliver it without waiting.
  after_create_commit { NotificationsDispatchJob.perform_later(household_member.household_id) }
  # New dates are announced like a declaration (member_pause.updated).
  after_update :announce_new_dates, if: :saved_change_to_dates?
  after_update_commit(if: :saved_change_to_dates?) { NotificationsDispatchJob.perform_later(household_member.household_id) }

  scope :overlapping, ->(week) {
    where(starts_on: ..week.sunday).where("member_pauses.ends_on IS NULL OR member_pauses.ends_on >= ?", week.monday)
  }

  def self.declare!(member:, declared_by:, starts_on:, ends_on: nil, reason: nil)
    create!(household_member: member, declared_by: declared_by, starts_on: starts_on, ends_on: ends_on, reason: reason)
  end

  def household
    household_member.household
  end

  def covers?(week)
    starts_on <= week.sunday && (ends_on.nil? || ends_on >= week.monday)
  end

  # The reason is shown to the member concerned only.
  def reason_for(user)
    reason if user && user.id == household_member.user_id
  end

  # A pause declared by someone other than the member (F8, or a « yes » to an
  # absence question).
  def declared_for_someone_else?
    declared_by_id.present? && declared_by_id != household_member&.user_id
  end

  # Only a pause that is current or in the future can be edited: a finished
  # one is history (closed weeks) and only a new declaration can change it.
  def editable?(today = household.zone.today)
    ends_on.nil? || ends_on >= today
  end

  # Ends the pause today, or removes it if it has not started yet.
  def cancel!(today = household.zone.today)
    return destroy! if starts_on > today

    update!(ends_on: [ ends_on, today ].compact.min)
  end

  private

  def ends_after_start
    errors.add(:ends_on, :before_start) if starts_on && ends_on && ends_on < starts_on
  end

  def saved_change_to_dates?
    saved_change_to_starts_on? || saved_change_to_ends_on?
  end

  # F8 (D3): a pause for someone else is bounded, with an end, to the weeks
  # of one open absence inquiry or regression about that member (first week
  # Monday to last week Sunday).
  def declared_for_someone_else_stays_in_the_inquiry
    return if starts_on.nil? || household_member.nil?
    return errors.add(:ends_on, :required_for_someone_else) if ends_on.nil?

    ranges = AbsenceInquiry.where(household_member_id: household_member_id)
      .select(&:correction_window_open?).map { |i| i.first_week_start..(i.last_week_start + 6) }
    return if ranges.any? { |range| range.cover?(starts_on) && range.cover?(ends_on) }

    errors.add(:base, :outside_inquiry_weeks)
  end

  # Extending a pause is a new declaration for the days it adds: same limits
  # as a creation. The days it adds are after today for a pause that can be
  # edited; closed weeks are refused (a new declaration goes through the D3
  # correction path, an edit does not).
  def extension_limits
    from = newly_covered_from
    return if from.nil?

    retroactive_limits(from)
    errors.add(:ends_on, :closed_weeks_need_declaration) if Week.containing(from, household.time_zone).end_at < Time.current
  end

  def newly_covered_from
    return starts_on if starts_on_changed? && starts_on_was && starts_on < starts_on_was
    return unless ends_on_changed? && ends_on_was && (ends_on.nil? || ends_on > ends_on_was)

    ends_on_was + 1
  end

  def retroactive_limits(from = starts_on)
    return if from.nil? || household_member.nil?

    zone = household.zone
    today = zone.today
    return unless from < today

    inquiry_start = AbsenceInquiry.where(household_member_id: household_member_id)
      .select { |inquiry| inquiry.correction_window_open? }.map(&:first_week_start).min
    earliest = [ today - RETROACTIVE_DAYS, inquiry_start ].compact.min
    errors.add(:starts_on, :too_far_back, days: RETROACTIVE_DAYS) if from < earliest
  end

  # The local weeks a pause from `from` to `to` (nil = open) touches, as far
  # as logs can exist (up to the current week).
  def weeks_touched(from, to)
    last_day = [ to, household.zone.today ].compact.min
    week = Week.containing(from, household.time_zone)
    weeks = []
    while week.monday <= last_day
      weeks << week
      week = week.next
    end
    weeks
  end

  def logged_in?(week)
    ChoreLog.where(user_id: household_member.user_id, completed_at: week.range).exists?
  end

  # On a creation every touched week counts; on an edit only the weeks the
  # new dates add (a log written after the declaration, in a week the pause
  # already covered, does not undo it).
  def covers_no_logged_week
    return if starts_on.nil? || household_member.nil? || (ends_on && ends_on < starts_on)
    return if persisted? && !(starts_on_changed? || ends_on_changed?)

    known = persisted? && starts_on_was ? weeks_touched(starts_on_was, ends_on_was).map(&:monday) : []
    logged = weeks_touched(starts_on, ends_on).reject { |week| known.include?(week.monday) }.select { |week| logged_in?(week) }
    return if logged.empty?

    week = logged.last
    own = household_member.user_id == declared_by_id || declared_by_id.nil?
    attribute = persisted? && !starts_on_changed? ? :ends_on : :starts_on
    when_key = week.monday == household.week_containing(Time.current).monday ? "this" : "that"
    errors.add(attribute, :"logged_#{when_key}_week_#{own ? 'self' : 'other'}", name: household_member.user.first_name,
               week: week.label.downcase, next_start: I18n.l(week.next.monday, format: :weekday_day_month))
  end

  def notify_engine
    WeeklyEngine.new(household).pause_declared(self)
  end

  def announce_new_dates
    EngineEvent.record!(household: household, name: "member_pause.updated", subject: self, at: Time.current,
                        household_member_id: household_member_id, user_id: household_member.user_id,
                        starts_on: starts_on, ends_on: ends_on, declared_by_id: declared_by_id)
  end
end
