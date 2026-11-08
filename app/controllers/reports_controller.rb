class ReportsController < ApplicationController
  before_action :authenticate_user!

  # Page vide en attendant le premier bilan hebdomadaire.
  def show
  end
end
