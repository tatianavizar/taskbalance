module BackOffice
  # What a superadmin does to back-office accounts from /admin/admin_users
  # (decision of 2026-11-13). Each write is checked here (superadmin only,
  # never on oneself, never leaving the team without an active superadmin),
  # done in a transaction with its AdminAction row, and returns a Result.
  #
  # Creating an account and resetting its second factor hand back, once, what
  # the new person needs: the one-time enrolment link (30 min) and, for a new
  # account, a generated password. They are shown on the response page only,
  # never stored in clear nor logged; the superadmin passes them on out of band.
  class Team
    Result = Data.define(:ok, :message, :admin, :password, :enrolment_token) do
      def ok? = ok
    end

    class << self
      def create(actor, email:, role:)
        return refused unless actor.superadmin?
        return failure("Rôle inconnu.") unless AdminUser::ROLES.include?(role.to_s)

        password = AdminUser.generate_password
        admin = AdminUser.new(email: email.to_s.strip.downcase, role: role, password: password, password_confirmation: password)
        AdminUser.transaction do
          return failure("Compte non créé : #{admin.errors.full_messages.to_sentence}") unless admin.save

          token = admin.issue_enrolment!
          AdminAction.record!(admin: actor, action: "admin.created", record: admin, role: admin.role)
          Result.new(ok: true, message: "Compte créé.", admin: admin, password: password, enrolment_token: token)
        end
      end

      def change_role(actor, admin, role:)
        return refused unless actor.superadmin?
        return failure("Rôle inconnu.") unless AdminUser::ROLES.include?(role.to_s)
        return failure("Votre propre rôle ne se change pas ici.") if admin == actor
        return failure("Ce compte a déjà ce rôle.") if admin.role == role.to_s

        AdminUser.transaction do
          admin.lock!
          before = admin.role
          admin.update!(role: role)
          AdminAction.record!(admin: actor, action: "admin.role_changed", record: admin, from: before, to: admin.role)
          success("Rôle changé.", admin)
        end
      end

      def deactivate(actor, admin)
        return refused unless actor.superadmin?
        return failure("Votre propre compte ne se désactive pas ici.") if admin == actor
        return failure("Ce compte est déjà désactivé.") if admin.deactivated?

        AdminUser.transaction do
          admin.lock!
          admin.deactivate!
          AdminAction.record!(admin: actor, action: "admin.deactivated", record: admin)
          success("Compte désactivé : ses sessions sont fermées.", admin)
        end
      end

      # Lost phone: a new secret and a new link; every session of the account ends.
      def reset_two_factor(actor, admin)
        return refused unless actor.superadmin?
        return failure("Pour votre propre compte : bin/rails admin:reset_two_factor.") if admin == actor
        return failure("Ce compte est désactivé.") if admin.deactivated?

        AdminUser.transaction do
          token = admin.reset_two_factor!
          AdminAction.record!(admin: actor, action: "admin.two_factor_reset", record: admin)
          Result.new(ok: true, message: "Double authentification réinitialisée.", admin: admin, password: nil, enrolment_token: token)
        end
      end

      private

      def refused = failure("Action réservée aux superadmins.")
      def success(message, admin) = Result.new(ok: true, message: message, admin: admin, password: nil, enrolment_token: nil)
      def failure(message) = Result.new(ok: false, message: message, admin: nil, password: nil, enrolment_token: nil)
    end
  end
end
