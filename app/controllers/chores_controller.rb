class ChoresController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chore, only: [:edit, :update, :destroy, :mark_as_completed]

  def index
    @chores = current_user.chores
  end

  def new
    @chore = Chore.new
    @tasks = Task.all
  end

  def create
    @chore = Chore.new(chore_params)
    @chore.status = :pending
    if @chore.save
      redirect_to household_path(@chore.household)
    else
      @tasks = Task.all
      render :new, status: :unprocessable_entity
    end
  end

  def add
    task_ids = params[:task_ids] || []
    household_id = params[:household_id]

    if task_ids.any?
      task_ids.each do |task_id|
        Chore.create!(task_id: task_id, household_id: household_id, status: :pending)
      end
      redirect_to chores_path, notice: "Les tâches sélectionnées ont été ajoutées."
    else
      redirect_to tasks_path, alert: "Aucune tâche sélectionnée."
    end
  end

  def edit; end

  def update
    if @chore.update(chore_params)
      redirect_to chores_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @chore.destroy
    redirect_to chores_path
  end

  def remove
    @chore = Chore.find(params[:id])
    @chore.destroy
    redirect_to chores_path
  end

  def mark_as_completed
    @chore.completed!
    redirect_to chores_path
  end

private

  def set_chore
    @chore = Chore.find(params[:id])
  end

  def chore_params
    params.require(:chore).permit(:household_id, :task_id, :status, :user_id, :mental_load, :execution_load)
  end
end
