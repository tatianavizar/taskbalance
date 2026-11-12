# The invitee's side of an invitation (B7 to B9, B12). The token in the URL is
# the only credential: it is long, random and never listed anywhere.
#
# Routing of GET /invitations/:token:
#   unknown token                          -> B8, unknown
#   closed (expired/cancelled/used/declined) -> B8, with its reason
#   signed out                             -> B7 (sign-up; sign-in link)
#   signed in with another address         -> B8, other account
#   signed in, already in a household      -> B9, leave it first (D13)
#   signed in, no household                -> B9 (accept screen)
#
# Whether an address has an account is never revealed: a signed-out visitor
# always gets B7, which offers both sign-up and sign-in.
class InvitationsController < ApplicationController
  rate_limit to: 60, within: 1.minute, only: :show, with: -> { head :too_many_requests }

  before_action :set_invitation
  before_action :require_sign_in, only: %i[claim accept decline waiting]

  def show
    return render_invalid(:unknown, status: :not_found) unless @invitation

    @invitation.expire_if_due!
    return render_invalid(@invitation.current_state.to_sym, status: :gone) unless @invitation.usable?

    # Signing in or up from here comes back to this invitation.
    session[:invitation_token] = @invitation.token
    user_signed_in? ? show_for_signed_in : render_join
  end

  # B9, "Voir la répartition et rejoindre": records the person as invitee. They
  # join only at the last step (lot 2), after seeing the split.
  def claim
    if @invitation.claim_for!(current_user)
      redirect_to invitee_resume_path(@invitation)
    else
      redirect_to invitation_path(@invitation.token)
    end
  end

  # The last step. Lot 2's final screen (B11, B14) posts here.
  def accept
    if @invitation.accept!(current_user)
      session.delete(:invitation_token)
      redirect_to household_path(@invitation.household), notice: t("invitations.flash.joined")
    else
      redirect_to invitation_path(@invitation.token), alert: @invitation.errors.full_messages.to_sentence
    end
  end

  # B9 "Refuser", B12 "Ne pas rejoindre ce foyer".
  def decline
    if @invitation.decline!(current_user)
      session.delete(:invitation_token)
      redirect_to dashboard_path, notice: t("invitations.flash.declined")
    else
      redirect_to invitation_path(@invitation.token)
    end
  end

  # B12: the setup is not finished. Once it is, the invitee goes on to B10.
  def waiting
    return redirect_to(invitation_path(@invitation.token)) unless @invitation&.grants_setup_access_to?(current_user)

    @household = @invitation.household
    @setup_ready = @household.setup_ready_for_invitee?
  end

  private

  def set_invitation
    @invitation = Invitation.includes(:household, :inviter).find_by(token: params[:token].to_s)
    return render_invalid(:unknown, status: :not_found) unless @invitation

    @invitation.expire_if_due!
  end

  def require_sign_in
    return if user_signed_in?

    redirect_to(@invitation ? invitation_path(@invitation.token) : new_user_session_path)
  end

  def show_for_signed_in
    return render_invalid(:other_account) unless @invitation.for?(current_user)

    membership = current_user.household_membership
    return render_invalid(:already_member) if membership&.household_id == @invitation.household_id
    return render :accept, locals: { invitation: @invitation, leave_first: true } if membership
    return redirect_to(invitee_resume_path(@invitation)) if @invitation.invitee_id == current_user.id

    render :accept, locals: { invitation: @invitation, leave_first: false }
  end

  def render_join
    render :join, locals: { invitation: @invitation, user: User.new(email: @invitation.email, first_name: @invitation.first_name) }
  end

  def render_invalid(reason, status: :ok)
    render :invalid, locals: { invitation: @invitation, reason: reason }, status: status
  end
end
