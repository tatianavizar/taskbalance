# I1 to I3: three screens that explain the rules before sign-up. Public, and
# marked as seen so that the welcome screen (A1) stops pushing it afterwards.
# Anyone can reopen it from their account (decision of 2026-11-08).
class IntroController < ApplicationController
  STEPS = 3

  before_action :set_step

  def show
    cookies.permanent[:intro_seen] = { value: "1", httponly: true, same_site: :lax }
  end

  private

  def set_step
    @step = params[:step].to_i
    raise ActionController::RoutingError, "Not Found" unless (1..STEPS).cover?(@step)

    @last = @step == STEPS
    @exit_path = user_signed_in? ? account_path : new_user_registration_path
    @next_path = @last ? @exit_path : intro_path(@step + 1)
  end
end
