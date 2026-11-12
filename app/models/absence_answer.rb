# One member's answer to an absence question: "yes" (the member concerned was
# away) or "no". One per inquiry and respondent; written through
# AbsenceInquiry#answer! and #correct!, never directly.
#
# - member_pause: the pause this "yes" declared (only the first "yes" declares
#   one; later ones join it).
# - original_answer / corrected_at: set when the member concerned corrected
#   this answer; `answer` then holds the corrected value.
class AbsenceAnswer < ApplicationRecord
  VALUES = %w[yes no].freeze

  belongs_to :absence_inquiry
  belongs_to :household_member
  belongs_to :member_pause, optional: true

  validates :answer, inclusion: { in: VALUES }
  validates :answered_at, presence: true
  validates :household_member_id, uniqueness: { scope: :absence_inquiry_id }

  scope :yes, -> { where(answer: "yes") }
  scope :no, -> { where(answer: "no") }

  def yes? = answer == "yes"
  def no? = answer == "no"
  def corrected? = corrected_at.present?

  def respondent_user_id
    household_member.user_id
  end

  # Answer given by the member the question is about.
  def by_concerned_member?
    household_member_id == absence_inquiry.household_member_id
  end
end
