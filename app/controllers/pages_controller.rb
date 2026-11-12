class PagesController < ApplicationController
  before_action :authenticate_user!, only: [:dashboard]

  # A1: welcome screen for people who are not signed in. Signed in, the app
  # opens on its home.
  def home
    return redirect_to(dashboard_path) if user_signed_in?

    @intro_seen = cookies[:intro_seen].present?
  end

  def dashboard
    household = current_user.household
    @home = HomeSummary.new(household: household, viewer: current_user) if household
  end
end
