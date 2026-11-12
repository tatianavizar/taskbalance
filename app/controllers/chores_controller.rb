class ChoresController < ApplicationController
  # Where to go back after adding a task: the screen it was added from.
  RETURN_TO = %w[catalogue split].freeze

  before_action :authenticate_user!
  before_action :set_chore, only: [ :edit, :update, :delete, :destroy ]

  def index
    @chores = current_user.chores.active.includes(:task, :household).order("households.name")
  end

  # C5: a custom task. Any member can add one (decision D14).
  def new
    @household = current_user.household
    @household = nil if params[:household_id].present? && @household&.id != params[:household_id].to_i
    redirect_to households_path, alert: t("chores.flash.household_required") and return unless @household

    @chore = @household.chores.new(frequency: :weekly, assignee_keys: [ "user:#{current_user.id}" ])
    load_form
  end

  def create
    @household = current_user.household
    return redirect_to(households_path, alert: t("chores.flash.household_required")) unless @household

    # Chores are created in the user's own household, whatever the request says.
    @chore = @household.chores.new(chore_params)
    @chore.created_by = current_user
    @chore.status = :pending

    if @chore.save
      redirect_to return_path, notice: created_notice
    else
      load_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form
  end

  def update
    if @chore.update(chore_params)
      redirect_to household_path(@chore.household), notice: t("chores.flash.updated")
    else
      load_form
      render :edit, status: :unprocessable_entity
    end
  end

  # C7: what deleting a custom task keeps.
  def delete
    return redirect_to(household_chores_setup_path(@chore.household), alert: t("chores.flash.cannot_delete_catalogue")) unless @chore.custom_chore?

    @log_counts = @chore.log_counts_by_member
    @logged_minutes = @chore.chore_logs.sum(:time_spent)
  end

  # Any member can delete a custom task (D14). Its logs stay with their
  # authors, detached and still named. A catalogue task is retired from the
  # task list instead.
  def destroy
    unless @chore.custom_chore?
      redirect_to household_chores_setup_path(@chore.household), alert: t("chores.flash.cannot_delete_catalogue")
      return
    end
    household = @chore.household
    @chore.destroy
    redirect_to household_chores_setup_path(household), notice: t("chores.flash.destroyed")
  end

private

  def set_chore
    @chore = current_user.chores.find(params[:id])
    @household = @chore.household
  rescue ActiveRecord::RecordNotFound
    redirect_to chores_path, alert: t("common.not_authorized")
  end

  def load_form
    @household ||= @chore.household
    @participants = @household.split_participants
    @return_to = RETURN_TO.include?(params[:return_to]) ? params[:return_to] : nil
  end

  def return_path
    case params[:return_to]
    when "split" then household_split_path(@household, mode: "now")
    when "catalogue" then household_chores_setup_path(@household)
    else @household.setup_done? ? household_path(@household) : household_setup_path(@household)
    end
  end

  # A task added while this week's split is validated is logged outside the
  # split until Monday's proposal (D14).
  def created_notice
    plan = @household.week_plan_for(@household.current_week)
    plan&.locked? ? t("chores.flash.created_outside_split") : t("chores.flash.created")
  end

  def chore_params
    permitted = params.require(:chore).permit(
      :custom_name, :category, :mental_load, :execution_load, :time_required,
      :frequency, :times_per_period, :anchor_on, assignee_keys: []
    )
    # A catalogue task keeps its name and category.
    permitted = permitted.except(:custom_name, :category) if @chore&.catalogue_chore?
    permitted
  end
end
