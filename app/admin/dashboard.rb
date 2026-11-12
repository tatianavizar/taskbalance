# Tableau de bord : des comptes et des états, jamais un enregistrement.
ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: "Tableau de bord"

  content title: "Tableau de bord" do
    pending_invitations = Invitation.live.count
    households_by_state = Household.group(:state).count

    div class: "grid grid-cols-1 gap-4 sm:grid-cols-3" do
      [
        [ "Comptes", User.where(deleted_at: nil).count ],
        [ "Foyers", Household.count ],
        [ "Invitations en cours", pending_invitations ]
      ].each do |label, figure|
        div class: "stat-card" do
          div figure, class: "stat-figure", "data-test-figure": label
          div label, class: "stat-label"
        end
      end
    end

    panel "Foyers par état" do
      table_for BackOffice::Labels::HOUSEHOLD_STATES.keys, class: "index_table" do
        column("État") { |state| span BackOffice::Labels.household_state(state).first, class: "pill #{BackOffice::Labels.household_state(state).last}" }
        column("Foyers") { |state| households_by_state.fetch(state, 0) }
      end
    end
  end
end
