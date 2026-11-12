# One line of the carried-over gap ledger (see SplitGap). `amount` is in
# percent of the fair share, signed: positive when the member carried more
# than their share.
class SplitGapEntry < ApplicationRecord
  belongs_to :household
  belongs_to :user, optional: true
  belongs_to :reset_by, class_name: "User", optional: true

  enum :kind, { week: "week", reset: "reset" }, prefix: true, validate: true

  validates :week_start, :amount, presence: true
end
