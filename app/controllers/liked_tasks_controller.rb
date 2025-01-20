class LikedTasksController < ApplicationController

  def initializer
    @user = current_user
    @tasks = Task.all
  end
  def new
    @liked_task = LikedTask.new
  end

  def create
    @liked_task = Like.new(
      id_user: current_user.id,
      id_task: Task.find(params[:id_task]),
      liked: params[:liked]
    )
  end
end
