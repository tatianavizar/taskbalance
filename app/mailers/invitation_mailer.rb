# B6: the invitation email. The link opens the invitation screen, which routes
# a new person to sign-up (B7) and an existing account to its own screen (B9);
# the email never says whether an account exists for the address.
class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @household = invitation.household
    @inviter_name = invitation.inviter&.first_name.presence || t("invitation_mailer.invite.someone")
    @invitation_url = invitation_url(invitation.token)
    @expires_on = I18n.l(invitation.expires_at.in_time_zone(@household.zone).to_date, format: :short)

    mail(
      to: invitation.email,
      subject: t("invitation_mailer.invite.subject", inviter: @inviter_name, household: @household.name)
    )
  end
end
