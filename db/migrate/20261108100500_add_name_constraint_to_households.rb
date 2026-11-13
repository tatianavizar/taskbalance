class AddNameConstraintToHouseholds < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE households SET name = 'Mon foyer' WHERE name IS NULL OR btrim(name) = ''"
    execute "UPDATE households SET name = left(name, 60) WHERE char_length(name) > 60"
    change_column_null :households, :name, false
  end

  def down
    change_column_null :households, :name, true
  end
end
