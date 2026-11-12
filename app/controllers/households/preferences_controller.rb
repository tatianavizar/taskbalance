module Households
  # Mes préférences (C3), and the invited person's preferences (B10, lot 3):
  # J'aime, Neutre or Je n'aime pas for each active chore, custom chores
  # included. Nobody else ever sees them; the proposal uses them (D18).
  class PreferencesController < ApplicationController
    include SplitAccess

    before_action :authenticate_user!
    before_action :set_household
    before_action :require_participant!

    def show
      @chores = @household.chores.active.includes(:task).sort_by { |c| [ Chore::CATEGORIES.index(c.effective_category) || 99, c.effective_name.to_s ] }
      @choices = ChorePreference.choices_for(current_user, @chores)
    end

    def update
      submitted = params[:preferences]
      choices = submitted.respond_to?(:to_unsafe_h) ? submitted.to_unsafe_h : {}
      # Only active chores of this household can be rated: a forged id or
      # choice is refused as a whole, nothing is written.
      return head :unprocessable_entity unless ChorePreference.record!(current_user, @household, choices)

      # The invited person goes on to the split (B11, B14). A provisional
      # split proposed without their preferences is recomputed (C12).
      if current_participant.provisional?
        plan = @household.starting_plan
        plan.recompute! if plan&.proposed? && plan.provisional?
        return redirect_to(household_split_path(@household))
      end

      redirect_to household_path(@household), notice: t("preferences.flash.saved")
    end

    private

    def set_household
      @household = split_household!(params[:household_id])
    end
  end
end
