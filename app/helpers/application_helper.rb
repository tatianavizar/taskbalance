module ApplicationHelper
  # Point d'entrée unique pour « le foyer de la personne connectée ».
  # Aujourd'hui le premier foyer ; quand le compte n'aura qu'un foyer
  # (User has_one :household), seule cette méthode change.
  def current_household
    return unless user_signed_in?

    @current_household ||= current_user.households.first
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

  # Onglet actif selon le contrôleur courant.
  def active_tab
    case controller_path
    when "pages" then action_name == "dashboard" ? :home : nil
    when "chores", "chores/completions", "tasks" then :tasks
    when "reports" then :report
    when "households", "household_members", "households/chores_setup", "households/liking_sessions" then :household
    end
  end

  def household_tab_path
    current_household ? household_path(current_household) : new_household_path
  end

  # Monogramme d'un membre. Un seul point de bascule quand le prénom existera.
  def member_initials(user)
    user.email.to_s.first.to_s.upcase
  end

  # Couleur de membre attribuée dans l'ordre d'arrivée, en attendant le choix
  # enregistré côté modèle.
  def member_color(index)
    ComponentsHelper::MEMBER_COLORS[index % ComponentsHelper::MEMBER_COLORS.size]
  end
end
