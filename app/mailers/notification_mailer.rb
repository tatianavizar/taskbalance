# Every notification email: the report (H3), the alerts (E3, E4, E5) and the
# rest of the catalogue. One action; the words come from Notifications::Message,
# written for the recipient from facts shared by all recipients (D8).
#
# Each message carries the one-click unsubscribe (D9, RFC 8058): the
# List-Unsubscribe headers and a link in the footer, both with a signed token
# for this person and this event type. Transactional mail (invitations,
# password, address confirmation) is not governed by a preference and has no
# such link.
class NotificationMailer < ApplicationMailer
  def notify(notification)
    @notification = notification
    @message = notification.message
    @user = notification.user
    @event_type = notification.event_type
    @unsubscribe_url = unsubscribe_url(Notifications::Unsubscribe.token_for(@user, @event_type))
    @settings_url = account_url
    @cta_url = public_send("#{Notifications::Catalogue.fetch(notification.kind).target}_url")

    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    headers["Auto-Submitted"] = "auto-generated"

    mail(to: @user.email, subject: @message.subject)
  end
end
