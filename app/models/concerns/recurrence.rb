# How often a task comes back, shared by the catalogue (Task: the default) and
# the household's chores (Chore: what the household chose).
#
#   frequency         daily, weekly, monthly, annually, or once (one-off)
#   times_per_period  "2 fois par semaine": 2 with weekly. Only daily and
#                     weekly repeat inside their period.
#
# The planned weight of a chore in a week's split is its number of
# occurrences in that week (decision 2026-11-08): a daily chore counts 7
# times, a weekly one once, a monthly, yearly or one-off chore counts in the
# week it falls due (anchor_on, Chore only).
module Recurrence
  extend ActiveSupport::Concern

  FREQUENCIES = { daily: 0, weekly: 1, monthly: 2, annually: 3, once: 4 }.freeze
  # Frequencies that need a due date to know which week they fall in.
  ANCHORED = %w[monthly annually once].freeze
  REPEATING = %w[daily weekly].freeze
  MAX_TIMES_PER_PERIOD = 14

  included do
    enum :frequency, FREQUENCIES, default: :weekly, validate: true

    validates :times_per_period, numericality: { only_integer: true, greater_than_or_equal_to: 1,
                                                 less_than_or_equal_to: MAX_TIMES_PER_PERIOD }
    validates :times_per_period, numericality: { equal_to: 1 }, unless: :repeating?
  end

  def anchored?
    ANCHORED.include?(frequency.to_s)
  end

  def repeating?
    REPEATING.include?(frequency.to_s)
  end

  # Occurrences of a recurrence in the 7 days of `week` (a Week).
  def self.occurrences(frequency:, times_per_period:, anchor_on:, week:)
    times = times_per_period.to_i.clamp(1, MAX_TIMES_PER_PERIOD)
    case frequency.to_s
    when "daily" then 7 * times
    when "weekly" then times
    when "monthly" then week.date_range.count { |day| monthly_due?(anchor_on, day) }
    when "annually" then week.date_range.count { |day| yearly_due?(anchor_on, day) }
    when "once" then anchor_on && week.date_range.cover?(anchor_on) ? 1 : 0
    else 0
    end
  end

  # Due on the anchor's day of the month, from the anchor on. A 31st falls on
  # the last day of shorter months (Date#>> clamps).
  def self.monthly_due?(anchor, day)
    return false if anchor.nil? || day < anchor

    months = (day.year * 12 + day.month) - (anchor.year * 12 + anchor.month)
    (anchor >> months) == day
  end

  def self.yearly_due?(anchor, day)
    return false if anchor.nil? || day < anchor

    (anchor >> (12 * (day.year - anchor.year))) == day
  end
end
