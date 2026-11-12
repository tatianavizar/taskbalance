# The invitee's side of an invitation (B7 to B9, B12). The token in the URL is
# the only credential: it is long, random, never listed anywhere and never
# stored (only its digest is: Invitation.find_by_token).
#
# The person who claimed an invitation (signed in, not joined yet) reaches
# B12 and the refusal without the token, through /invitation/... (the app
# cannot rebuild the link): those routes read Invitation.live_for_invitee.
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

  before_action :authenticate_user!, unless: -> { params[:token] }
  before_action :set_invitation, except: :resume
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
      redirect_to back_to_invitation
    end
  end

  # The last step. Lot 2's final screen (B11, B14) posts here.
  def accept
    if @invitation.accept!(current_user)
      session.delete(:invitation_token)
      redirect_to household_path(@invitation.household), notice: t("invitations.flash.joined")
    else
      redirect_to back_to_invitation, alert: @invitation.errors.full_messages.to_sentence
    end
  end

  # B9 "Refuser", B12 "Ne pas rejoindre ce foyer".
  def decline
    if @invitation.decline!(current_user)
      session.delete(:invitation_token)
      redirect_to dashboard_path, notice: t("invitations.flash.declined")
    else
      redirect_to back_to_invitation
    end
  end

  # B12: the setup is not finished. Once it is, the invitee goes on to B10.
  def waiting
    return redirect_to(back_to_invitation) unless @invitation&.grants_setup_access_to?(current_user)

    @household = @invitation.household
    @setup_ready = @household.setup_ready_for_invitee?
  end

  # GET /invitation: the claimed invitation, wherever the person is in it.
  def resume
    invitation = pending_invitation_of(current_user)
    redirect_to(invitation ? invitee_resume_path(invitation) : dashboard_path)
  end

  private

  # By the token of the link, or (no token: /invitation/...) the invitation
  # the signed-in person claimed.
  def set_invitation
    @invitation = if params[:token]
      Invitation.includes(:household, :inviter).find_by_token(params[:token].to_s)
    else
      pending_invitation_of(current_user)
    end
    return render_invalid(:unknown, status: :not_found) unless @invitation

    @invitation.expire_if_due!
  end

  def require_sign_in
    return if user_signed_in?

    redirect_to(@invitation&.token ? invitation_path(@invitation.token) : new_user_session_path)
  end

  def back_to_invitation
    @invitation&.token ? invitation_path(@invitation.token) : dashboard_path
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
