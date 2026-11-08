module Chores
  # Completing a chore records a ChoreLog: who did it, which of the two load
  # dimensions it involved, and how long it took. The chore itself is marked
  # completed, and a recurring chore spawns its next occurrence.
  class CompletionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_chore

    def new
      @chore_log = build_prefilled_log
    end

    def create
      # A member only logs what they did themselves: the author is always
      # current_user, whatever the request carries.
      @chore_log = @chore.chore_logs.new(chore_log_params)
      @chore_log.user = current_user
      @chore_log.completed_at = Time.current

      ChoreLog.transaction do
        @chore_log.save!
        @chore.completed!
      end

      spawn_next_occurrence
      redirect_to chores_path, notice: t("chore_logs.flash.created", chore: @chore.effective_name)
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    private

    # Prefilled from the chore, but every value stays editable: the log records
    # what actually happened, not what the chore declared.
    def build_prefilled_log
      @chore.chore_logs.new(
        user: current_user,
        mental_load: @chore.mental_load,
        execution_load: @chore.execution_load,
        time_spent: @chore.effective_time_required
      )
    end

    # A recurring chore whose template is assigned but carries no load dimension
    # cannot produce a valid Chore. That is the scheduler's problem, and it must
    # never cost the user the log they just filled in, so this runs outside the
    # transaction and swallows the failure.
    def spawn_next_occurrence
      recurring = @chore.recurring_chore
      return if recurring.nil?

      RecurringChoreScheduler.generate_next(recurring)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("Could not spawn next occurrence of recurring_chore #{recurring.id}: #{e.message}")
    end

    def set_chore
      @chore = current_user.chores.find(params[:chore_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to chores_path, alert: t("common.not_authorized")
    end

    def chore_log_params
      params.require(:chore_log).permit(:mental_load, :execution_load, :time_spent)
    end
  end
end
