# Invitation links: only a keyed digest of the token is stored (decision of
# 2026-11-13). HMAC-SHA256 with a key derived from secret_key_base, the same
# as Invitation.digest_token. Existing rows get the digest of their current
# token, so links already sent keep working; then the plaintext column goes.
#
# Not reversible: the plaintext cannot be recovered from the digest.
class DigestInvitationTokens < ActiveRecord::Migration[8.0]
  KEY_SALT = "invitation-token-digest".freeze

  class MigrationInvitation < ActiveRecord::Base
    self.table_name = "invitations"
  end

  def up
    add_column :invitations, :token_digest, :string

    key = Rails.application.key_generator.generate_key(KEY_SALT)
    MigrationInvitation.reset_column_information
    MigrationInvitation.where(token_digest: nil).find_each do |invitation|
      invitation.update_columns(token_digest: OpenSSL::HMAC.hexdigest("SHA256", key, invitation.token))
    end

    change_column_null :invitations, :token_digest, false
    add_index :invitations, :token_digest, unique: true
    remove_index :invitations, :token
    remove_column :invitations, :token
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "invitation tokens are only stored as digests"
  end
end
