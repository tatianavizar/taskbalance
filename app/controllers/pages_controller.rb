class PagesController < ApplicationController
  before_action :authenticate_user!, only: [ :dashboard, :household ]

  # A1: welcome screen for people who are not signed in. Signed in, the app
  # opens on its home.
  def home
    return redirect_to(dashboard_path) if user_signed_in?

    @intro_seen = cookies[:intro_seen].present?
  end

  # The « Foyer » tab of the native shells (lot 9) needs one fixed address:
  # the person's household, or its creation when they have none yet.
  def household
    household = current_user.household
    redirect_to household ? household_path(household) : new_household_path
  end

  def dashboard
    household = current_user.household
    return unless household

    @home = HomeSummary.new(household: household, viewer: current_user)
    @alerts = HouseholdAlerts.new(household, current_user)
  end
end
