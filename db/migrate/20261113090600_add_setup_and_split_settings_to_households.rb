# setup_step: where the set-up checklist resumes (« Mise en place 2 sur 4 »).
# Existing households are already set up.
#
# The split settings of C16. They change only once every member validated the
# change (split_setting_changes); auto_validate_splits is off by default.
class AddSetupAndSplitSettingsToHouseholds < ActiveRecord::Migration[8.0]
  def change
    add_column :households, :setup_step, :string, null: false, default: "done"
    add_column :households, :weekly_proposal_enabled, :boolean, null: false, default: true
    add_column :households, :gap_carry_over_enabled, :boolean, null: false, default: true
    add_column :households, :auto_validate_splits, :boolean, null: false, default: false
  end
end
