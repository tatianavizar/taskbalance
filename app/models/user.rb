class User < ApplicationRecord
  include TimeZoned
  include BackOfficeSearchable

  FIRST_NAME_MAX_LENGTH = 50

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  #
  # :confirmable never blocks access (config.allow_unconfirmed_access_for = nil):
  # the confirmation link lasts 24 h, and an unconfirmed account can sign in and
  # create its household.
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  # One household per account (decision of 2026-11-08).
  has_one :household_membership, class_name: "HouseholdMember"
  has_one :household, through: :household_membership
  has_many :chores, through: :household       # all chores of the user's household
  has_many :chore_assignees, dependent: :delete_all
  has_many :assigned_chores, through: :chore_assignees, source: :chore
  # The journal (E6): their logs across time, whatever became of the chore or
  # the household. No `dependent`: a log is theirs, nothing here deletes it.
  has_many :chore_logs
  # Private: only their author ever sees them.
  has_many :chore_preferences, dependent: :delete_all

  # What the back office may filter on (never a log, a preference or a household figure).
  self.ransackable_attribute_names = %w[first_name email confirmed_at created_at deleted_at]

  before_validation { self.first_name = first_name.to_s.strip.presence }

  validates :first_name, presence: true, length: { maximum: FIRST_NAME_MAX_LENGTH }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Lot 7, F5: an account deleted by its owner is anonymised (AccountDeletion)
  # and can never sign in again.
  def deleted?
    deleted_at.present?
  end

  def active_for_authentication?
    super && !deleted?
  end

  # Sessions last one week whether or not the person ticked a box: the
  # persistent cookie is always issued at sign-in (see config/initializers/devise.rb
  # `remember_for`). Devise reads this accessor in its after_set_user hook.
  def remember_me
    true
  end
end
