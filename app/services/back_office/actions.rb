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

      # The address the person signs in with, still unconfirmed. Never touches a
      # pending change of address (`confirm` would swap it in). `expected` is the
      # address the dialog showed: refused when it is no longer the one on file.
      def confirm_current_email(admin, user, expected:)
        return failure("Ce compte est supprimé.") if user.deleted?
        return failure("L'adresse a changé depuis l'affichage de la page : rechargez.") unless same_email?(user.email, expected)
        return failure("L'adresse actuelle est déjà confirmée.") if user.confirmed_at

        AdminAction.transaction do
          user.update_columns(confirmed_at: Time.current, confirmation_token: nil)
          AdminAction.record!(admin: admin, action: "user.email_confirmed", record: user,
                              email_digest: AdminAction.digest(user.email))
          success("Adresse actuelle confirmée.")
        end
      end

      # The change of address the person asked for: it replaces the sign-in
      # email. The audit row keeps keyed digests of the old and the new address.
      def confirm_pending_email(admin, user, expected:)
        return failure("Ce compte est supprimé.") if user.deleted?
        return failure("Aucun changement d'adresse en attente.") if user.unconfirmed_email.blank?
        return failure("Le changement en attente n'est plus celui affiché : rechargez.") unless same_email?(user.unconfirmed_email, expected)

        AdminAction.transaction do
          before = user.email
          pending = user.unconfirmed_email
          # Not Devise's `confirm`: it refuses a link older than 24 h, which is
          # beside the point when the team confirms by hand.
          user.skip_reconfirmation!
          unless user.update(email: pending, unconfirmed_email: nil, confirmed_at: Time.current, confirmation_token: nil)
            return failure("Ce changement n'a pas pu être confirmé : #{user.errors.full_messages.to_sentence}")
          end

          AdminAction.record!(admin: admin, action: "user.email_change_confirmed", record: user,
                              from_digest: AdminAction.digest(before), to_digest: AdminAction.digest(pending))
          success("Changement d'adresse confirmé : la personne se connecte désormais avec la nouvelle.")
        end
      end

      # Sign-in lockout (SignInLockout): lifts a temporary or a permanent lock
      # and resets both counters. The person is not told by the app; they can
      # sign in again.
      def unlock_account(admin, user)
        return failure("Ce compte est supprimé.") if user.deleted?

        AdminAction.transaction do
          user.lock!
          return failure("La connexion à ce compte n'est pas bloquée.") unless user.sign_in_locked?

          hard = user.sign_in_hard_locked?
          user.unlock_sign_in!
          AdminAction.record!(admin: admin, action: "user.sign_in_unlocked", record: user, hard_lock: hard)
          success("Compte débloqué : la personne peut se connecter de nouveau.")
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

      def same_email?(one, other)
        one.to_s.strip.casecmp?(other.to_s.strip)
      end

      def success(message) = Result.new(ok: true, message: message)
      def failure(message) = Result.new(ok: false, message: message)
    end
  end
end
