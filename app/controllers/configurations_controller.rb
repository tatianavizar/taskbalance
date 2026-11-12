# Configuration des chemins (path configuration) lue par les coquilles
# Hotwire Native : /configurations/ios_v1.json et /configurations/android_v1.json.
#
# Règles, la dernière qui correspond l'emporte pour chaque propriété :
#   - tout écran : pile de l'onglet, tirer pour rafraîchir ;
#   - formulaires (D6, D10, E12, D15...) et écrans de confirmation (E16, B15,
#     C2, C7, F3 : `/delete`, `/cancel`) : feuille modale native ;
#   - routes « historical location » de turbo-rails : rien à afficher.
# `settings.tabs` documente les onglets ; les coquilles les ont en dur
# (native/), pour les afficher avant d'avoir lu ce fichier. Android nomme en
# plus le fragment à ouvrir (`uri`) : page web, ou feuille du bas pour les
# modales. Les copies embarquées dans les apps (native/ios/.../path-configuration.json,
# native/android/.../json/configuration.json) suivent ces règles.
class ConfigurationsController < ApplicationController
  TABS = [
    { "title" => "Accueil", "path" => "/dashboard" },
    { "title" => "Tâches", "path" => "/chores" },
    { "title" => "Bilan", "path" => "/bilan" },
    { "title" => "Foyer", "path" => "/foyer" }
  ].freeze

  def show
    render json: self.class.path_configuration(params[:platform])
  end

  ANDROID_URIS = { default: "hotwire://fragment/web", modal: "hotwire://fragment/web/modal/sheet" }.freeze

  def self.path_configuration(platform = "ios")
    android = platform.to_s == "android"
    {
      settings: { tabs: TABS },
      rules: [
        {
          patterns: [ ".*" ],
          properties: { context: "default", pull_to_refresh_enabled: true, uri: (ANDROID_URIS[:default] if android) }.compact
        },
        {
          patterns: [ "/new$", "/edit$", "/completion/new$", "/delete$", "/cancel$" ],
          properties: { context: "modal", pull_to_refresh_enabled: false, uri: (ANDROID_URIS[:modal] if android) }.compact
        },
        {
          patterns: [
            "/recede_historical_location$",
            "/resume_historical_location$",
            "/refresh_historical_location$"
          ],
          properties: { presentation: "none" }
        }
      ]
    }
  end
end
