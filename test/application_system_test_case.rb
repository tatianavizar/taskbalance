require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Le gestionnaire de mots de passe de Chrome peut intercepter la saisie des
  # champs `current-password` : on le coupe pour les tests.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
  end
end
