# Lot 7, F5: an account deleted by its owner is anonymised, not removed (its
# id stays referenced by past reports). deleted_at marks it and closes sign-in.
class AddDeletedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :deleted_at, :datetime
  end
end
