class HouseholdMembersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_household

  def new
    @household_member = HouseholdMember.new
  end

  def create
    user = User.find_by(email: household_member_params[:email])
    if user.nil?
      @household_member = HouseholdMember.new
      @household_member.errors.add(:email, "aucun compte trouvé avec cet email")
      render :new, status: :unprocessable_entity and return
    end

    @household_member = @household.household_members.new(user: user)
    if @household_member.save
      redirect_to household_path(@household), notice: "#{user.email} a été ajouté(e) au foyer."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_household
    @household = current_user.households.find(params[:household_id])
  end

  def household_member_params
    params.require(:household_member).permit(:email)
  end
end
