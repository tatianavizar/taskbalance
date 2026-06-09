class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @household = invitation.household
    @signup_url = new_user_registration_url(invitation_token: invitation.token)

    mail(
      to: invitation.email,
      subject: "You've been invited to join #{@household.name} on 50/50"
    )
  end
end
