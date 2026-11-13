# Invitation tokens are stored as digests only: a row read back from the
# database has no `token`. Tests that need to open the link of such a row
# give it a fresh one (what a resend does, without the email and counters).
module InvitationHelpers
  def with_link_token(invitation)
    token = SecureRandom.urlsafe_base64(32)
    invitation.update_columns(token_digest: Invitation.digest_token(token))
    invitation.token = token
    invitation
  end

  # The token in the link of an invitation email.
  def token_in_mail(mail)
    mail.text_part.body.to_s[%r{/invitations/([A-Za-z0-9_-]+)}, 1]
  end
end

ActiveSupport::TestCase.include InvitationHelpers
ActionDispatch::IntegrationTest.include InvitationHelpers
