module ApplicationHelper
  # Point d'entrée unique pour « le foyer de la personne connectée »
  # (un seul foyer par compte, décision du 2026-11-08).
  def current_household
    return unless user_signed_in?

    @current_household ||= current_user.household
  end

  # Titre de la page : `provide :title, "…"` dans la vue. Le natif l'affiche
  # dans sa barre de navigation.
  def page_title
    [ content_for(:title).presence, t("app.name") ].compact.join(" · ")
  end

  # Une vue peut demander l'écran nu (sans en-tête ni barre d'onglets) avec
  # `provide :chrome, "none"`. Les coquilles natives masquent toujours les deux.
  def chrome?
    !hotwire_native_app? && content_for(:chrome) != "none" && user_signed_in?
  end

  # Le bandeau cookies s'affiche tant qu'on n'a pas cliqué « OK ». Jamais dans
  # les coquilles natives : elles n'ont ni navigateur ni bandeau à montrer.
  def cookie_banner?
    !hotwire_native_app? && cookies[:cookie_notice_seen].blank?
  end

  # Lot 8b : dans les coquilles natives, une personne connectée envoie le jeton
  # du téléphone au serveur (composant bridge « push-notifications », mode
  # "sync"). L'empreinte du jeton déjà enregistré par cette session évite de le
  # renvoyer à chaque page.
  def native_push_sync
    return unless hotwire_native_app? && user_signed_in?

    digest = PushDevice.where(id: session[:push_device_id], user_id: current_user.id).pick(:token_digest) if session[:push_device_id]
    tag.div(hidden: true, data: {
      controller: "bridge--push-notifications",
      "bridge--push-notifications-mode-value": "sync",
      "bridge--push-notifications-url-value": push_device_path,
      "bridge--push-notifications-signed-in-value": true,
      "bridge--push-notifications-device-digest-value": digest.to_s
    })
  end

  # Onglet actif selon le contrôleur courant.
  def active_tab
    case controller_path
    when "pages" then action_name == "dashboard" ? :home : nil
    when "chores", "chores/completions", "tasks" then :tasks
    when "reports", "levels" then :report
    when "absence_inquiries" then :home
    when "households", "households/invitations", "households/chores_setup", "households/preferences",
         "households/setups", "households/splits", "households/split_settings", "households/departures",
         "member_pauses" then :household
    end
  end

  def household_tab_path
    current_household ? household_path(current_household) : new_household_path
  end

  # Monogramme d'un membre. Un seul point de bascule quand le prénom existera.
  def member_initials(user)
    membership = user.try(:household_membership)
    return membership.monogram if membership&.monogram.present?

    (user.try(:first_name).presence || user.email).to_s.first.to_s.upcase
  end

  # Couleur de membre attribuée dans l'ordre d'arrivée, en attendant le choix
  # enregistré côté modèle.
  def member_color(index)
    ComponentsHelper::MEMBER_COLORS[index % ComponentsHelper::MEMBER_COLORS.size]
  end
end
