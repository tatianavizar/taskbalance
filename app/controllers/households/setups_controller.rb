module Households
  # The set-up checklist (« Mise en place 2 sur 4 »): opens the step to
  # resume at. Step 2 (the partner) has its own screen here; the tasks and
  # the split have theirs.
  class SetupsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_household

    def show
      case @household.setup_step
      when "partner"
        @invitations = @household.pending_invitations
      when "tasks" then redirect_to household_chores_setup_path(@household)
      when "split" then redirect_to household_split_path(@household)
      else redirect_to household_path(@household)
      end
    end

    # Leaves the partner step, with or without an invitation sent.
    def update
      @household.complete_setup_step!("partner")
      redirect_to household_setup_path(@household)
    end

    private

    def set_household
      @household = find_own_household!(params[:household_id])
    end
  end
end
