module Households
  class ChoresSetupController < ApplicationController
    before_action :authenticate_user!
    before_action :set_household

    def show
      @tasks_by_category = Task.order(:category, :name).group_by(&:category)
      @existing_task_ids = @household.chores.pluck(:task_id).to_set
    end

    def update
      task_ids = (params[:task_ids] || []).map(&:to_i)
      existing_task_ids = @household.chores.pluck(:task_id).to_set

      Chore.transaction do
        new_ids = task_ids - existing_task_ids.to_a
        new_ids.each { |id| @household.chores.create!(task_id: id, status: :pending) }

        removed_ids = existing_task_ids.to_a - task_ids
        @household.chores.where(task_id: removed_ids).destroy_all
      end

      # TODO: notify all household members of added chores (notification system TBD)

      redirect_to household_path(@household), notice: t("chores.setup.flash.saved")
    end

    private

    def set_household
      @household = current_user.households.find(params[:household_id])
    end
  end
end
