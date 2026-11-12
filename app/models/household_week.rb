# The weekly report of a household: a snapshot of WeeklyStats for one local
# week. Written provisional on Sunday 20:00 and final on Monday 03:00 (household
# zone) by WeeklyEngine. Once final, a row is read-only: it is never rewritten,
# even when a log is later back-dated into that week.
#
# `members` (JSON array, one hash per member, string keys): household_member_id,
# user_id, first_name, color, monogram, mental_count, execution_count, minutes,
# logs_count, mental_share, execution_share, paused, arrived, in_zone_mental,
# in_zone_execution, in_zone. `pauses`: household_member_id, user_id,
# first_name, starts_on, ends_on, declared_by_id (the reason is private and
# never copied here).
class HouseholdWeek < ApplicationRecord
  PROVISIONAL_HOUR = 20 # Sunday 20:00
  FINAL_HOUR = 3        # Monday 03:00, the Monday after the week

  belongs_to :household
  has_many :level_changes, dependent: nil # nullified by the foreign key
  # D3: corrections laid over the report; the report itself never changes.
  has_many :week_corrections, dependent: nil # deleted by the foreign key

  enum :status, { provisional: "provisional", final: "final" }, validate: true
  enum :outcome, { balanced: "balanced", unbalanced: "unbalanced", neutral: "neutral" }, validate: true

  validates :week_start, presence: true, uniqueness: { scope: :household_id }
  validates :time_zone, :computed_at, presence: true
  validates :neutral_reason, inclusion: { in: WeeklyStats::NEUTRAL_REASONS.map(&:to_s) }, if: :neutral?
  validates :neutral_reason, absence: true, unless: :neutral?
  validate :week_start_is_a_monday

  scope :chronological, -> { order(:week_start) }

  def self.provisional_at(week)
    week.time_zone.local(week.sunday.year, week.sunday.month, week.sunday.day, PROVISIONAL_HOUR)
  end

  def self.final_at(week)
    monday = week.next.monday
    week.time_zone.local(monday.year, monday.month, monday.day, FINAL_HOUR)
  end

  # A final report is never rewritten (docs/backend-backlog.md, product rules).
  def readonly?
    super || (persisted? && status_in_database == "final")
  end

  def corrected?
    week_corrections.any?
  end

  # What screens show: neutral once a retroactive pause corrected the week.
  def effective_outcome
    corrected? ? "neutral" : outcome
  end

  def effective_neutral_reason
    corrected? ? WeekCorrection::NEUTRAL_REASON : neutral_reason
  end

  def week
    Week.new(week_start, ActiveSupport::TimeZone[time_zone])
  end

  def member_snapshot(user_or_id)
    id = user_or_id.respond_to?(:id) ? user_or_id.id : user_or_id
    members.find { |m| m["user_id"] == id }
  end

  private

  def week_start_is_a_monday
    errors.add(:week_start, :not_a_monday) if week_start && !week_start.monday?
  end
end
