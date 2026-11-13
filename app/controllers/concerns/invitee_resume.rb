# Resuming an invitation (lot 3): a person who has claimed an invitation but
# has not joined yet comes back to the right screen after signing in, or after
# the app restarts.
module InviteeResume
  extend ActiveSupport::Concern

  included do
    helper_method :invitee_resume_path, :pending_invitation_of
  end

  # The live invitation the signed-in person is working through, if they are
  # still in no household.
  def pending_invitation_of(user)
    return unless user && user.household_membership.nil?

    Invitation.live_for_invitee(user)
  end

  # :waiting opens B12; :preferences opens B10, which leads to B11 (a split
  # was proposed) or B14 (the creator chose « Attendre »).
  def invitee_resume_path(invitation)
    case invitation.resume_stage
    when :style then household_member_style_path(invitation.household)
    when :preferences then household_preferences_path(invitation.household)
    else invitee_waiting_path
    end
  end
end
