# frozen_string_literal: true

# From `bin/rails generate solid_cable:update` (solid_cable 4.1): messages are
# looked up by channel_hash only, so the index on the binary channel column is
# dead weight on every broadcast.
class RemoveChannelIndex < ActiveRecord::Migration[8.1]
  def up
    remove_index :solid_cable_messages, :channel, if_exists: true
  end

  def down
    add_index :solid_cable_messages, :channel, if_not_exists: true
  end
end
