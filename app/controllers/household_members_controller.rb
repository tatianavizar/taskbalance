class HouseholdMembersController < ApplicationController

  def initializer
    @user = current_user
  end

  def new
    @household_member = HouseholdMember.new
  end

  def create
    @household_member = HouseholdMember.new(household_members_params)
    @household_member.save
  end

private


  def household_members_params
    param_1 = @household_member.household_id = Household.find(params[:id])
    param_2 = @household_member.user_id = @user.id
    params.require(param_1, param_2).permit(:household_id, :user_id)

  end
end
