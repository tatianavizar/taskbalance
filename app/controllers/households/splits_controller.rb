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
  #   preview  (lot 6) the shares of the form as it stands, as a Turbo Stream
  #            replacing the bar. Saves nothing: only « Valider » persists.
  #   reset_gap  C9: the carried gap back to zero, by the member who carried
  #            the surplus only (D4).
  #
  # An edit that takes a share out of the zone is saved with a warning
  # (lot 6). The member above the zone may save it « sans reporter l'écart »
  # (carry_gap=0): that week's real gap is then not carried.
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

    def preview
      return head(:conflict) if @plan&.locked?

      load_split
      @split = split_with(@split, submitted_assignments)
      render turbo_stream: turbo_stream.replace("planned_bar", partial: "households/splits/planned_bar",
                                                locals: { split: @split, viewer: current_participant, waivable: true })
    end

    def reset_gap
      SplitGap.reset!(@household, by: current_user)
      redirect_to household_split_path(@household), notice: t("split.gap.flash.reset")
    rescue SplitGap::NotACarrier
      redirect_to household_split_path(@household), alert: t("split.gap.flash.not_carrier")
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

      waive_gap_if_asked
      @household.complete_setup_step!("split")
      redirect_to dashboard_path, notice: validation_notice, alert: zone_warning
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

    # The split as the form stands: the submitted assignees over the household's.
    def split_with(split, assignments)
      keys = split.participant_keys
      items = split.items.map do |item|
        assignments.key?(item.chore_id) ? item.with(assignees: assignments[item.chore_id] & keys) : item
      end
      PlannedSplit.new(items: items, participants: split.participants, week: split.week)
    end

    # carry_gap=0 from the member above the zone (the one carrying the
    # surplus, decision 2026-11-08 and D4): the week's gap is not carried.
    def waive_gap_if_asked
      return unless params[:carry_gap] == "0" && @plan
      return unless @plan.split.above_zone.any? { |participant| participant.user_id == current_user.id }

      @plan.update!(carry_gap: false, gap_waived_by: current_user)
    end

    # Saved, with a warning, when a bar is out of the zone.
    def zone_warning
      return unless @plan

      outside = @plan.split.outside_zone
      return if outside.empty?

      zone = HouseholdRules.zone(@plan.participant_list.size)
      shares = outside.map { |p| "#{p.first_name} #{helpers.share_percent(@plan.split.share_of(p.key).average)}" }
      key = @plan.gap_carried? ? "split.zone.saved_outside" : "split.zone.saved_outside_waived"
      t(key, min: zone.min, max: zone.max, shares: shares.to_sentence)
    end

    def load_split
      @gap_balances = SplitGap.balances(@household)
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
