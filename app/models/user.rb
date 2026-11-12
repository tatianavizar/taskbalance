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
  # After `devise`: it wraps Devise's valid_for_authentication?.
  include SignInLockout

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
  # Lot 8b: the phones that accepted notifications (PushDevice).
  has_many :push_devices, dependent: :delete_all

  # What the back office may filter on (never a log, a preference or a household figure).
  self.ransackable_attribute_names = %w[first_name email confirmed_at created_at deleted_at]

  before_validation { self.first_name = first_name.to_s.strip.presence }

  validates :first_name, presence: true, length: { maximum: FIRST_NAME_MAX_LENGTH }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Lot 7, F5: an account deleted by its owner is anonymised (AccountDeletion)
  # and can never sign in again.
  # Changes of email per account over a rolling 24 hours (decision of
  # 2026-11-13). Counted when the change sent a confirmation mail.
  EMAIL_CHANGES_PER_DAY = 2
  EMAIL_CHANGES_WINDOW = 24.hours

  def recent_email_changes(now = Time.current)
    email_changes_requested_at.select { |at| at > now - EMAIL_CHANGES_WINDOW }
  end

  # When the next change is allowed; nil when it is allowed now.
  def email_change_blocked_until(now = Time.current)
    recent = recent_email_changes(now).sort
    recent.last(EMAIL_CHANGES_PER_DAY).first + EMAIL_CHANGES_WINDOW if recent.size >= EMAIL_CHANGES_PER_DAY
  end

  def record_email_change!(now = Time.current)
    update_columns(email_changes_requested_at: recent_email_changes(now) + [ now ])
  end

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
