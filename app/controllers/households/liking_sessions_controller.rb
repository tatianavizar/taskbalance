module Households
  class LikingSessionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_household

    def show
      chores = @household.chores.where.not(task_id: nil)
                 .includes(:task).references(:task)
                 .order("tasks.category", "tasks.name")
      @tasks_by_category = chores.map(&:task).group_by(&:category)
      @liked_by_task_id = current_user.liked_tasks
                            .where(task_id: chores.map(&:task_id))
                            .index_by(&:task_id)
    end

    def update
      submitted = params[:preferences]
      preferences = submitted.respond_to?(:to_unsafe_h) ? submitted.to_unsafe_h : {}
      # Only tasks that are chores of this household can be rated: a forged
      # task_id is refused as a whole, nothing is written.
      allowed_ids = @household.chores.where.not(task_id: nil).pluck(:task_id)
      return head :unprocessable_entity unless preferences.keys.all? { |id| allowed_ids.include?(id.to_i) }

      LikedTask.transaction do
        preferences.each do |task_id, liked|
          record = LikedTask.find_or_initialize_by(user: current_user, task_id: task_id.to_i)
          record.liked = liked == "true"
          record.save!
        end
      end

      redirect_to household_path(@household), notice: t("tasks.liking_session.flash.saved")
    end

    private

    def set_household
      @household = find_own_household!(params[:household_id])
    end
  end
end
