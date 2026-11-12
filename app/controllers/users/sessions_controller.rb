class Users::SessionsController < Devise::SessionsController
  # Password guessing, two defences (decision of 2026-11-13):
  #   - per connection: 30 attempts per 15 minutes, whatever the address and
  #     whether the password is right or not;
  #   - per account: the lockout of SignInLockout (4 wrong passwords in 2 h
  #     lock it for 2 h, the 3rd lock waits for the team).
  # Either way the answer is the failed sign-in screen itself: an attacker
  # cannot tell a throttled attempt or a locked account from a wrong password,
  # nor a known address from an unknown one (Devise paranoid).
  ATTEMPTS_PER_IP = 30
  ATTEMPTS_WITHIN = 15.minutes

  rate_limit to: ATTEMPTS_PER_IP, within: ATTEMPTS_WITHIN, only: :create, name: "sign-in-ip",
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
