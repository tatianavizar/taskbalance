class Users::RegistrationsController < Devise::RegistrationsController
  def new
    session[:invitation_token] = params[:invitation_token] if params[:invitation_token].present?
    super
  end

  def create
    super do |user|
      if user.persisted? && session[:invitation_token].present?
        redeem_invitation(user)
      end
    end
  end

  private

  def redeem_invitation(user)
    invitation = Invitation.find_by(token: session[:invitation_token])
    return unless invitation
    return unless invitation.email.downcase == user.email.downcase

    HouseholdMember.find_or_create_by!(user: user, household_id: invitation.household_id)
    invitation.destroy
    session.delete(:invitation_token)
  end
end
