class HouseholdsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_household, only: [:show, :edit, :update, :destroy]

  def index
    @households = current_user.households
  end

  def new
    @household = Household.new
  end

  def create
    @household = Household.new(household_params)
    if @household.save
      @household.household_members.create!(user: current_user)
      redirect_to household_path(@household), notice: t("households.flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @household.update(household_params)
      redirect_to household_path(@household), notice: t("households.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @household.destroy
    redirect_to households_path, notice: t("households.flash.destroyed")
  end

  private

  def set_household
    @household = current_user.households.find(params[:id])
  end

  def household_params
    params.require(:household).permit(:name)
  end
end
