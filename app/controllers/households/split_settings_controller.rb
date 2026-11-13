module Households
  # Réglages de la répartition (C16). Any member can change them; a change
  # applies once every member validated it (decision 2026-11-08).
  class SplitSettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_household

    def show
      @pending_change = @household.split_setting_changes.pending.first
    end

    def update
      submitted = params.fetch(:household, {}).permit(*SplitSettingChange::SETTINGS)
      change = SplitSettingChange.request!(household: @household, by: current_user, changes: submitted.to_h)
      notice =
        if change.nil? then t("split_settings.flash.unchanged")
        elsif change.applied? then t("split_settings.flash.applied")
        else t("split_settings.flash.pending", names: change.pending_members.map { |m| m.user.first_name }.to_sentence)
        end
      redirect_to household_split_settings_path(@household), notice: notice
    end

    def approve
      change = @household.split_setting_changes.pending.find(params[:change_id])
      applied = change.approve!(by: current_user)
      redirect_to household_split_settings_path(@household),
                  notice: applied ? t("split_settings.flash.applied") : t("split_settings.flash.approved")
    end

    private

    def set_household
      @household = find_own_household!(params[:household_id])
    end
  end
end
