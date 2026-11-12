module BackOffice
  # French names and pill styles for what the back office lists. The states
  # are the models' own (Household.states, Invitation.states); the labels
  # are the team's, not the app's wording.
  module Labels
    HOUSEHOLD_STATES = {
      "setting_up" => [ "Mise en place", "pill-outline" ],
      "solo" => [ "Une personne", "pill-soft" ],
      "active" => [ "Actif", "pill-mint" ],
      "warned" => [ "Alerte", "pill-soft" ],
      "blocked" => [ "Bloqué", "pill-ink" ],
      "dormant" => [ "En veille", "pill-outline" ]
    }.freeze

    INVITATION_STATES = {
      "pending" => [ "En cours", "pill-mint" ],
      "accepted" => [ "Acceptée", "pill-soft" ],
      "declined" => [ "Déclinée", "pill-soft" ],
      "cancelled" => [ "Annulée", "pill-outline" ],
      "expired" => [ "Expirée", "pill-outline" ]
    }.freeze

    ACTIONS = {
      "two_factor.enrolled" => "Double authentification activée",
      "invitation.resent" => "Invitation renvoyée",
      "invitation.cancelled" => "Invitation annulée",
      "household.unblocked" => "Foyer débloqué",
      "user.email_confirmed" => "Email actuel confirmé",
      "user.email_change_confirmed" => "Changement d'email confirmé",
      "admin.signed_in" => "Connexion",
      "admin.sign_in_failed" => "Connexion refusée",
      "admin.locked" => "Compte bloqué après trop d'essais",
      "admin.bootstrapped" => "Compte créé (console)",
      "admin.password_reset" => "Mot de passe réinitialisé (console)",
      "admin.two_factor_reset" => "Double authentification réinitialisée (console)",
      "two_factor.enrolment_failed" => "Code d'enrôlement refusé",
      "user.account_deleted" => "Compte supprimé",
      "user.sign_in_unlocked" => "Compte débloqué"
    }.freeze

    ROLES = { "manager" => "Gestionnaire", "member" => "Membre" }.freeze

    module_function

    # « semaine 45 »: the ISO week of the household's last log, in its own
    # zone, for a household of two or more (the query leaves it nil below).
    # Never the day: nothing a single person did on a given date.
    def activity_week(household)
      at = household[:last_activity_at]
      at ? Week.containing(at, household.time_zone).label.downcase : "—"
    end

    # The sign-in lockout of an account (SignInLockout), for the team only.
    def sign_in_lock(user)
      if user.sign_in_hard_locked?
        "Bloquée depuis le #{I18n.l(user.sign_in_hard_locked_at, format: :long)} (3e blocage : à débloquer ici)"
      elsif user.sign_in_temporarily_locked?
        "Bloquée jusqu'au #{I18n.l(user.sign_in_unlocks_at, format: :long)}"
      else
        "Ouverte"
      end
    end

    def household_state(state) = HOUSEHOLD_STATES.fetch(state.to_s, [ state.to_s, "pill-soft" ])
    def invitation_state(state) = INVITATION_STATES.fetch(state.to_s, [ state.to_s, "pill-soft" ])
    def action(name) = ACTIONS.fetch(name.to_s, name.to_s)
    def role(role) = ROLES.fetch(role.to_s, role.to_s)

    def household_state_options = HOUSEHOLD_STATES.map { |value, (label, _)| [ label, value ] }
    def invitation_state_options = INVITATION_STATES.map { |value, (label, _)| [ label, value ] }
    def action_options = ACTIONS.map { |value, label| [ label, value ] }
  end
end
