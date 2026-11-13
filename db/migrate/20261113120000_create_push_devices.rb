# Lot 8b: the phones that can receive push notifications (D9: push first,
# email as the fallback). One row per FCM registration token. The token is
# encrypted (Active Record encryption); its SHA-256 digest is what rows are
# looked up and kept unique by.
class CreatePushDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :push_devices do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :platform, null: false
      t.text :token, null: false
      t.string :token_digest, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end
    add_index :push_devices, :token_digest, unique: true
    add_check_constraint :push_devices, "platform IN ('ios', 'android')", name: "push_devices_platform"
  end
end
