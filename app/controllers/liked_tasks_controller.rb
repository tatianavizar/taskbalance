class LikedTasksController < ApplicationController
  before_action :authenticate_user!

  def create
    @liked_task = LikedTask.new(
      user_id: current_user.id,
      task_id: params[:task_id],
      liked: params[:liked]
    )
    if @liked_task.save
      redirect_to tasks_path, notice: "Préférence enregistrée."
    else
      redirect_to tasks_path, alert: "Impossible d'enregistrer la préférence."
    end
  end
end
