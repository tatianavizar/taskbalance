# Who may open the preferences and the split of a household, and as whom:
# its members, and the person who claimed a live invitation to it and has
# not joined yet (B10, B11, B14; Invitation#grants_setup_access_to?).
module SplitAccess
  extend ActiveSupport::Concern

  included do
    helper_method :current_participant, :current_invitation
  end

  private

  def split_household!(id)
    household = current_user.household
    return household if household && household.id == id.to_i

    invitation = current_invitation
    raise ActiveRecord::RecordNotFound unless invitation && invitation.household_id == id.to_i

    invitation.household
  end

  # The invitation the signed-in person is working through, when they may
  # still use it.
  def current_invitation
    return @current_invitation if defined?(@current_invitation)

    invitation = Invitation.live_for_invitee(current_user)
    @current_invitation = invitation&.grants_setup_access_to?(current_user) ? invitation : nil
  end

  def current_participant
    @current_participant ||= @household&.split_participant_for(current_user)
  end

  # The invited person waits on B12 until the set-up is over.
  def require_participant!
    raise ActiveRecord::RecordNotFound unless current_participant
    return unless current_participant.provisional? && !@household.setup_ready_for_invitee?

    redirect_to waiting_invitation_path(current_invitation.token)
  end
end
