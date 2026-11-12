module InvitationsHelper
  # The person who sent the invitation. They may have left or deleted their
  # account since: the wording stays neutral.
  def invitation_inviter_name(invitation)
    invitation.inviter&.first_name.presence || t("invitations.someone")
  end

  # Expiry date, read in the household's time zone.
  def invitation_expiry(invitation)
    l(invitation.expires_at.in_time_zone(invitation.household.zone).to_date, format: :short)
  end

  # "k***@gmail.com": the address is shown to a signed-in stranger holding the
  # link (wrong account), so it is masked.
  def masked_email(email)
    local, domain = email.to_s.split("@", 2)
    "#{local.to_s.first}•••@#{domain}"
  end
end
