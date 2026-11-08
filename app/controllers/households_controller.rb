class HouseholdsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_household, only: [ :show, :edit, :update, :destroy ]

  # There is one household per account: no list, only the household itself or
  # the creation screen.
  def index
    if current_user.household
      redirect_to household_path(current_user.household)
    else
      redirect_to new_household_path
    end
  end

  def new
    return redirect_to(household_path(current_user.household), alert: t("households.flash.already_member")) if current_user.household

    @household = Household.new(time_zone: current_user.time_zone)
  end

  def create
    if current_user.household
      return redirect_to(household_path(current_user.household), alert: t("households.flash.already_member"))
    end

    @household = Household.create_for(current_user, household_params)
    if @household.persisted?
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
    redirect_to new_household_path, notice: t("households.flash.destroyed")
  end

  private

  def set_household
    @household = find_own_household!(params[:id])
  end

  def household_params
    params.require(:household).permit(:name, :time_zone)
  end
end
