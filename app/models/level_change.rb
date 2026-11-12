# History of a household's level: every move, up or down, with the counter
# before and after. Written by WeeklyEngine only.
class LevelChange < ApplicationRecord
  belongs_to :household
  belongs_to :household_week, optional: true
  belongs_to :absence_inquiry, optional: true
  # Set on a regression_cancelled change: the regression it undoes.
  belongs_to :cancelled_level_change, class_name: "LevelChange", optional: true

  enum :reason, {
    reached: "reached",                     # a balanced week crossed a threshold
    regressed: "regressed",                 # 2 empty weeks, no pause by the deadline
    ultimate_lost: "ultimate_lost",         # ratio since first reached fell to the keep rate or less
    ultimate_regained: "ultimate_regained", # ratio back above the keep rate
    regression_cancelled: "regression_cancelled" # D3: a retroactive pause covered the empty weeks
  }, validate: true

  validates :from_level, :to_level, inclusion: { in: 0..Progression::ULTIMATE }
  validates :balanced_weeks_count_before, :balanced_weeks_count_after, numericality: { greater_than_or_equal_to: 0 }

  scope :chronological, -> { order(:created_at, :id) }
  # Regressions not undone by a regression_cancelled change.
  scope :standing_regressions, -> {
    regressed.where.not(id: LevelChange.where.not(cancelled_level_change_id: nil).select(:cancelled_level_change_id))
  }
end
