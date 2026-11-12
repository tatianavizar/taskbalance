# Lot 7, F3: a notification belongs to its recipient. When a household is
# deleted, its members keep the message that says so (and the email job still
# finds its row): the household reference is nullified instead of cascading.
class NullifyNotificationsOnHouseholdDelete < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :notifications, :households
    add_foreign_key :notifications, :households, on_delete: :nullify
  end

  def down
    remove_foreign_key :notifications, :households
    add_foreign_key :notifications, :households, on_delete: :cascade
  end
end
