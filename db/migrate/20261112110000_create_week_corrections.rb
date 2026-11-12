# D3 (decision 2026-11-12): a pause declared after the fact over a final week
# never rewrites the stored report. A correction is recorded over it instead,
# and screens show the week as « Neutre · pause déclarée le … ». The first
# name and the declaration time are copied so the correction stays readable
# after the pause or the member is gone.
class CreateWeekCorrections < ActiveRecord::Migration[8.0]
  def change
    create_table :week_corrections do |t|
      t.references :household, null: false, foreign_key: { on_delete: :cascade }
      t.references :household_week, null: false, foreign_key: { on_delete: :cascade }
      t.references :member_pause, foreign_key: { on_delete: :nullify }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.references :declared_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :first_name, null: false
      t.datetime :declared_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :week_corrections, [ :household_week_id, :user_id ], unique: true

    # A regression_cancelled level change points at the regression it undoes.
    add_reference :level_changes, :cancelled_level_change, foreign_key: { to_table: :level_changes, on_delete: :nullify }
  end
end
