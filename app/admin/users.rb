# Comptes de l'app, en lecture seule. On ne montre ni enregistrement, ni
# préférence, ni notification : ils appartiennent à leur auteur. Actions :
# confirmer l'email, débloquer la connexion, supprimer le compte
# (BackOffice::Actions, journalisées).
ActiveAdmin.register User do
  menu label: "Comptes", priority: 2
  actions :index, :show

  config.sort_order = "created_at_desc"
  config.comments = false

  scope("Tous", default: true) { |users| users }
  scope("Email à confirmer") { |users| users.where(confirmed_at: nil, deleted_at: nil) }
  scope("Supprimés") { |users| users.where.not(deleted_at: nil) }
  scope("Connexion bloquée") { |users| users.where(deleted_at: nil).sign_in_locked }

  filter :first_name, label: "Prénom"
  filter :email, label: "Email"
  filter :created_at, label: "Créé le"
  filter :deleted_at, label: "Supprimé le", as: :date_range

  controller do
    sortable_by :first_name, :email, :confirmed_at, :created_at, :deleted_at

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
      row("Connexion") { |user| BackOffice::Labels.sign_in_lock(user) }
    end

    unless resource.deleted?
      panel "Supprimer le compte" do
        render "back_office/users/delete_form", user: resource
      end
    end
  end

  # Two separate actions: the address people sign in with, and the address
  # they asked to change to. Each dialog names the address it acts on, and the
  # action refuses when that address is no longer the one on file.
  action_item :confirm_current_email, only: :show, if: -> { !resource.deleted? && resource.confirmed_at.nil? } do
    link_to "Confirmer l'adresse actuelle", confirm_current_email_admin_user_path(resource, email: resource.email), method: :post,
            data: { confirm: "Confirmer l'adresse actuelle #{resource.email} ?" }
  end

  action_item :confirm_pending_email, only: :show, if: -> { !resource.deleted? && resource.unconfirmed_email.present? } do
    link_to "Confirmer le changement vers #{resource.unconfirmed_email}", confirm_pending_email_admin_user_path(resource, email: resource.unconfirmed_email), method: :post,
            data: { confirm: "Remplacer l'adresse de connexion #{resource.email} par #{resource.unconfirmed_email} ? La personne se connectera avec la nouvelle." }
  end

  action_item :unlock_account, only: :show, if: -> { !resource.deleted? && resource.sign_in_locked? } do
    link_to "Débloquer le compte", unlock_account_admin_user_path(resource), method: :post,
            data: { confirm: "Débloquer la connexion au compte #{resource.email} ? Les compteurs d'essais repartent de zéro." }
  end

  member_action :unlock_account, method: :post do
    result = BackOffice::Actions.unlock_account(current_admin_user, resource)
    redirect_to admin_user_path(resource), (result.ok? ? { notice: result.message } : { alert: result.message })
  end

  member_action :confirm_current_email, method: :post do
    result = BackOffice::Actions.confirm_current_email(current_admin_user, resource, expected: params[:email])
    redirect_to admin_user_path(resource), (result.ok? ? { notice: result.message } : { alert: result.message })
  end

  member_action :confirm_pending_email, method: :post do
    result = BackOffice::Actions.confirm_pending_email(current_admin_user, resource, expected: params[:email])
    redirect_to admin_user_path(resource), (result.ok? ? { notice: result.message } : { alert: result.message })
  end

  member_action :delete_account, method: :post do
    result = BackOffice::Actions.delete_account(current_admin_user, resource, typed_email: params[:typed_email])
    redirect_to admin_user_path(resource), (result.ok? ? { notice: result.message } : { alert: result.message })
  end
end
