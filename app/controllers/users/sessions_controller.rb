class Users::SessionsController < Devise::SessionsController
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
end
