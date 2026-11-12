# Configuration des chemins (path configuration) lue par les coquilles
# Hotwire Native : /configurations/ios_v1.json et /configurations/android_v1.json.
#
# Règles, la dernière qui correspond l'emporte pour chaque propriété :
#   - tout écran : pile de l'onglet, tirer pour rafraîchir ;
#   - formulaires (D6, D10, E12, D15...) et écrans de confirmation (E16, B15,
#     C2, C7, F3 : `/delete`, `/cancel`) : feuille modale native ;
#   - routes « historical location » de turbo-rails : rien à afficher.
# `settings.tabs` documente les onglets ; les coquilles les ont en dur
# (native/), pour les afficher avant d'avoir lu ce fichier.
class ConfigurationsController < ApplicationController
  TABS = [
    { "title" => "Accueil", "path" => "/dashboard" },
    { "title" => "Tâches", "path" => "/chores" },
    { "title" => "Bilan", "path" => "/bilan" },
    { "title" => "Foyer", "path" => "/foyer" }
  ].freeze

  def show
    render json: self.class.path_configuration
  end

  def self.path_configuration
    {
      settings: { tabs: TABS },
      rules: [
        {
          patterns: [ ".*" ],
          properties: { context: "default", pull_to_refresh_enabled: true }
        },
        {
          patterns: [ "/new$", "/edit$", "/completion/new$", "/delete$", "/cancel$" ],
          properties: { context: "modal", pull_to_refresh_enabled: false }
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
