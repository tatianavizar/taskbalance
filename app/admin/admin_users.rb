# Équipe : les comptes du back-office. Réservé aux superadmins
# (BackOffice::Authorization). Créer un compte, changer son rôle, le désactiver,
# réinitialiser sa double authentification : BackOffice::Team, chaque écriture
# journalisée. Un compte n'est jamais supprimé (le journal pointe vers lui).
ActiveAdmin.register AdminUser do
  menu label: "Équipe", priority: 6
  actions :index, :show, :new, :create

  config.sort_order = "created_at_asc"
  config.comments = false
  config.filters = false

  controller do
    sortable_by :email, :role, :created_at

    # Not ActiveAdmin's create: BackOffice::Team checks the role, generates the
    # password and the enrolment link, and logs the action.
    def create
      result = BackOffice::Team.create(current_admin_user, email: params.dig(:admin_user, :email), role: params.dig(:admin_user, :role))
      return redirect_to(new_admin_admin_user_path, alert: result.message) unless result.ok?

      render_issued(result)
    end

    private

    # The password and the link are on this response only: never cached.
    def render_issued(result)
      response.headers["Cache-Control"] = "no-store"
      @issued = result
      @enrolment_url = back_office_two_factor_link_url(token: result.enrolment_token)
      @page_title = "À transmettre à #{result.admin.email}"
      render "admin/admin_users/issued"
    end
  end

  index title: "Équipe", download_links: false do
    column("Email", :email)
    column("Rôle", :role) { |admin| BackOffice::Labels.admin_role(admin.role) }
    column("Double authentification", sortable: false) { |admin| admin.two_factor_enrolled? ? "Activée" : "À activer" }
    column("Désactivé le", sortable: false) { |admin| admin.deactivated_at ? l(admin.deactivated_at, format: :long) : "—" }
    column("Créé le", :created_at)
    actions defaults: false do |admin|
      item "Voir", admin_admin_user_path(admin)
    end
  end

  show title: ->(admin) { admin.email } do
    attributes_table do
      row("Email") { |admin| admin.email }
      row("Rôle") { |admin| BackOffice::Labels.admin_role(admin.role) }
      row("Double authentification") { |admin| admin.two_factor_enrolled? ? "Activée" : "À activer" }
      row("Désactivé le") { |admin| admin.deactivated_at ? l(admin.deactivated_at, format: :long) : "—" }
      row("Créé le") { |admin| l(admin.created_at, format: :long) }
    end

    if resource != current_admin_user && !resource.deactivated?
      panel "Rôle" do
        render "back_office/admin_users/role_form", admin: resource
      end
    end
  end

  form title: "Nouveau compte" do |f|
    f.inputs "Nouveau compte de l'équipe" do
      f.input :email, label: "Email"
      f.input :role, label: "Rôle", as: :select, include_blank: false,
                     collection: AdminUser::ROLES.map { |role| [ BackOffice::Labels.admin_role(role), role ] }
    end
    para "Un mot de passe et un lien d'activation (30 minutes, usage unique) s'affichent une seule fois à l'étape suivante, à transmettre à la personne."
    f.actions do
      f.action :submit, label: "Créer le compte"
    end
  end

  action_item :reset_two_factor, only: :show, if: -> { resource != current_admin_user && !resource.deactivated? } do
    link_to "Réinitialiser la double authentification", reset_two_factor_admin_admin_user_path(resource), method: :post,
            data: { confirm: "Réinitialiser la double authentification de #{resource.email} ? Ses sessions sont fermées et un nouveau lien d'activation s'affiche." }
  end

  action_item :deactivate, only: :show, if: -> { resource != current_admin_user && !resource.deactivated? } do
    link_to "Désactiver le compte", deactivate_admin_admin_user_path(resource), method: :post,
            data: { confirm: "Désactiver le compte #{resource.email} ? Ses sessions sont fermées ; il ne pourra plus se connecter." }
  end

  member_action :reset_two_factor, method: :post do
    result = BackOffice::Team.reset_two_factor(current_admin_user, resource)
    result.ok? ? render_issued(result) : redirect_to(admin_admin_user_path(resource), alert: result.message)
  end

  member_action :deactivate, method: :post do
    result = BackOffice::Team.deactivate(current_admin_user, resource)
    redirect_to admin_admin_user_path(resource), (result.ok? ? { notice: result.message } : { alert: result.message })
  end

  member_action :change_role, method: :post do
    result = BackOffice::Team.change_role(current_admin_user, resource, role: params[:role].to_s)
    redirect_to admin_admin_user_path(resource), (result.ok? ? { notice: result.message } : { alert: result.message })
  end
end
