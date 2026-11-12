# D3 (decision 2026-11-12): a pause declared after the fact over a final week.
# The stored HouseholdWeek is never rewritten; this record sits over it and
# makes the week read as « Neutre · pause déclarée le <declared_at> ». A
# corrected week is excluded from the ultimate-level ratio. Written by
# WeeklyEngine#retroactive_pause_on_final_weeks only, one per week and member.
class WeekCorrection < ApplicationRecord
  NEUTRAL_REASON = "pause_declared".freeze

  belongs_to :household
  belongs_to :household_week
  belongs_to :member_pause, optional: true
  belongs_to :user, optional: true
  belongs_to :declared_by, class_name: "User", optional: true

  validates :first_name, :declared_at, presence: true
  validates :user_id, uniqueness: { scope: :household_week_id }, allow_nil: true
end
