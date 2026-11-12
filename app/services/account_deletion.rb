# F5: a person deletes their account (docs/backend-backlog.md 3.6). Also the
# form object of the F5 screen (`current_password`, `confirmed`, errors).
#
#   deletion = AccountDeletion.new(user, current_password: "...", confirmed: "1")
#   deletion.save   # false with errors; true once the account is anonymised
#
# In one transaction:
#   1. the person leaves their household first (HouseholdMember#leave!: chores
#      handed over, manager role passed on; the last one out deletes it);
#   2. their logs: see `dispose_of_logs!` (product decision, below);
#   3. what is theirs only goes: chore preferences, notifications and their
#      settings, validations; invitations addressed to them are cancelled;
#   4. past snapshots that name them (household_weeks members and pauses,
#      week plans, week corrections, other people's notifications, the
#      engine outbox) keep their figures and read « Ancien membre »;
#   5. the account row stays (past reports point to its id), anonymised:
#      first name « Ancien membre », an email nobody can receive at, a random
#      password (which also kills every remember-me cookie), `deleted_at` set
#      so sign-in is refused. There are no TOTP secrets nor session rows in
#      this app to remove; the controller signs the person out.
class AccountDeletion
  include ActiveModel::Model

  ANONYMOUS_FIRST_NAME = "Ancien membre".freeze
  ANONYMOUS_EMAIL_DOMAIN = "supprime.invalid".freeze # RFC 2606: never routable

  # PRODUCT / LEGAL DECISION (product owner, 2026-11-12): the logs belong to
  # their author and the person is leaving, so they are deleted (right to
  # erasure). The alternative, :keep_anonymised, leaves them on the
  # anonymised account. `dispose_of_logs!` is the only place that acts on it.
  LOGS_ON_DELETION = :delete
  LOG_POLICIES = %i[delete keep_anonymised].freeze

  attr_reader :user, :logs_policy
  attr_accessor :current_password, :confirmed

  def initialize(user, current_password: nil, confirmed: nil, logs_policy: LOGS_ON_DELETION)
    raise ArgumentError, "unknown logs policy #{logs_policy}" unless LOG_POLICIES.include?(logs_policy)

    @user = user
    @current_password = current_password
    @confirmed = confirmed
    @logs_policy = logs_policy
  end

  def self.model_name
    ActiveModel::Name.new(self, nil, "AccountDeletion")
  end

  def logs_deleted?
    logs_policy == :delete
  end

  def save
    errors.clear
    errors.add(:current_password, :invalid) unless user.valid_password?(current_password.to_s)
    errors.add(:confirmed, :accepted) unless ActiveModel::Type::Boolean.new.cast(confirmed)
    return false if errors.any?

    old_email = user.email
    User.transaction do
      user.lock!
      user.household_membership&.leave!
      dispose_of_logs!
      cancel_invitations!(old_email)
      drop_personal_data!
      anonymise_snapshots!
      anonymise_account!
    end
    true
  end

  # The one switch for the logs (see LOGS_ON_DELETION). Leaving the household
  # has already detached them.
  def dispose_of_logs!
    case logs_policy
    when :delete then ChoreLog.where(user_id: user.id).delete_all
    when :keep_anonymised then nil # they stay on the anonymised account, attached to nobody's name
    end
  end

  private

  def cancel_invitations!(email)
    Invitation.live.where(invitee_id: user.id).or(Invitation.live.where(email: email)).find_each(&:cancel!)
  end

  def drop_personal_data!
    ChorePreference.where(user_id: user.id).delete_all
    NotificationPreference.where(user_id: user.id).delete_all
    Notification.where(user_id: user.id).delete_all
    Approval.where(user_id: user.id).delete_all
    ChoreAssignee.where(user_id: user.id).delete_all
  end

  # JSON columns holding { "user_id" => id, "first_name" => ... } somewhere.
  SNAPSHOTS = {
    "HouseholdWeek" => %w[members pauses],
    "WeekPlan" => %w[participants],
    "Notification" => %w[facts],
    "EngineEvent" => %w[payload]
  }.freeze

  # Final reports are read-only records (HouseholdWeek#readonly?): only the
  # name changes, through SQL, never a figure.
  def anonymise_snapshots!
    SNAPSHOTS.each do |model_name, columns|
      model = model_name.constantize
      columns.each do |column|
        model.where(mentions_user(model.arel_table[column])).pluck(:id, column).each do |id, value|
          model.where(id: id).update_all(column => scrub(value))
        end
      end
    end
    WeekCorrection.where(user_id: user.id).update_all(first_name: ANONYMOUS_FIRST_NAME)
  end

  # jsonb_path_exists(column, '$.** ? (@.user_id == $id)', {"id": user.id}):
  # an object anywhere in the document whose user_id is this person's.
  def mentions_user(column)
    Arel::Nodes::NamedFunction.new("jsonb_path_exists", [
      column,
      Arel::Nodes.build_quoted("$.** ? (@.user_id == $id)"),
      Arel::Nodes::NamedFunction.new("jsonb_build_object", [ Arel::Nodes.build_quoted("id"), Arel::Nodes.build_quoted(user.id) ])
    ])
  end

  def scrub(value)
    case value
    when Array then value.map { |item| scrub(item) }
    when Hash
      hash = value.transform_values { |item| scrub(item) }
      return hash unless hash["user_id"] == user.id

      hash["first_name"] = ANONYMOUS_FIRST_NAME if hash.key?("first_name")
      hash["monogram"] = ANONYMOUS_FIRST_NAME.first if hash.key?("monogram")
      hash
    else value
    end
  end

  def anonymise_account!
    user.password = SecureRandom.base58(48)
    user.update_columns(
      first_name: ANONYMOUS_FIRST_NAME,
      email: "ancien-membre-#{user.id}-#{SecureRandom.hex(8)}@#{ANONYMOUS_EMAIL_DOMAIN}",
      encrypted_password: user.encrypted_password,
      unconfirmed_email: nil, confirmation_token: nil,
      reset_password_token: nil, reset_password_sent_at: nil, remember_created_at: nil,
      deleted_at: Time.current, updated_at: Time.current
    )
  end
end
