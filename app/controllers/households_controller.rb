class HouseholdsController < ApplicationController

  def index
    @households = Household.all
  end

  def new
    @household = Household.new
  end

  def create
    @household = Household.new(household_params)
    if @household.save
      redirect_to household_path(@household)

    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @household = Household.find(params[:id])
  end

  private

  def household_params
    params.require(:household).permit(:name, :id)
  end

end
