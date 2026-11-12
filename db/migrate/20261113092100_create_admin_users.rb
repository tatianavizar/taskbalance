# Back office accounts: separate from the app's users (docs/decisions.md,
# 2026-11-13). Sign-in needs a password and a TOTP code (devise-two-factor);
# the secret is encrypted with Active Record encryption.
class CreateAdminUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_users do |t|
      t.string :email, null: false
      t.string :encrypted_password, null: false

      # devise-two-factor
      t.text :otp_secret
      t.integer :consumed_timestep
      t.boolean :otp_required_for_login, null: false, default: false

      # Devise lockable (time strategy)
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :locked_at

      t.timestamps
    end
    add_index :admin_users, :email, unique: true
  end
end
