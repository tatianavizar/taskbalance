# E8, E9, E13: the household's level, the ladder and, at the ultimate level,
# the margin before it is lost.
class LevelsController < ApplicationController
  before_action :authenticate_user!

  def show
    @household = current_user.household
    return redirect_to(dashboard_path) unless @household

    @summary = LevelSummary.new(@household)
  end
end
