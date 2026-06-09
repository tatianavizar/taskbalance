class ChoresController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chore, only: [:edit, :update, :destroy, :mark_as_completed]

  def index
    @chores = current_user.chores.includes(:task, :household).order("households.name")
  end

  def new
    @household = current_user.households.find_by(id: params[:household_id])
    redirect_to households_path, alert: t("chores.flash.household_required") and return unless @household

    @chore = Chore.new(household: @household)
    @members = @household.users
  end

  def create
    @chore = Chore.new(chore_params)
    @chore.status = :pending

    if @chore.save
      redirect_to household_path(@chore.household), notice: t("chores.flash.created")
    else
      @household = @chore.household
      @members = @household&.users || []
      render :new, status: :unprocessable_entity
    end
  end

  def add
    task_ids = params[:task_ids] || []
    household_id = params[:household_id]

    if task_ids.any?
      task_ids.each do |task_id|
        Chore.create!(task_id: task_id, household_id: household_id, status: :pending)
      end
      redirect_to chores_path, notice: t("chores.flash.added")
    else
      redirect_to tasks_path, alert: t("chores.flash.none_selected")
    end
  end

  def edit
    @household = @chore.household
    @members = @household.users
  end

  def update
    if @chore.update(chore_params)
      redirect_to household_path(@chore.household), notice: t("chores.flash.updated")
    else
      @household = @chore.household
      @members = @household.users
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @chore.custom_chore?
      redirect_to household_path(@chore.household), alert: t("chores.flash.cannot_delete_catalogue")
      return
    end
    household = @chore.household
    @chore.destroy
    redirect_to household_path(household), notice: t("chores.flash.destroyed")
  end

  def mark_as_completed
    @chore.completed!
    redirect_to chores_path
  end

private

  def set_chore
    @chore = current_user.chores.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to chores_path, alert: t("common.not_authorized")
  end

  def chore_params
    params.require(:chore).permit(
      :household_id, :task_id, :custom_name, :category, :assigned_to_id,
      :mental_load, :execution_load,
      :time_required, :due_date
    )
  end
end
