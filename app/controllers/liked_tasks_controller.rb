class LikedTasksController < ApplicationController
  before_action :authenticate_user!

  def create
    @liked_task = LikedTask.new(
      user_id: current_user.id,
      task_id: params[:task_id],
      liked: params[:liked]
    )
    if @liked_task.save
      redirect_to tasks_path, notice: t("liked_tasks.flash.saved")
    else
      redirect_to tasks_path, alert: t("liked_tasks.flash.error")
    end
  end
end
