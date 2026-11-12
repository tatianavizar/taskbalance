# Audit log of what the 50/50 team did from the back office: one row per
# write, never edited (AdminAction is read-only once saved). It keeps the
# admin's email too, so the row still says who did it after the account is gone.
class CreateAdminActions < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_actions do |t|
      t.references :admin_user, foreign_key: { on_delete: :nullify }
      t.string :admin_email, null: false
      t.string :action, null: false
      t.string :record_type
      t.bigint :record_id
      t.jsonb :detail, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :admin_actions, :created_at
    add_index :admin_actions, [ :record_type, :record_id ]
  end
end
