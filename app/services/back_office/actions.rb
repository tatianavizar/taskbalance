module BackOffice
  # The writes the 50/50 team can make from /admin (docs/decisions.md,
  # 2026-11-13). Each one checks its own limits, does the work in a transaction
  # with its AdminAction row, and returns a Result whose message is shown as is
  # (French, the back office's language). Nothing writes without being listed
  # here, and nothing here touches a log, a preference or a report.
  #
  #   BackOffice::Actions.resend_invitation(admin, invitation)
  class Actions
    Result = Data.define(:ok, :message) do
      def ok? = ok
    end

    class << self
      # Same limits and same email as the sender's own resend (Invitation#resend!):
      # 3 sends in all, 15 minutes apart.
      def resend_invitation(admin, invitation)
        return failure("Action non autorisée.") unless invitation.resendable_by?(admin)

        AdminAction.transaction do
          verdict, seconds = invitation.resend!
          case verdict
          when :ok
            AdminAction.record!(admin: admin, action: "invitation.resent", record: invitation,
                                household_id: invitation.household_id, resend_count: invitation.reload.resend_count)
            success("Invitation renvoyée.")
          when :wait then failure("Un envoi a eu lieu il y a moins de #{Invitation::MIN_RESEND_GAP.in_minutes.to_i} minutes. Réessayer dans #{(seconds / 60.0).ceil} min.")
          when :limit then failure("Cette adresse a déjà reçu les #{Invitation::MAX_RESENDS + 1} envois possibles pour ce foyer.")
          else failure("Seule une invitation en cours peut être renvoyée.")
          end
        end
      end

      def cancel_invitation(admin, invitation)
        AdminAction.transaction do
          return failure("Seule une invitation en cours peut être annulée.") unless invitation.cancel!

          AdminAction.record!(admin: admin, action: "invitation.cancelled", record: invitation, household_id: invitation.household_id)
          success("Invitation annulée.")
        end
      end

      def unblock_household(admin, household)
        AdminAction.transaction do
          return failure("Ce foyer n'est pas bloqué.") unless household.admin_unblock!(by: admin)

          AdminAction.record!(admin: admin, action: "household.unblocked", record: household,
                              level: household.level, balanced_weeks_count: household.balanced_weeks_count)
          success("Foyer débloqué. Le niveau et le compteur de semaines équilibrées n'ont pas changé.")
        end
      end

      def confirm_user_email(admin, user)
        return failure("Ce compte est supprimé.") if user.deleted?

        AdminAction.transaction do
          return failure("L'email est déjà confirmé.") unless user.confirm

          AdminAction.record!(admin: admin, action: "user.email_confirmed", record: user)
          success("Email confirmé.")
        end
      end

      # The admin types the account's email (AccountDeletion#save_as_admin).
      # Logs are deleted, as in the person's own deletion.
      def delete_account(admin, user, typed_email:)
        deletion = AccountDeletion.new(user)
        household_id = user.household&.id
        AdminAction.transaction do
          return failure(deletion.errors.full_messages.to_sentence.presence || "L'email saisi ne correspond pas.") unless deletion.save_as_admin(typed_email: typed_email)

          AdminAction.record!(admin: admin, action: "user.account_deleted", record: user,
                              household_id: household_id, logs_deleted: deletion.logs_deleted?)
          success("Compte supprimé. Ses enregistrements ont été supprimés.")
        end
      end

      private

      def success(message) = Result.new(ok: true, message: message)
      def failure(message) = Result.new(ok: false, message: message)
    end
  end
end
