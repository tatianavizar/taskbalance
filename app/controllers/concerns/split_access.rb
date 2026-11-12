# Who may open the preferences and the split of a household, and as whom.
#
# Today: its members. Lot 3 adds the person invited but not yet in (B10,
# B11, B14): it only has to let `split_household!` find the household
# through the invitation (invitations.invitee_id) and make
# Household#invitee_participant_for return that person's participant. The
# screens and the models already take the acting participant as a parameter.
module SplitAccess
  extend ActiveSupport::Concern

  included do
    helper_method :current_participant
  end

  private

  def split_household!(id)
    find_own_household!(id)
  end

  def current_participant
    @current_participant ||= @household&.split_participant_for(current_user)
  end

  def require_participant!
    raise ActiveRecord::RecordNotFound unless current_participant
  end
end
