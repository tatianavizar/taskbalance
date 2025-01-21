class HouseholdsController < ApplicationController

  def new
    @household = Household.new
  end

  def create
    @household = Household.new(household_params)
    if @household.save
      redirect_to household_members_path

    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def household_params
    params.require(:household).permit(:name)
  end

end
