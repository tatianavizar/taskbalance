# Account lockout after wrong passwords (decision of 2026-11-13, replaces the
# per-address rate limit on sign-in; the per-connection one stays in
# Users::SessionsController).
#
#   - 4 wrong passwords within 2 hours lock the account for 2 hours. A wrong
#     password older than 2 hours stops counting (`failed_sign_ins_at` keeps
#     the times of the recent ones).
#   - The 3rd lock (12 wrong passwords) is permanent: only the team unlocks it
#     from the back office (BackOffice::Actions.unlock_account).
#   - A successful sign-in resets both counters (`after_database_authentication`).
#   - While locked, an attempt is refused without checking the password and
#     without counting; the right password is refused too.
#   - The sign-in screen never tells: Devise is paranoid, a locked account
#     gets the same "wrong email or password" as a wrong password.
#   - Each lock sends the owner an email (AccountMailer.sign_in_locked).
#   - A lock only stops new sign-ins: sessions already open stay open (anyone
#     knowing the address could otherwise log the person out of every device).
#     A password reset changes the password but neither lifts the lock nor
#     signs in while it lasts (Users::PasswordsController#update).
#
# Implemented on Devise's `valid_for_authentication?` hook, without
# :lockable, whose single counter and session kill-switch fit neither rule.
module SignInLockout
  extend ActiveSupport::Concern

  MAX_FAILED_ATTEMPTS = 4
  FAILED_ATTEMPTS_WINDOW = 2.hours
  LOCK_DURATION = 2.hours
  # The lock that stays until the team lifts it.
  HARD_LOCK_AT = 3

  included do
    # Locked right now: permanently, or within a temporary lock.
    scope :sign_in_locked, lambda {
      where.not(sign_in_hard_locked_at: nil).or(where(sign_in_locked_at: (Time.current - LOCK_DURATION)..))
    }
  end

  # Called by Devise's database strategy with the password check as the
  # block. False refuses the sign-in (paranoid: always the "invalid" message).
  def valid_for_authentication?(&block)
    return super unless persisted?

    locked_now = false
    verdict = with_lock do
      next false if sign_in_locked?

      if super(&block)
        true
      else
        locked_now = register_failed_sign_in!
        false
      end
    end
    deliver_lock_email if locked_now
    verdict
  end

  # A successful sign-in through the password (Devise calls it).
  def after_database_authentication
    super if defined?(super)
    reset_sign_in_lockout! if failed_sign_ins_at.any? || sign_in_lockouts_count.positive? || sign_in_locked_at
  end

  def sign_in_locked?(now = Time.current)
    sign_in_hard_locked? || sign_in_temporarily_locked?(now)
  end

  def sign_in_hard_locked?
    sign_in_hard_locked_at.present?
  end

  def sign_in_temporarily_locked?(now = Time.current)
    sign_in_locked_at.present? && now < sign_in_unlocks_at
  end

  # When a temporary lock ends (nil for a permanent one or no lock).
  def sign_in_unlocks_at
    sign_in_locked_at + LOCK_DURATION if sign_in_locked_at && !sign_in_hard_locked?
  end

  # The team's unlock (back office). Also clears a lock that has lapsed.
  def unlock_sign_in!
    reset_sign_in_lockout!
  end

  private

  # Runs under the row lock. Returns true when this failure locked the account.
  def register_failed_sign_in!(now = Time.current)
    recent = failed_sign_ins_at.select { |at| at > now - FAILED_ATTEMPTS_WINDOW } + [ now ]
    if recent.size >= MAX_FAILED_ATTEMPTS
      lockouts = sign_in_lockouts_count + 1
      update_columns(failed_sign_ins_at: [], sign_in_locked_at: now, sign_in_lockouts_count: lockouts,
                     sign_in_hard_locked_at: (now if lockouts >= HARD_LOCK_AT))
      true
    else
      update_columns(failed_sign_ins_at: recent)
      false
    end
  end

  def reset_sign_in_lockout!
    update_columns(failed_sign_ins_at: [], sign_in_locked_at: nil, sign_in_lockouts_count: 0, sign_in_hard_locked_at: nil)
  end

  def deliver_lock_email
    AccountMailer.sign_in_locked(self).deliver_later
  end
end
