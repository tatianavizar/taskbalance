# Comptes de l'app, en lecture seule. On ne montre ni enregistrement, ni
# préférence, ni notification : ils appartiennent à leur auteur. Deux actions :
# confirmer l'email, supprimer le compte (BackOffice::Actions, journalisées).
ActiveAdmin.register User do
  menu label: "Comptes", priority: 2
  actions :index, :show

  config.sort_order = "created_at_desc"
  config.comments = false

  scope("Tous", default: true) { |users| users }
  scope("Email à confirmer") { |users| users.where(confirmed_at: nil, deleted_at: nil) }
  scope("Supprimés") { |users| users.where.not(deleted_at: nil) }

  filter :first_name, label: "Prénom"
  filter :email, label: "Email"
  filter :created_at, label: "Créé le"
  filter :deleted_at, label: "Supprimé le", as: :date_range

  controller do
    def scoped_collection
      super.includes(household_membership: :household)
    end
  end

  index title: "Comptes", download_links: false do
    column("Prénom", :first_name)
    column("Email", :email)
    column("Confirmé", sortable: :confirmed_at) { |user| span(user.confirmed_at ? "Oui" : "Non", class: "pill #{user.confirmed_at ? 'pill-soft' : 'pill-outline'}") }
    column("Créé le", :created_at)
    column("Foyer", sortable: false) { |user| user.household ? link_to(user.household.name, admin_household_path(user.household)) : "—" }
    column("Supprimé le", :deleted_at)
    actions defaults: false do |user|
      item "Voir", admin_user_path(user)
    end
  end

  show title: ->(user) { user.first_name } do
    attributes_table do
      row("Prénom") { |user| user.first_name }
      row("Email") { |user| user.email }
      row("Email en attente de confirmation") { |user| user.unconfirmed_email.presence || "—" }
      row("Confirmé") { |user| user.confirmed_at ? l(user.confirmed_at, format: :long) : "Non" }
      row("Créé le") { |user| l(user.created_at, format: :long) }
      row("Foyer") { |user| user.household ? link_to(user.household.name, admin_household_path(user.household)) : "—" }
      row("Supprimé le") { |user| user.deleted_at ? l(user.deleted_at, format: :long) : "—" }
    end

    unless resource.deleted?
      panel "Supprimer le compte" do
        render "back_office/users/delete_form", user: resource
      end
    end
  end

  action_item :confirm_email, only: :show, if: -> { !resource.deleted? && (resource.confirmed_at.nil? || resource.unconfirmed_email.present?) } do
    link_to "Confirmer l'email", confirm_email_admin_user_path(resource), method: :post,
            data: { confirm: "Confirmer l'email #{resource.email} sans que la personne clique sur le lien ?" }
  end

  member_action :confirm_email, method: :post do
    result = BackOffice::Actions.confirm_user_email(current_admin_user, resource)
    redirect_to admin_user_path(resource), (result.ok? ? { notice: result.message } : { alert: result.message })
  end

  member_action :delete_account, method: :post do
    result = BackOffice::Actions.delete_account(current_admin_user, resource, typed_email: params[:typed_email])
    redirect_to admin_user_path(resource), (result.ok? ? { notice: result.message } : { alert: result.message })
  end
end
