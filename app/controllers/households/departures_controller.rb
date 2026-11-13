# F2: leaving the household. The screen says what follows; the button leaves
# (HouseholdMember#leave!, rules in HouseholdDeparture). Then F11.
class Households::DeparturesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_household

  def new
    @membership = current_user.household_membership
    @others = @household.household_members.includes(:user).where.not(id: @membership.id).order(:created_at, :id).to_a
    @chores_count = @household.chores.active.joins(:chore_assignees)
                              .where(chore_assignees: { user_id: current_user.id }).distinct.count
    logs = ChoreLog.where(user_id: current_user.id, household_id: @household.id)
    @logs_count = logs.count
    @first_log_on = logs.minimum(:completed_at)&.in_time_zone(@household.zone)&.to_date
  end

  def create
    name = @household.name
    current_user.household_membership.leave!
    redirect_to dashboard_path(departed: 1), notice: t("households.departure.flash", name: name)
  end

  private

  def set_household
    @household = find_own_household!(params[:household_id])
  end
end
