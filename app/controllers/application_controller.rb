class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Les coquilles natives (User-Agent « Hotwire Native ») embarquent une WebView
  # dont la version n'est pas annoncée comme un navigateur : on ne les bloque pas.
  allow_browser versions: :modern, unless: -> { hotwire_native_app? }

  default_form_builder FiftyFormBuilder

  # Après connexion ou inscription, on arrive sur l'accueil de l'app.
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || dashboard_path
  end
end
