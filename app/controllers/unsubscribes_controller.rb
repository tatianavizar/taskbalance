# One-click unsubscribe (D9, RFC 8058), no sign-in: the signed token in the
# link of every notification email names the person and the event type.
#
#   GET  /desinscription/:token            the link in the email body: changes
#                                          NOTHING (mail scanners and link
#                                          previewers prefetch GET links); shows
#                                          the event type and one button
#   POST /desinscription/:token            the button of that page, or the mail
#                                          client's List-Unsubscribe=One-Click:
#                                          switches the type off
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
  # The one-click POST of a mail client carries no CSRF token. The button of
  # the page does, but it is checked like the one-click: the token in the URL
  # is the credential, and the action only switches one type off.
  skip_forgery_protection only: :create
  before_action :resolve_token

  def show
    render_invalid unless @user
  end

  def create
    unless @user
      return one_click? ? head(:not_found) : render_invalid
    end

    NotificationPreference.set(@user, @event_type, false)
    one_click? ? head(:ok) : render(:done)
  end

  def resubscribe
    return render_invalid unless @user

    NotificationPreference.set(@user, @event_type, true)
  end

  private

  def one_click?
    params["List-Unsubscribe"] == "One-Click"
  end

  def resolve_token
    @token = params[:token]
    @user, @event_type = Notifications::Unsubscribe.resolve(@token)
  end

  def render_invalid
    render :invalid, status: :not_found
  end
end
