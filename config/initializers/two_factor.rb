# Back office sign-in: remember in the session that the second factor was
# given. `after_authentication` fires only when a strategy signs someone in,
# and the two-factor strategy lets an enrolled admin through only with a valid
# TOTP code (devise-two-factor), so reaching this hook with an enrolled
# AdminUser means the code was checked. See BackOfficeGate.
#
# The flag lives in the Warden scope session: it goes away with the sign-out.
Warden::Manager.after_authentication scope: :admin_user do |admin, auth, _opts|
  auth.session(:admin_user)[BackOfficeGate::SESSION_KEY] = true if admin.two_factor_enrolled?
end

# ActiveAdmin's controllers (resources, dashboard, pages) get the gate.
ActiveSupport.on_load(:active_admin_controller) { include BackOfficeGate }
