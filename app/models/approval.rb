# One person's validation of a week plan (WeekPlan) or of a change of the
# split settings (SplitSettingChange). Screens never list who validated when:
# they show « Validée par tous » or « En attente de <prénom> » (decision
# 2026-11-08).
class Approval < ApplicationRecord
  belongs_to :approvable, polymorphic: true
  belongs_to :user

  validates :user_id, uniqueness: { scope: [ :approvable_type, :approvable_id ] }
end
