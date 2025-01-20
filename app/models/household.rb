class Household < ApplicationRecord
  has_many :household_members
  has_many :users, through: :household_members
  has_many :chores
end
