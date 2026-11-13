class Users::ConfirmationsController < Devise::ConfirmationsController
  # Seconds before the "resend" button comes back (the server limits sends too).
  RESEND_DELAY = 60

  # Devise skips authenticate_user! inside its own controllers unless forced.
  before_action -> { authenticate_user!(force: true) }, only: :pending

  # Resending the confirmation sends a mail: same limits as password reset
  # (9 per connection, 3 per address, per hour; decision of 2026-11-08).
  rate_limit to: 9, within: 1.hour, only: :create, name: "confirmation-ip",
             with: -> { rate_limited_redirect }
  rate_limit to: 3, within: 1.hour, only: :create, name: "confirmation-email",
             by: -> { params.dig(:user, :email).to_s.strip.downcase },
             with: -> { rate_limited_redirect }

  # A10: "confirm your email". Reached right after sign-up, and from the
  # account screen. It never blocks: the person can go on without confirming.
  def pending
    @user = current_user
    @address = @user.unconfirmed_email.presence || @user.email
    @confirmed = @user.confirmed? && @user.unconfirmed_email.blank?
    sent_at = @user.confirmation_sent_at
    @resend_in = sent_at ? [ (sent_at + RESEND_DELAY.seconds - Time.current).ceil, 0 ].max : 0
  end

  protected

  # Signed in (A10), the person goes back to the same screen; otherwise to the
  # sign-in screen, with the generic answer of config.paranoid.
  def after_resending_confirmation_instructions_path_for(resource_name)
    user_signed_in? ? pending_user_confirmation_path : super
  end

  private

  def rate_limited_redirect
    redirect_to(user_signed_in? ? pending_user_confirmation_path : new_user_confirmation_path,
                alert: t("devise.failure.rate_limited"))
  end
end
