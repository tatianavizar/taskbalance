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

  # Lot 2 replaces the :preferences branch with B10, then B11 or B14. Until
  # then both stages open the waiting screen (B12).
  def invitee_resume_path(invitation)
    case invitation.resume_stage
    when :preferences then waiting_invitation_path(invitation.token)
    else waiting_invitation_path(invitation.token)
    end
  end
end
