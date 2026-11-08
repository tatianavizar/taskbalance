class Household < ApplicationRecord
  include TimeZoned

  NAME_MAX_LENGTH = 60

  has_many :household_members, dependent: :destroy
  has_many :users, through: :household_members
  has_many :chores, dependent: :destroy
  has_many :recurring_chores, dependent: :destroy
  # Logs are the members' own data and survive the household being deleted.
  has_many :chore_logs, dependent: :nullify
  has_many :invitations, dependent: :destroy

  before_validation { self.name = name.to_s.strip.presence }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }

  # Creates the household and makes `user` its manager, in one transaction.
  # Returns the household: check `persisted?` and `errors`. A user who already
  # has a household gets an error on :base and nothing is created.
  def self.create_for(user, attributes = {})
    household = new(attributes)
    # The household starts in its creator's time zone unless one is given.
    household.time_zone = user.time_zone if attributes.to_h.with_indifferent_access[:time_zone].blank?

    if user.household_membership.present?
      household.errors.add(:base, :user_already_in_household)
      return household
    end

    transaction do
      raise ActiveRecord::Rollback unless household.save

      household.household_members.create!(user: user, role: :manager)
    end
    household
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    household.errors.add(:base, :user_already_in_household)
    household
  end

  def manager
    household_members.manager.order(:created_at, :id).first&.user
  end
end
