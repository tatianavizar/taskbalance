module Households
  # The household's tasks: C1 during the set-up, M1 afterwards (Foyer ›
  # Tâches du foyer). Any member can change them (decision D14).
  #
  # Ticking a catalogue task adds a chore with the task's defaults, assigned
  # by the proposal (D18), or brings back the chore retired earlier. Unticking
  # retires it (backlog 3.4): its logs stay, and if it was ever logged the
  # member confirms first (C2). Custom chores are not part of the list: they
  # are deleted one by one (C7).
  class ChoresSetupController < ApplicationController
    before_action :authenticate_user!
    before_action :set_household

    def show
      load_catalogue
      @ticked_task_ids =
        if @household.chores.catalogue.exists?
          @household.chores.catalogue.active.pluck(:task_id).to_set
        else
          # First visit: the regular tasks are ticked (C1).
          Task.where(recurring: true).pluck(:id).to_set
        end
    end

    def update
      task_ids = submitted_task_ids
      active = @household.chores.catalogue.active.includes(:task).group_by(&:task_id)
      to_retire = active.values_at(*(active.keys - task_ids)).flatten
      logged = to_retire.select { |chore| chore.chore_logs.exists? }

      if logged.any? && params[:confirm_retire] != "1"
        @task_ids = task_ids
        @logged = logged
        return render :confirm_retire, status: :unprocessable_entity
      end

      if @household.setup_step == "tasks" && task_ids.empty? && !@household.chores.custom.active.exists?
        load_catalogue
        @ticked_task_ids = Set.new
        flash.now[:alert] = t("chores.setup.flash.none_chosen")
        return render :show, status: :unprocessable_entity
      end

      Chore.transaction do
        retire(to_retire)
        add(task_ids - active.keys)
      end

      was_setting_up = !@household.setup_done?
      @household.complete_setup_step!("tasks")
      if was_setting_up
        redirect_to household_setup_path(@household)
      else
        redirect_to household_path(@household), notice: t("chores.setup.flash.saved")
      end
    end

    private

    def load_catalogue
      @tasks_by_category = Task.order(:category, :name).group_by(&:category)
      @custom_chores = @household.chores.custom.active.order(:custom_name)
    end

    def retire(chores)
      # The status of a chore says nothing about its definition: no
      # validation runs (an older chore may have no assignee yet).
      chores.each { |chore| chore.update_columns(active: false, updated_at: Time.current) }
    end

    # New chores first go to every participant (a chore always has an
    # assignee), then the proposal places them; chores already there keep
    # their assignees.
    def add(task_ids)
      return if task_ids.empty?

      # The oldest retired chore of each task comes back (older databases can
      # hold several chores per task).
      retired = @household.chores.catalogue.retired.where(task_id: task_ids).order(:id)
                          .group_by(&:task_id).transform_values(&:first)
      everyone = @household.split_participants.map(&:key)
      new_ids = []
      Task.where(id: task_ids).find_each do |task|
        if (chore = retired[task.id])
          chore.update_columns(active: true, updated_at: Time.current)
        else
          chore = @household.chores.create!(task.chore_defaults.merge(created_by: current_user, status: :pending,
                                                                      assignee_keys: everyone))
          new_ids << chore.id
        end
      end
      @household.propose_split!(keep: @household.chores.active.pluck(:id) - new_ids) if new_ids.any?
    end

    # Checkbox forms submit a blank entry alongside the real ids, which would
    # otherwise cast to task_id 0. Unknown ids are dropped.
    def submitted_task_ids
      ids = Array(params[:task_ids]).map(&:to_i).reject(&:zero?)
      return [] if ids.empty?

      Task.where(id: ids).pluck(:id)
    end

    def set_household
      @household = find_own_household!(params[:household_id])
    end
  end
end
