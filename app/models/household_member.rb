class HouseholdMember < ApplicationRecord
  belongs_to :user
  belongs_to :household

  validates :user_id, presence: true
  validates :household_id, presence: true
  validates :user_id, uniqueness: { scope: :household_id, message: "already belongs to this household" }
end
