class Users::ConfirmationsController < Devise::ConfirmationsController
  # Resending the confirmation sends a mail: same limits as password reset.
  rate_limit to: 5, within: 1.hour, only: :create, name: "confirmation-ip",
             with: -> { rate_limited_redirect }
  rate_limit to: 3, within: 1.hour, only: :create, name: "confirmation-email",
             by: -> { params.dig(:user, :email).to_s.strip.downcase },
             with: -> { rate_limited_redirect }

  private

  def rate_limited_redirect
    redirect_to new_user_confirmation_path, alert: t("devise.failure.rate_limited")
  end
end
