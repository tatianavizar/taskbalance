module Households
  # One-off reassignment (TaskHandover).
  #
  #   new / create   D15: offer one of my tasks of this week to another member
  #   show           D16: the offer, with « Accepter » / « Refuser » for the
  #                  person offered it, « Annuler » for the one who offered
  #   accept, refuse, cancel
  #
  # Members of the household only; this week only. The validated split never
  # changes (D16), and the task is « prévue », not counted (D2).
  class HandoversController < ApplicationController
    before_action :authenticate_user!
    before_action :set_household
    before_action :set_handover, only: [ :show, :accept, :refuse, :cancel ]

    def new
      @chores = TaskHandover.offerable_chores(@household, current_user)
      @members = @household.users.where.not(id: current_user.id).order(:first_name)
    end

    def create
      chore = @household.chores.find(params.require(:handover)[:chore_id])
      to = @household.users.find_by(id: params[:handover][:to_user_id])
      handover = TaskHandover.offer!(chore: chore, from: current_user, to: to)
      redirect_to household_handover_path(@household, handover), notice: t("handovers.flash.offered", name: to.first_name)
    rescue TaskHandover::Refused => e
      redirect_to new_household_handover_path(@household), alert: t("handovers.refused.#{e.reason}")
    end

    def show; end

    def accept = answer(:accept!)
    def refuse = answer(:refuse!)
    def cancel = answer(:cancel!)

    private

    def set_household
      @household = current_user.household
      raise ActiveRecord::RecordNotFound unless @household && @household.id == params[:household_id].to_i
    end

    def set_handover
      @handover = @household.task_handovers.find(params[:id])
      raise ActiveRecord::RecordNotFound unless [ @handover.from_user_id, @handover.to_user_id ].include?(current_user.id)
    end

    def answer(action)
      @handover.public_send(action, by: current_user)
      redirect_to household_split_path(@household), notice: t("handovers.flash.#{@handover.status}")
    rescue TaskHandover::Refused => e
      redirect_to household_handover_path(@household, @handover), alert: t("handovers.refused.#{e.reason}")
    end
  end
end
