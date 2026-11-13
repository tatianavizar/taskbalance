class AddFirstNameToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :first_name, :string

    # Existing accounts have no first name: fall back to the local part of the
    # email, capitalised, so every screen still has something to address them by.
    execute <<~SQL.squish
      UPDATE users
      SET first_name = initcap(split_part(split_part(email, '@', 1), '+', 1))
      WHERE first_name IS NULL
    SQL
    execute "UPDATE users SET first_name = 'Membre' WHERE first_name = ''"

    change_column_null :users, :first_name, false
  end

  def down
    remove_column :users, :first_name
  end
end
