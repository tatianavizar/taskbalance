module Households
  # The split of the week.
  #
  #   choice   C12: during the set-up, when someone is invited but not in yet,
  #            « Proposer maintenant » or « Attendre ».
  #   show     C4/C8: the split, editable until everyone validated; read-only
  #            once validated (locked until Monday). The person invited sees
  #            B11 (a split was proposed) or B14 (they propose it).
  #   update   saves the assignments. « Valider la répartition » proposes
  #            (or edits) the week plan with the acting person's validation;
  #            « Mettre à jour les parts » only recomputes the shares.
  #   approve  validates the split as it is.
  #   wait     C12 « Attendre ».
  class SplitsController < ApplicationController
    include SplitAccess

    before_action :authenticate_user!
    before_action :set_household
    before_action :require_participant!
    before_action :set_plan

    def choice
      redirect_to household_split_path(@household) unless choice_needed?
    end

    def show
      return redirect_to(choice_household_split_path(@household)) if choice_needed? && params[:mode] != "now"

      load_split
    end

    def update
      return redirect_to(household_split_path(@household), alert: t("split.flash.locked")) if @plan&.locked?

      assignments = submitted_assignments
      if params[:commit_action] == "recompute"
        @household.assign_chores!(assignments, by: current_user)
        return redirect_to(household_split_path(@household, mode: "now"))
      end

      if @plan&.proposed? && unchanged?(assignments)
        # Validating the split as it is: the others' validations stand.
        @plan.approve!(by: current_user)
      elsif @plan&.proposed?
        @plan.update_assignments!(by: current_user, assignments: assignments)
      else
        @household.assign_chores!(assignments, by: current_user)
        @plan = WeekPlan.propose!(household: @household, by: current_user, kind: starting_kind)
      end
      return join_household if current_participant.provisional?

      @household.complete_setup_step!("split")
      redirect_to dashboard_path, notice: validation_notice
    rescue ActiveRecord::RecordInvalid => e
      load_split
      @error = e.record.errors[:assignees].first || e.record.errors.full_messages.first
      render :show, status: :unprocessable_entity
    end

    def approve
      return redirect_to(household_split_path(@household)) unless @plan&.proposed?

      @plan.approve!(by: current_user)
      redirect_to household_split_path(@household), notice: validation_notice
    end

    def wait
      return redirect_to(household_split_path(@household)) unless choice_needed?

      WeekPlan.await_proposal!(household: @household)
      @household.complete_setup_step!("split")
      redirect_to dashboard_path, notice: t("split.flash.waiting")
    end

    private

    def set_household
      @household = split_household!(params[:household_id])
    end

    def set_plan
      @plan = @household.week_plan_for(@household.current_week)
    end

    # C12 is asked once, during the set-up, when someone invited has not
    # joined yet and nothing was proposed.
    def choice_needed?
      @household.setup_step == "split" && @plan.nil? && @household.pending_invitations.exists?
    end

    def starting_kind
      return :starting if @plan&.starting?

      @household.setup_done? && @household.starting_plan ? :weekly : :starting
    end

    # B11 « Rejoindre le foyer », B14 « Proposer et rejoindre le foyer »: the
    # split is saved with the invited person's validation, then they join
    # (lot 3's Invitation#accept!, which hands their assignments over).
    def join_household
      invitation = current_invitation
      if invitation&.accept!(current_user)
        session.delete(:invitation_token)
        redirect_to household_path(@household), notice: t("invitations.flash.joined")
      else
        redirect_to household_split_path(@household), alert: invitation&.errors&.full_messages&.to_sentence
      end
    end

    def load_split
      @locked = @plan&.locked?
      @split =
        if @plan && !@plan.awaiting_proposal? && @locked
          @plan.split
        else
          PlannedSplit.from_household(@household, participants: @household.split_participants(include_invitations: starting_kind == :starting))
        end
    end

    # { chore_id => [participant keys] }. Each row of the form sends an
    # empty entry so that a chore with every box unticked reaches the
    # validation (at least one assignee) instead of being skipped.
    def submitted_assignments
      raw = params[:assignments]
      raw = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : {}
      raw.to_h { |chore_id, keys| [ chore_id.to_i, Array(keys).compact_blank ] }
    end

    def unchanged?(assignments)
      planned = @plan.assignments.to_h { |item| [ item["chore_id"], item["assignees"].sort ] }
      assignments.all? { |chore_id, keys| planned[chore_id] == keys.sort }
    end

    def validation_notice
      return t("split.flash.validated") if @plan.validated?

      t("split.flash.sent", names: @plan.pending_participants.map(&:first_name).to_sentence)
    end
  end
end
