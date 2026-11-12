ActiveAdmin.setup do |config|
  config.site_title = "50/50 · équipe"

  # AdminUser, not User: the app's accounts never reach /admin. The gate also
  # requires the second factor (app/controllers/concerns/back_office_gate.rb).
  config.authentication_method = :authenticate_admin_user_with_two_factor!
  config.current_user_method = :current_admin_user
  config.logout_link_path = :destroy_admin_user_session_path

  # No comments: nothing in the back office is written freely.
  config.comments = false

  # Nothing is edited or deleted in bulk.
  config.batch_actions = false

  config.filter_attributes = [ :encrypted_password, :password, :password_confirmation, :otp_secret ]
  config.localize_format = :long
  config.default_per_page = 30
  config.max_per_page = 100
end

# ActiveAdmin 4.0.0.beta23 registers its Comment resource in every namespace
# even with `config.comments = false` (it only hides the menu entry): that
# leaves /admin/comments (index, show, create, destroy) routed, on a table this
# app does not have. Nothing in the back office is commentable, so it goes.
# Registered after ActiveAdmin's own after_load, so it runs after it.
ActiveAdmin.after_load do |app|
  app.namespaces.each do |namespace|
    collection = namespace.resources.instance_variable_get(:@collection)
    collection.delete_if { |name, _| name.to_s == namespace.comments_registration_name.to_s }
  end
end
