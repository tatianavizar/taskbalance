# History of a household's level: every move, up or down, with the counter
# before and after. Written by WeeklyEngine only.
class LevelChange < ApplicationRecord
  belongs_to :household
  belongs_to :household_week, optional: true
  belongs_to :absence_inquiry, optional: true

  enum :reason, {
    reached: "reached",                     # a balanced week crossed a threshold
    regressed: "regressed",                 # 2 empty weeks, no pause by the deadline
    ultimate_lost: "ultimate_lost",         # ratio over the window fell to 85 % or less (D5)
    ultimate_regained: "ultimate_regained"  # ratio back above 85 % (D5)
  }, validate: true

  validates :from_level, :to_level, inclusion: { in: 0..Progression::ULTIMATE }
  validates :balanced_weeks_count_before, :balanced_weeks_count_after, numericality: { greater_than_or_equal_to: 0 }

  scope :chronological, -> { order(:created_at, :id) }
end
