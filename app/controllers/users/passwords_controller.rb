class Users::PasswordsController < Devise::PasswordsController
  # Seconds before the "resend" button comes back (the server limits sends too).
  RESEND_DELAY = 60

  # The zone of the expiry hour on the "check your emails" screen.
  DEFAULT_ZONE = "Europe/Paris".freeze

  # Reset mails: 9 per connection per hour, and 3 per address per hour (nobody
  # can bury an inbox; decision of 2026-11-08). The answer stays generic
  # (config.paranoid).
  rate_limit to: 9, within: 1.hour, only: :create, name: "password-reset-ip",
             with: -> { rate_limited_redirect }
  rate_limit to: 3, within: 1.hour, only: :create, name: "password-reset-email",
             by: -> { params.dig(:user, :email).to_s.strip.downcase },
             with: -> { rate_limited_redirect }

  # The link is checked when it is opened, not when the new password is sent
  # (A8, A9): an expired or already-used link renders the "expired link" state
  # of the same template, with @reset_link_expired and @reset_link_sent_at;
  # a valid one exposes @reset_email.
  def edit
    inspect_reset_token(params[:reset_password_token])
    super
  end

  def update
    super do |user|
      # Re-rendered with errors: an expired token shows the "expired link" state
      # again, a valid one keeps the form (and the account email) on screen.
      inspect_reset_token(params.dig(:user, :reset_password_token)) if user.errors.any?
    end
  end

  # A7: "check your emails". The same screen for a known and an unknown
  # address (config.paranoid); the address comes from the session, set when the
  # request was made.
  def sent
    pending = session[:password_reset]
    return redirect_to(new_user_password_path) unless pending

    @email = pending["email"]
    sent_at = Time.zone.at(pending["sent_at"])
    # Always the default zone, and no account is looked up: reading the hour in
    # the account's own zone would tell a visitor that the address has an
    # account, and where its owner lives.
    @expires_at = (sent_at + Devise.reset_password_within).in_time_zone(DEFAULT_ZONE)
    @resend_in = [ (sent_at + RESEND_DELAY.seconds - Time.current).ceil, 0 ].max
  end

  protected

  def after_sending_reset_password_instructions_path_for(_resource_name)
    session[:password_reset] = { "email" => params.dig(:user, :email).to_s.strip, "sent_at" => Time.current.to_i }
    flash.delete(:notice) # the screen says it itself
    sent_user_password_path
  end

  private

  def inspect_reset_token(token)
    user = token.present? ? User.with_reset_password_token(token) : nil

    if user && user.reset_password_period_valid?
      @reset_link_expired = false
      @reset_email = user.email
    else
      @reset_link_expired = true
      @reset_link_sent_at = user&.reset_password_sent_at
      @reset_link_zone = user&.zone
    end
  end

  def rate_limited_redirect
    redirect_to new_user_password_path, alert: t("devise.failure.rate_limited")
  end
end
