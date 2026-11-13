# Back-office roles (decision of 2026-11-13): `admin` sees aggregates only (the
# behaviour so far); `superadmin` has every right, manages the admins and may
# read a person's individual data, each reading logged in admin_actions.
# Existing accounts stay `admin`: a superadmin is made with
# `bin/rails admin:bootstrap ROLE=superadmin`.
class AddRoleToAdminUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :admin_users, :role, :string, null: false, default: "admin"
    add_check_constraint :admin_users, "role IN ('admin', 'superadmin')", name: "admin_users_role_values"
  end
end
