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
      "user.email_confirmed" => "Email confirmé",
      "user.account_deleted" => "Compte supprimé"
    }.freeze

    ROLES = { "manager" => "Gestionnaire", "member" => "Membre" }.freeze

    module_function

    def household_state(state) = HOUSEHOLD_STATES.fetch(state.to_s, [ state.to_s, "pill-soft" ])
    def invitation_state(state) = INVITATION_STATES.fetch(state.to_s, [ state.to_s, "pill-soft" ])
    def action(name) = ACTIONS.fetch(name.to_s, name.to_s)
    def role(role) = ROLES.fetch(role.to_s, role.to_s)

    def household_state_options = HOUSEHOLD_STATES.map { |value, (label, _)| [ label, value ] }
    def invitation_state_options = INVITATION_STATES.map { |value, (label, _)| [ label, value ] }
    def action_options = ACTIONS.map { |value, label| [ label, value ] }
  end
end
