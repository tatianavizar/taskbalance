class Users::SessionsController < Devise::SessionsController
  # Password guessing: attempts are counted per connection and per address,
  # whether the account exists or not and whether the password is right or
  # not. Over the limit, the answer is the failed sign-in screen itself: an
  # attacker cannot tell a throttled attempt from a wrong password, nor a known
  # address from an unknown one.
  ATTEMPTS_PER_IP = 30
  ATTEMPTS_PER_EMAIL = 10
  ATTEMPTS_WITHIN = 15.minutes

  rate_limit to: ATTEMPTS_PER_IP, within: ATTEMPTS_WITHIN, only: :create, name: "sign-in-ip",
             with: -> { render_failed_sign_in }
  rate_limit to: ATTEMPTS_PER_EMAIL, within: ATTEMPTS_WITHIN, only: :create, name: "sign-in-email",
             by: -> { params.dig(:user, :email).to_s.strip.downcase },
             with: -> { render_failed_sign_in }

  # A5: Devise re-renders the sign-in form with a flash alert after a failed
  # attempt. The screen shows that failure itself (what happened, how to
  # recover), so the generic flash is dropped. Unknown address and wrong
  # password get the same screen on purpose.
  def new
    message = warden.message || request.env["warden.options"]&.dig(:message)
    @auth_failed = %i[invalid not_found_in_database].include?(message)
    flash.delete(:alert) if @auth_failed
    super
  end

  private

  # What Devise's failure app answers for a wrong password (recall of #new,
  # 422), without asking Warden anything.
  def render_failed_sign_in
    @auth_failed = true
    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    render :new, status: Devise.responder.error_status
  end
end
