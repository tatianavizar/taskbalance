class Users::PasswordsController < Devise::PasswordsController
  # Reset mails: 5 per IP per hour, and 3 per address per hour (nobody can bury
  # an inbox). The answer stays generic (config.paranoid).
  rate_limit to: 5, within: 1.hour, only: :create, name: "password-reset-ip",
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
      # Sent with an expired token: show the "expired link" state again.
      inspect_reset_token(params.dig(:user, :reset_password_token)) if user.errors.include?(:reset_password_token)
    end
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
    end
  end

  def rate_limited_redirect
    redirect_to new_user_password_path, alert: t("devise.failure.rate_limited")
  end
end
