class Household < ApplicationRecord
  has_many :household_members, dependent: :destroy
  has_many :users, through: :household_members
  has_many :chores, dependent: :destroy
  has_many :recurring_chores, dependent: :destroy
  # Logs are the members' own data and survive the household being deleted.
  has_many :chore_logs, dependent: :nullify
  has_many :invitations, dependent: :destroy
end
