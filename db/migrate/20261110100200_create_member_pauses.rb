# A member's declared absence. Any member can declare one, for themselves or
# for an absent member (declared_by). Paused weeks don't count. `reason` is
# private to the member concerned.
class CreateMemberPauses < ActiveRecord::Migration[8.0]
  def change
    create_table :member_pauses do |t|
      t.references :household_member, null: false, foreign_key: { on_delete: :cascade }
      t.references :declared_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.date :starts_on, null: false
      t.date :ends_on
      t.string :reason
      t.timestamps
    end
    add_index :member_pauses, [ :household_member_id, :starts_on ]
    add_check_constraint :member_pauses, "ends_on IS NULL OR ends_on >= starts_on", name: "member_pauses_dates_ordered"
  end
end
