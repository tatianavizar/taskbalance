class ChoresController < ApplicationController
  def initializer

  end
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

  def add
    # 1) Récupérer la liste d'IDs des tâches cochées
    task_ids = params[:task_ids] || []  # tableau ou liste vide par défaut
    household_id = params[:household_id] || current_user.household.id

    # 2) Pour chaque tâche sélectionnée, on crée un Chore
    if task_ids.any?
      task_ids.each do |task_id|
        Chore.create!(
          task_id: task_id,
          household_id: household_id,
          status: 0  # => 'pending'
        )
      end
      redirect_to chores_path, notice: "Les tâches sélectionnées ont été ajoutées comme chores."
    else
      redirect_to tasks_path, alert: "Aucune tâche sélectionnée."
    end
  end

private

  def add_task_to_chores
    @chore = Chore.new(chore_params)
    @chore.status = 0
    if @chore.save
      redirect_to household_path
    else
      @tasks = Task.all
      render :new, status: :unprocessable_entity
    end
  end

  def chore_params
    params.require(:chore).permit(:household_id, :task_id, :status)
  end

end
