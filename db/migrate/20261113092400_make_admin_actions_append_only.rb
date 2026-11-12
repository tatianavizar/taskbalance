# The audit log is append-only in the database itself, not only in the model:
# a trigger refuses UPDATE, DELETE and TRUNCATE, and the foreign key to
# admin_users no longer nullifies (that was an UPDATE through the back door):
# an admin with rows is deactivated, not destroyed.
#
# Triggers are not part of db/schema.rb, so the app dumps its schema as SQL
# (config.active_record.schema_format = :sql, db/structure.sql).
class MakeAdminActionsAppendOnly < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :admin_actions, :admin_users
    add_foreign_key :admin_actions, :admin_users, on_delete: :restrict

    execute <<~SQL
      CREATE FUNCTION admin_actions_append_only() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'admin_actions is append-only (% refused)', TG_OP;
      END;
      $$ LANGUAGE plpgsql;
    SQL
    execute <<~SQL
      CREATE TRIGGER admin_actions_no_update_delete
        BEFORE UPDATE OR DELETE ON admin_actions
        FOR EACH ROW EXECUTE FUNCTION admin_actions_append_only();
    SQL
    execute <<~SQL
      CREATE TRIGGER admin_actions_no_truncate
        BEFORE TRUNCATE ON admin_actions
        FOR EACH STATEMENT EXECUTE FUNCTION admin_actions_append_only();
    SQL
  end

  def down
    execute "DROP TRIGGER admin_actions_no_truncate ON admin_actions"
    execute "DROP TRIGGER admin_actions_no_update_delete ON admin_actions"
    execute "DROP FUNCTION admin_actions_append_only()"
    remove_foreign_key :admin_actions, :admin_users
    add_foreign_key :admin_actions, :admin_users, on_delete: :nullify
  end
end
