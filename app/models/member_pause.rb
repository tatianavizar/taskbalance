# A declared absence of one member: from `starts_on`, until `ends_on`
# (inclusive) or open-ended. Any member can declare one, for themselves or for
# an absent member (`declared_by`), as many times as they want. A paused
# member is not an active member for any week the pause overlaps, even by one
# day *(default)*: that week never counts as empty for them, and they are left
# out of the fair share. `reason` is private to the member concerned.
#
# Retroactive pauses are limited (product decisions 2026-11-08 and D3,
# 2026-11-12): the start can go back 14 days at most, or to the first week of
# an absence inquiry or regression about that member while it is open (until
# the next final report after its deadline); and every closed week it covers
# must be a week the member logged nothing. Over final weeks, the engine then
# records a correction and may cancel a regression (WeeklyEngine, D3).
class MemberPause < ApplicationRecord
  RETROACTIVE_DAYS = HouseholdRules::PAUSE_RETROACTIVE_DAYS

  belongs_to :household_member
  belongs_to :declared_by, class_name: "User", optional: true

  validates :starts_on, presence: true
  validate :ends_after_start
  validate :retroactive_limits, on: :create

  after_create :notify_engine
  # Every pause path notifies through the outbox: the engine recorded
  # member_pause.declared (and any outcome); deliver it without waiting.
  after_create_commit { NotificationsDispatchJob.perform_later(household_member.household_id) }

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

  # Ends the pause today, or removes it if it has not started yet.
  def cancel!(today = household.zone.today)
    return destroy! if starts_on > today

    update!(ends_on: [ ends_on, today ].compact.min)
  end

  private

  def ends_after_start
    errors.add(:ends_on, :before_start) if starts_on && ends_on && ends_on < starts_on
  end

  def retroactive_limits
    return if starts_on.nil? || household_member.nil?

    zone = household.zone
    today = zone.today
    return unless starts_on < today

    inquiry_start = AbsenceInquiry.where(household_member_id: household_member_id)
      .select { |inquiry| inquiry.correction_window_open? }.map(&:first_week_start).min
    earliest = [ today - RETROACTIVE_DAYS, inquiry_start ].compact.min
    return errors.add(:starts_on, :too_far_back, days: RETROACTIVE_DAYS) if starts_on < earliest

    week = Week.containing(starts_on, household.time_zone)
    last_day = [ ends_on, today ].compact.min
    now = Time.current
    while week.monday <= last_day && week.end_at < now
      if ChoreLog.where(user_id: household_member.user_id, completed_at: week.range).exists?
        return errors.add(:starts_on, :member_logged_that_week, week: week.label)
      end
      week = week.next
    end
  end

  def notify_engine
    WeeklyEngine.new(household).pause_declared(self)
  end
end
