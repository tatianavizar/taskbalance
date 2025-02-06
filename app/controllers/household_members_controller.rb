class HouseholdMembersController < ApplicationController
  before_action :set_current_user
  before_action :set_household, only: [:new, :create]


  def index
    @household_members = HouseholdMember.all
  end

  def new
    @household_member = @household.household_members.new
  end

  def create
    @household_member = @household.household_members.new(household_member_params)
    if @household_member.save
      redirect_to household_members_path, notice: "Invitation envoyée avec succès."
    else
      render :new, status: :unprocessable_entity
    end
  end

private

  def set_current_user
    @user = current_user
  end

  def set_household
    @household = Household.find(params[:household_id])
  end

  def household_members_params
    params.require(:household_member).permit(:user_id)
  end
end
