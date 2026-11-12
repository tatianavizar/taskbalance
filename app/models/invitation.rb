# An invitation to join a household (lot 3, docs/backend-backlog.md 3.1, 3.2).
#
# Nobody joins a household without accepting, existing accounts included. The
# invited person joins only at the last step of the setup (`accept!`); until
# then they can decline. Between sign-up and that step, `invitee` gives them
# access to the household's setup (see `grants_setup_access_to?`).
#
#   pending -> accepted | declined | cancelled | expired
#
# Only a pending invitation can still be used. One pending invitation per
# email and household (partial unique index); closed rows stay as history.
class Invitation < ApplicationRecord
  VALIDITY = 14.days
  MAX_RESENDS = 3
  MIN_RESEND_GAP = 15.minutes

  belongs_to :household
  belongs_to :invitee, class_name: "User", optional: true
  belongs_to :inviter, class_name: "User", optional: true

  enum :state, {
    pending: "pending", accepted: "accepted", declined: "declined",
    cancelled: "cancelled", expired: "expired"
  }, default: "pending", validate: true

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true
  validate :email_domain_complete
  validate :checks_for_new_invitation, on: :create

  before_validation :generate_token, on: :create
  before_validation :set_send_defaults, on: :create

  # The person sending it; lets the validations reject their own address.
  attr_accessor :sent_by

  # Pending and not past its date. A pending row past its date reads as
  # expired for every purpose, whether or not `expire_overdue!` wrote it yet.
  scope :live, -> { pending.where("invitations.expires_at > ?", Time.current) }

  # Writes `expired` on every pending invitation whose date has passed.
  def self.expire_overdue!(scope = all)
    scope.pending.where(expires_at: ..Time.current).update_all(state: "expired")
  end

  # Opens a new invitation and queues the email. Returns the invitation:
  # `persisted?` is false and `errors` explains why when nothing was sent.
  def self.invite(household:, email:, inviter:)
    expire_overdue!(where(household_id: household.id))
    invitation = new(household: household, email: email, inviter: inviter, sent_by: inviter)
    InvitationMailer.invite(invitation).deliver_later if invitation.save
    invitation
  rescue ActiveRecord::RecordNotUnique
    invitation.errors.add(:email, :already_invited_now)
    invitation
  end

  # ---- Resend counting ------------------------------------------------------
  #
  # PRODUCT OPEN QUESTION (D12, docs/plan-de-travail.md section 4): are resends
  # counted per invitation, or per email and household? We count per email and
  # household, so that cancelling and inviting again does not reset the
  # counter. This method is the only place that decides it: to count per
  # invitation instead, scope on the row and drop the carry-over in
  # `set_send_defaults`.
  def self.resend_counting_scope(household_id:, email:)
    where(household_id: household_id, email: normalize_value_for(:email, email))
  end

  # Resends already used for this email in this household.
  def self.resends_used(household_id:, email:)
    resend_counting_scope(household_id: household_id, email: email).sum(:resend_count)
  end

  def self.last_send_at(household_id:, email:)
    resend_counting_scope(household_id: household_id, email: email).maximum(:last_sent_at)
  end

  # What a send to this email is currently allowed to do:
  #   [:ok], [:wait, seconds] (15 min between two sends) or [:limit] (3 used).
  def self.send_allowance(household_id:, email:, now: Time.current)
    return [ :limit ] if resends_used(household_id: household_id, email: email) >= MAX_RESENDS

    last = last_send_at(household_id: household_id, email: email)
    wait = last ? (last + MIN_RESEND_GAP - now) : 0
    wait.positive? ? [ :wait, wait.ceil ] : [ :ok ]
  end

  # The live invitation a signed-in person is working through as invitee.
  def self.live_for_invitee(user)
    return unless user

    live.where(invitee_id: user.id).order(:created_at, :id).last
  end

  # ---- State ---------------------------------------------------------------

  def usable?
    pending? && expires_at > Time.current
  end

  # The state to show: a pending invitation past its date reads as expired.
  def current_state
    pending? && !usable? ? "expired" : state
  end

  def expire_if_due!
    update_columns(state: "expired") if pending? && !usable?
    self
  end

  def for?(user)
    user.present? && email == self.class.normalize_value_for(:email, user.email)
  end

  # Records that this account is working through the setup. Joining waits for
  # `accept!`. Refused (false) when the invitation is not usable, is for
  # another address, or the person is already in a household (D13: they must
  # leave it first).
  def claim_for!(user)
    return false unless can_be_worked_through_by?(user)

    update!(invitee: user) unless invitee_id == user.id
    true
  end

  # The pre-join access mechanism (lot 3.2). Lot 2's screens for the invitee
  # (B10, B11, B14: preferences, split, proposal) call this before reading or
  # writing anything of the household: true only for the person who claimed
  # this invitation, while it is pending and unexpired, and while they are
  # still in no household.
  def grants_setup_access_to?(user)
    usable? && user.present? && invitee_id == user.id && user.household_membership.nil?
  end

  # Where an invitee resumes: :waiting while the manager has not finished the
  # setup (B12), else :preferences (B10, then B11 or B14, built in lot 2).
  def resume_stage
    household.setting_up? ? :waiting : :preferences
  end

  # The last step: the invited person joins. Returns the membership, or false
  # with errors when they cannot (household full, already in a household,
  # invitation closed or for someone else).
  def accept!(user)
    # The invitee must have claimed the invitation first: nobody joins without
    # having gone through the setup screens.
    unless grants_setup_access_to?(user) && for?(user)
      errors.add(:base, :not_acceptable)
      return false
    end

    membership = household.household_members.new(user: user)
    transaction do
      raise ActiveRecord::Rollback unless membership.save

      update!(state: "accepted", accepted_at: Time.current, invitee: user)
    end
    return membership if membership.persisted?

    membership.errors.full_messages.each { |message| errors.add(:base, message) }
    false
  end

  # Refusing: allowed to the addressee until the last step.
  def decline!(user)
    return false unless usable? && for?(user)

    update!(state: "declined", declined_at: Time.current, invitee: user)
  end

  def cancel!
    return false unless usable?

    update!(state: "cancelled", cancelled_at: Time.current)
  end

  # ---- Resend --------------------------------------------------------------

  def resend_allowance(now: Time.current)
    self.class.send_allowance(household_id: household_id, email: email, now: now)
  end

  def resends_used
    self.class.resends_used(household_id: household_id, email: email)
  end

  # Same token, expiry reset, new email. Returns [:ok], the refusal
  # ([:wait, seconds] or [:limit]), or [:closed] when no longer pending.
  def resend!
    return [ :closed ] unless usable?

    verdict = resend_allowance
    return verdict unless verdict.first == :ok

    now = Time.current
    update!(resend_count: resend_count + 1, last_sent_at: now, expires_at: now + VALIDITY)
    InvitationMailer.invite(self).deliver_later
    [ :ok ]
  end

  private

  def can_be_worked_through_by?(user)
    usable? && for?(user) && user.household_membership.nil?
  end

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  # A new row for an email already invited to this household (cancelled,
  # declined or expired earlier) counts as a resend: see resend_counting_scope.
  def set_send_defaults
    now = Time.current
    self.last_sent_at ||= now
    self.expires_at ||= now + VALIDITY
    return if resend_count.positive? || household_id.blank? || email.blank?

    self.resend_count = 1 if self.class.resend_counting_scope(household_id: household_id, email: email).exists?
  end

  # "karim@gmail" passes the generic address format but cannot receive mail.
  def email_domain_complete
    return if email.blank? || errors.include?(:email)

    domain = email.split("@", 2).last.to_s
    errors.add(:email, :incomplete_domain) unless domain.match?(/\A[^.\s]+(\.[^.\s]+)*\.[a-z]{2,}\z/i)
  end

  def checks_for_new_invitation
    return if errors.any? || household.nil?

    if sent_by && for?(sent_by)
      errors.add(:email, :own_email)
    elsif (member = household.users.find_by(email: email))
      errors.add(:email, :already_member, name: member.first_name)
    elsif (existing = household.invitations.live.find_by(email: email))
      errors.add(:email, :already_invited, date: I18n.l(existing.last_sent_at.in_time_zone(household.zone).to_date, format: :short))
    elsif household.household_members.count + household.invitations.live.count >= HouseholdMember::COLORS.size
      errors.add(:base, :household_full, max: HouseholdMember::COLORS.size)
    else
      check_send_allowance
    end
  end

  def check_send_allowance
    return unless resend_count.positive?

    verdict, seconds = self.class.send_allowance(household_id: household_id, email: email)
    case verdict
    when :limit then errors.add(:email, :resend_limit, max: MAX_RESENDS)
    when :wait then errors.add(:email, :resend_wait, minutes: (seconds / 60.0).ceil)
    end
  end
end
