# One-click unsubscribe (D9, RFC 8058), no sign-in: the signed token in the
# link of every notification email names the person and the event type.
#
#   GET  /desinscription/:token            the link in the email body: switches
#                                          the type off and says so, with an undo
#   POST /desinscription/:token            List-Unsubscribe=One-Click, sent by
#                                          the mail client itself
#   POST /desinscription/:token/reactiver  the undo
#
# It switches one event type off and back on, nothing else. It inherits from
# ActionController::Base on purpose: mail servers and clients post here with
# no session, no CSRF token and no browser user agent, so ApplicationController's
# allow_browser must not apply. Every bad token gets the same answer, which
# reveals nothing about accounts.
class UnsubscribesController < ActionController::Base
  layout "application"
  helper :all
  skip_forgery_protection only: :create
  before_action :resolve_token

  def show
    return render_invalid unless @user

    NotificationPreference.set(@user, @event_type, false)
  end

  def create
    return head :not_found unless @user

    NotificationPreference.set(@user, @event_type, false)
    head :ok
  end

  def resubscribe
    return render_invalid unless @user

    NotificationPreference.set(@user, @event_type, true)
  end

  private

  def resolve_token
    @token = params[:token]
    @user, @event_type = Notifications::Unsubscribe.resolve(@token)
  end

  def render_invalid
    render :invalid, status: :not_found
  end
end
