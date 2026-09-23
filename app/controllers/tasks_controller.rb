class TasksController < ApplicationController
  before_action :authenticate_user!

  def index
    @tasks_by_category = Task.order(:category, :name).group_by(&:category)
  end
end
