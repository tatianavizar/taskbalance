module Households
  class ChoresSetupController < ApplicationController
    before_action :authenticate_user!
    before_action :set_household

    def show
      @tasks_by_category = Task.order(:category, :name).group_by(&:category)
      @existing_task_ids = catalogue_task_ids
    end

    def update
      task_ids = submitted_task_ids
      existing_task_ids = catalogue_task_ids

      Chore.transaction do
        new_ids = task_ids - existing_task_ids.to_a
        new_ids.each { |id| @household.chores.create!(task_id: id, status: :pending) }

        removed_ids = existing_task_ids.to_a - task_ids
        @household.chores.where(task_id: removed_ids).destroy_all if removed_ids.any?
      end

      # TODO: notify all household members of added chores (notification system TBD)

      redirect_to household_path(@household), notice: t("chores.setup.flash.saved")
    end

    private

    # Checkbox forms submit a blank entry alongside the real ids, which would
    # otherwise cast to task_id 0 and blow up on the tasks foreign key.
    def submitted_task_ids
      ids = Array(params[:task_ids]).map(&:to_i).reject(&:zero?)
      return [] if ids.empty?

      Task.where(id: ids).pluck(:id)
    end

    # Custom chores have a nil task_id. They are not part of the catalogue
    # setup and must never be picked up by the add/remove diff below.
    def catalogue_task_ids
      @household.chores.where.not(task_id: nil).pluck(:task_id).to_set
    end

    def set_household
      @household = find_own_household!(params[:household_id])
    end
  end
end
