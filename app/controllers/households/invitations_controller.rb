# The household's side of an invitation (B3 to B5, B13, B15): any member can
# invite, follow, resend and cancel. The addressee's side is InvitationsController.
class Households::InvitationsController < ApplicationController
  # An email-sending endpoint: no one floods an inbox through here.
  rate_limit to: 20, within: 1.hour, only: %i[create resend], name: "invitation-sends",
             by: -> { current_user&.id || request.remote_ip },
             with: -> { redirect_back_or_to(dashboard_path, alert: t("invitations.flash.rate_limited")) }

  before_action :authenticate_user!
  before_action :set_household
  before_action :set_invitation, only: %i[show destroy resend cancel]

  # B3
  def new
    @invitation = Invitation.new(email: params[:email])
  end

  # Every answer is the same whether or not the address has an account: the
  # invitation always goes through the invitee's consent (backlog 3.1).
  def create
    @invitation = Invitation.invite(household: @household, email: params.dig(:invitation, :email), inviter: current_user)
    if @invitation.persisted?
      redirect_to household_invitation_path(@household, @invitation), notice: t("invitations.flash.sent")
    else
      @pending = @household.invitations.live.find_by(email: @invitation.email) if @invitation.errors.of_kind?(:email, :already_invited)
      render :new, status: :unprocessable_entity
    end
  end

  # B5 (pending or expired), B13 (declined). Cancelled and accepted invitations
  # have nothing left to show.
  def show
    return redirect_to(household_path(@household)) if @invitation.cancelled? || @invitation.accepted?

    @allowance = @invitation.resend_allowance if @invitation.usable?
  end

  # B15, the confirmation sheet.
  def cancel
    redirect_to household_invitation_path(@household, @invitation) unless @invitation.usable?
  end

  def destroy
    if @invitation.cancel!
      redirect_to household_path(@household), notice: t("invitations.flash.cancelled")
    else
      redirect_to household_invitation_path(@household, @invitation), alert: t("invitations.flash.not_cancellable")
    end
  end

  # Only the sender can resend: anyone else gets a 404, as if it did not exist.
  def resend
    raise ActiveRecord::RecordNotFound unless @invitation.resendable_by?(current_user)

    verdict, seconds = @invitation.resend!
    path = household_invitation_path(@household, @invitation)
    case verdict
    when :ok then redirect_to path, notice: t("invitations.flash.resent")
    when :wait then redirect_to path, alert: t("invitations.flash.resend_wait", minutes: (seconds / 60.0).ceil)
    when :limit then redirect_to path, alert: t("invitations.flash.resend_limit", max: Invitation::MAX_RESENDS)
    else redirect_to path
    end
  end

  private

  def set_household
    @household = find_own_household!(params[:household_id])
  end

  # Only this household's invitations: another household's id is a 404.
  def set_invitation
    @invitation = @household.invitations.find(params[:id])
    @invitation.expire_if_due!
  end
end
