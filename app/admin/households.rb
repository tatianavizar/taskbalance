# Foyers, en lecture seule, avec des agrégats : jamais la part de chacun ni un
# enregistrement. Seule écriture : débloquer un foyer (Household#admin_unblock!).
ActiveAdmin.register Household do
  menu label: "Foyers", priority: 3
  actions :index, :show

  config.sort_order = "created_at_desc"
  config.comments = false

  scope("Tous", default: true) { |households| households }
  scope("Bloqués") { |households| households.blocked }

  filter :name, label: "Nom"
  filter :state, label: "État", as: :select, collection: -> { BackOffice::Labels.household_state_options }
  filter :level, label: "Niveau"
  filter :time_zone, label: "Fuseau horaire", as: :select, collection: -> { Household.distinct.order(:time_zone).pluck(:time_zone) }
  filter :blocked_at, label: "Bloqué depuis", as: :date_range

  controller do
    # Counts and one date per household, in the same query. The last activity
    # is the date of the household's latest log, nothing more of it.
    def scoped_collection
      super.select(
        "households.*",
        "(SELECT COUNT(*) FROM household_members WHERE household_members.household_id = households.id) AS member_count",
        "(SELECT COUNT(*) FROM household_weeks WHERE household_weeks.household_id = households.id AND household_weeks.status = 'final') AS final_weeks_count",
        "(SELECT MAX(chore_logs.completed_at) FROM chore_logs WHERE chore_logs.household_id = households.id) AS last_activity_at"
      )
    end
  end

  index title: "Foyers", download_links: false do
    column("Nom", :name)
    column("Fuseau horaire", :time_zone)
    column("Membres", sortable: false) { |household| household[:member_count] }
    column("Niveau", :level)
    column("État", :state) do |household|
      label, style = BackOffice::Labels.household_state(household.state)
      span label, class: "pill #{style}"
    end
    column("Bloqué depuis", :blocked_at)
    column("Semaines finales", sortable: false) { |household| household[:final_weeks_count] }
    column("Dernière activité", sortable: false) { |household| household[:last_activity_at] ? l(household[:last_activity_at].to_date, format: :long) : "—" }
    actions defaults: false do |household|
      item "Voir", admin_household_path(household)
    end
  end

  show title: ->(household) { household.name } do
    attributes_table do
      row("Nom") { |household| household.name }
      row("Fuseau horaire") { |household| household.time_zone }
      row("Membres") { |household| household[:member_count] }
      row("Niveau") { |household| household.level }
      row("Semaines équilibrées") { |household| household.balanced_weeks_count }
      row("État") do |household|
        label, style = BackOffice::Labels.household_state(household.state)
        span label, class: "pill #{style}"
      end
      row("Bloqué depuis") { |household| household.blocked_at ? l(household.blocked_at, format: :long) : "—" }
      row("Semaines finales") { |household| household[:final_weeks_count] }
      row("Dernière activité") { |household| household[:last_activity_at] ? l(household[:last_activity_at].to_date, format: :long) : "—" }
      row("Créé le") { |household| l(household.created_at, format: :long) }
    end

    panel "Membres" do
      table_for resource.household_members.includes(:user).order(:created_at, :id), class: "index_table" do
        column("Prénom") { |member| link_to member.user.first_name, admin_user_path(member.user) }
        column("Rôle") { |member| BackOffice::Labels.role(member.role) }
        column("Arrivée") { |member| l(member.created_at, format: :long) }
      end
    end

    panel "Invitations" do
      table_for resource.invitations.order(id: :desc), class: "index_table" do
        column("Prénom") { |invitation| link_to invitation.display_name, admin_invitation_path(invitation) }
        column("État") do |invitation|
          label, style = BackOffice::Labels.invitation_state(invitation.current_state)
          span label, class: "pill #{style}"
        end
        column("Envoyée le") { |invitation| l(invitation.created_at, format: :long) }
      end
    end
  end

  action_item :unblock, only: :show, if: -> { resource.blocked? } do
    link_to "Débloquer le foyer", unblock_admin_household_path(resource), method: :post,
            data: { confirm: "Débloquer #{resource.name} ? Le niveau et le compteur de semaines équilibrées ne changent pas." }
  end

  member_action :unblock, method: :post do
    result = BackOffice::Actions.unblock_household(current_admin_user, resource)
    redirect_to admin_household_path(resource), (result.ok? ? { notice: result.message } : { alert: result.message })
  end
end
