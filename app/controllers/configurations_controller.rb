# Configuration des chemins (path configuration) lue par les coquilles
# Hotwire Native : /configurations/ios_v1.json et /configurations/android_v1.json.
class ConfigurationsController < ApplicationController
  def show
    render json: self.class.path_configuration
  end

  def self.path_configuration
    {
      settings: {},
      rules: [
        {
          patterns: [ ".*" ],
          properties: { context: "default", pull_to_refresh_enabled: true }
        },
        {
          patterns: [ "/new$", "/edit$", "/completion/new$" ],
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
