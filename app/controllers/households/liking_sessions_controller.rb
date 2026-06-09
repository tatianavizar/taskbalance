module Households
  class LikingSessionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_household

    def show
      chores = @household.chores.includes(:task).order("tasks.category", "tasks.name")
      @tasks_by_category = chores.map(&:task).group_by(&:category)
      @liked_by_task_id = current_user.liked_tasks
                            .where(task_id: chores.map(&:task_id))
                            .index_by(&:task_id)
    end

    def update
      (params[:preferences] || {}).each do |task_id, liked|
        record = LikedTask.find_or_initialize_by(user: current_user, task_id: task_id.to_i)
        record.liked = liked == "true"
        record.save!
      end

      redirect_to household_path(@household), notice: t("tasks.liking_session.flash.saved")
    end

    private

    def set_household
      @household = current_user.households.find(params[:household_id])
    end
  end
end
