class HouseholdMembersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_household

  def new
    @household_member = HouseholdMember.new
  end

  def create
    email = household_member_params[:email].to_s.strip
    user = User.find_by(email: email)

    if user
      add_existing_member(user)
    else
      send_invitation(email)
    end
  end

  private

  def add_existing_member(user)
    member = @household.household_members.new(user: user)
    if member.save
      redirect_to household_path(@household), notice: t("household_members.flash.created", email: user.email)
    else
      # Same answer whatever the reason (already in a household, household full):
      # the form must not tell whether an account exists for this address.
      @household_member = HouseholdMember.new(email: user.email)
      @household_member.errors.add(:email, :cannot_join)
      render :new, status: :unprocessable_entity
    end
  end

  def send_invitation(email)
    invitation = Invitation.find_or_initialize_by(email: email, household_id: @household.id)
    if invitation.new_record?
      unless invitation.save
        @household_member = HouseholdMember.new(email: email)
        @household_member.errors.add(:email, invitation.errors[:email].first)
        return render :new, status: :unprocessable_entity
      end
      InvitationMailer.invite(invitation).deliver_now
    end
    redirect_to household_path(@household), notice: t("household_members.flash.invited", email: email)
  end

  def set_household
    @household = find_own_household!(params[:household_id])
  end

  def household_member_params
    params.require(:household_member).permit(:email)
  end
end
