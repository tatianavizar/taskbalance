# Opened by the final report that gives a member their second consecutive
# empty week. Every member, the absent one included, is asked whether that
# member was away (E11, P5). One "Yes" is enough: it declares a pause over the
# two weeks, which resolves the inquiry as `paused`. Without a covering pause
# by `deadline_at` (Wednesday 20:00 after the closing, household zone), the
# household regresses one level and is blocked (`regressed`).
#
# Seam for lot 5b: the question itself, the "No" answers (absence_answers),
# the Wednesday reminder and the screens are not built. A "Yes" goes through
# #answer_yes!, which is all the state machine needs.
class AbsenceInquiry < ApplicationRecord
  DEADLINE_WDAY_OFFSET = 2 # Wednesday, counted from the Monday of the closing
  DEADLINE_HOUR = 20

  belongs_to :household
  belongs_to :household_member

  # cancelled: the regression applied at the deadline was undone by a pause
  # declared afterwards, within the window (D3).
  enum :status, { pending: "pending", paused: "paused", regressed: "regressed", cancelled: "cancelled" }, validate: true

  validates :first_week_start, :last_week_start, :deadline_at, presence: true

  scope :due, ->(now) { pending.where(deadline_at: ..now) }

  # Wednesday 20:00 of the week after `last_week`, in its zone.
  def self.deadline_for(last_week)
    day = last_week.next.monday + DEADLINE_WDAY_OFFSET
    last_week.time_zone.local(day.year, day.month, day.day, DEADLINE_HOUR)
  end

  # The inquiry's weeks stay open to a retroactive pause (and the regression
  # to cancellation) until the next final report after the deadline: the
  # Monday 03:00 closing the week after `last_week_start` (D3).
  def correction_window_end
    HouseholdWeek.final_at(Week.new(last_week_start, household.zone).next)
  end

  def correction_window_open?(now = Time.current)
    now < correction_window_end
  end

  def covers_week?(week)
    week.monday.between?(first_week_start, last_week_start)
  end

  def weeks
    zone = household.zone
    [ Week.new(first_week_start, zone), Week.new(last_week_start, zone) ]
  end

  def covered_by_pause?
    weeks.any? { |week| household_member.member_pauses.overlapping(week).exists? }
  end

  # "Yes, they were away": declares the pause over the two empty weeks.
  def answer_yes!(by:)
    MemberPause.declare!(
      member: household_member, declared_by: by,
      starts_on: first_week_start, ends_on: last_week_start + 6
    )
  end
end
