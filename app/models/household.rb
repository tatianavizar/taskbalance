class Household < ApplicationRecord
  has_many :household_members, dependent: :destroy
  has_many :users, through: :household_members
  has_many :chores, dependent: :destroy
  has_many :recurring_chores, dependent: :destroy
  has_many :invitations, dependent: :destroy
end
