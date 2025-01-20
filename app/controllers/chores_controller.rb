class ChoresController < ApplicationController

  def index
    @chores = Chore.all
  end

  def new
    @chore = Chore.new
    @tasks = Task.all
  end

  def create
    add_task_to_chores
  end

private

  def add_task_to_chores
    @task = Task.find(params[:id])
    @chore = Chore.new(@task)
    if @chore.save
      redirect_to household_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def tasks_params
    params.require(:task).permit(:name, :time_required, :frequency)
  end

  def chore_params
    params.require(:chore).permit(:household_id, :task_id, :status)
  end

end
