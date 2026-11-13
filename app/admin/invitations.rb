# Invitations : qui, à quelle adresse, dans quel état, combien d'envois. Jamais
# le jeton. Actions : renvoyer (mêmes limites que l'app : 3 envois en tout,
# 15 minutes d'écart) et annuler.
ActiveAdmin.register Invitation do
  menu label: "Invitations", priority: 4
  actions :index, :show

  config.sort_order = "created_at_desc"
  config.comments = false

  scope("Toutes", default: true) { |invitations| invitations }
  scope("En cours") { |invitations| invitations.live }

  filter :first_name, label: "Prénom"
  filter :email, label: "Email"
  filter :state, label: "État", as: :select, collection: -> { BackOffice::Labels.invitation_state_options }
  filter :created_at, label: "Envoyée le"

  controller do
    sortable_by :first_name, :email, :state, :created_at, :last_sent_at, :expires_at, :resend_count

    def scoped_collection
      super.includes(:household)
    end
  end

  index title: "Invitations", download_links: false do
    column("Prénom") { |invitation| invitation.display_name }
    column("Email", :email)
    column("État", :state) do |invitation|
      label, style = BackOffice::Labels.invitation_state(invitation.current_state)
      span label, class: "pill #{style}"
    end
    column("Foyer", sortable: false) { |invitation| link_to invitation.household.name, admin_household_path(invitation.household) }
    column("Envoyée le", :created_at)
    column("Dernier envoi", :last_sent_at)
    column("Expire le", :expires_at)
    column("Renvois", :resend_count)
    actions defaults: false do |invitation|
      item "Voir", admin_invitation_path(invitation)
    end
  end

  show title: ->(invitation) { invitation.display_name } do
    attributes_table do
      row("Prénom") { |invitation| invitation.first_name.presence || "—" }
      row("Email") { |invitation| invitation.email }
      row("État") do |invitation|
        label, style = BackOffice::Labels.invitation_state(invitation.current_state)
        span label, class: "pill #{style}"
      end
      row("Foyer") { |invitation| link_to invitation.household.name, admin_household_path(invitation.household) }
      row("Envoyée le") { |invitation| l(invitation.created_at, format: :long) }
      row("Dernier envoi") { |invitation| l(invitation.last_sent_at, format: :long) }
      row("Expire le") { |invitation| l(invitation.expires_at, format: :long) }
      row("Acceptée le") { |invitation| invitation.accepted_at ? l(invitation.accepted_at, format: :long) : "—" }
      row("Déclinée le") { |invitation| invitation.declined_at ? l(invitation.declined_at, format: :long) : "—" }
      row("Annulée le") { |invitation| invitation.cancelled_at ? l(invitation.cancelled_at, format: :long) : "—" }
      row("Renvois utilisés pour cette adresse") do |invitation|
        "#{invitation.resends_used} sur #{Invitation::MAX_RESENDS}"
      end
    end
  end

  action_item :resend, only: :show, if: -> { resource.usable? } do
    link_to "Renvoyer l'invitation", resend_admin_invitation_path(resource), method: :post,
            data: { confirm: "Renvoyer l'invitation à #{resource.email} ?" }
  end

  action_item :cancel, only: :show, if: -> { resource.usable? } do
    link_to "Annuler l'invitation", cancel_admin_invitation_path(resource), method: :post,
            data: { confirm: "Annuler l'invitation de #{resource.email} ?" }
  end

  member_action :resend, method: :post do
    result = BackOffice::Actions.resend_invitation(current_admin_user, resource)
    redirect_to admin_invitation_path(resource), (result.ok? ? { notice: result.message } : { alert: result.message })
  end

  member_action :cancel, method: :post do
    result = BackOffice::Actions.cancel_invitation(current_admin_user, resource)
    redirect_to admin_invitation_path(resource), (result.ok? ? { notice: result.message } : { alert: result.message })
  end
end
