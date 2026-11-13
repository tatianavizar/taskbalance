class HouseholdsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_household, only: [ :show, :edit, :update, :delete, :destroy ]

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
      # On to step 2 of the set-up.
      redirect_to household_setup_path(@household), notice: t("households.flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # F1
  def show
    @members = @household.household_members.includes(:user).order(:created_at, :id).to_a
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

  # F3: only the manager sees the form.
  def delete
    @deletion = HouseholdDeletion.new(@household, by: current_user)
    redirect_to household_path(@household), alert: t("households.delete.manager_only") unless @deletion.allowed?
  end

  # F3: manager only, after typing the household's name (backlog 3.5).
  def destroy
    @deletion = HouseholdDeletion.new(@household, by: current_user,
                                      confirmation_name: params.dig(:household_deletion, :confirmation_name))
    return redirect_to(household_path(@household), alert: t("households.delete.manager_only")) unless @deletion.allowed?

    if @deletion.save
      redirect_to dashboard_path(departed: 1), notice: t("households.flash.destroyed", name: @household.name)
    else
      render :delete, status: :unprocessable_entity
    end
  end

  private

  def set_household
    @household = find_own_household!(params[:id])
  end

  def household_params
    params.require(:household).permit(:name, :time_zone)
  end
end
