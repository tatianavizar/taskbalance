require "test_helper"

module Households
  class SplitSettingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @household = households(:smith_home)
      sign_in users(:alice)
    end

    def settings(**overrides)
      { weekly_proposal_enabled: "1", auto_validate_splits: "0", gap_carry_over_enabled: "1" }.merge(overrides)
    end

    test "C16 shows the three settings, auto-validation off" do
      get household_split_settings_path(@household)

      assert_response :success
      assert_select "input[role=switch][name=?][checked]", "household[weekly_proposal_enabled]"
      assert_select "input[role=switch][name=?]:not([checked])", "household[auto_validate_splits]"
      assert_text "Un changement s'applique une fois validé par tous les membres du foyer."
    end

    test "a change waits for the other member, who validates it" do
      patch household_split_settings_path(@household), params: { household: settings(auto_validate_splits: "1") }

      assert_equal "Changement proposé. En attente de Bob.", flash[:notice]
      assert_not @household.reload.auto_validate_splits?
      change = @household.split_setting_changes.pending.first

      sign_in users(:bob)
      get household_split_settings_path(@household)
      assert_text "En attente de Bob"
      post approve_household_split_settings_path(@household, change_id: change.id)

      assert_equal "Réglages appliqués.", flash[:notice]
      assert @household.reload.auto_validate_splits?
    end

    test "nothing changed, nothing to validate" do
      patch household_split_settings_path(@household), params: { household: settings }
      assert_equal "Aucun réglage n'a changé.", flash[:notice]
      assert_empty @household.split_setting_changes
    end

    test "another household's settings are not reachable" do
      patch household_split_settings_path(households(:jones_home)), params: { household: settings(auto_validate_splits: "1") }
      assert_response :not_found
    end
  end
end
