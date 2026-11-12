# Back-office sessions (Warden hooks, scope :admin_user only).
#
# - after_authentication: a strategy just signed someone in. The two-factor
#   strategy lets an enrolled admin through only with a valid TOTP code
#   (devise-two-factor), so reaching this hook with an enrolled AdminUser means
#   the code was checked: remember it (BackOfficeGate), and the time, for the
#   absolute lifetime below. The sign-in is written to the audit log.
# - after_set_user on every request (:fetch): a session older than
#   AdminUser::SESSION_LIFETIME (8 h from sign-in) ends, however active it is.
#   The 30-minute idle timeout is Devise's :timeoutable.
# - before_failure: a refused sign-in is written to the audit log.
#
# The flags live in the Warden scope session: they go away with the sign-out.
Warden::Manager.after_authentication scope: :admin_user do |admin, auth, _opts|
  session = auth.session(:admin_user)
  session["signed_in_at"] = Time.current.to_i
  session[BackOfficeGate::SESSION_KEY] = true if admin.two_factor_enrolled?
  BackOffice::SignInAudit.signed_in(admin, auth.env)
end

Warden::Manager.after_set_user scope: :admin_user, only: :fetch do |_admin, auth, _opts|
  started_at = auth.session(:admin_user)["signed_in_at"].to_i
  if started_at + AdminUser::SESSION_LIFETIME.to_i < Time.current.to_i
    auth.logout(:admin_user)
    throw :warden, scope: :admin_user, message: :timeout
  end
end

Warden::Manager.before_failure do |env, opts|
  BackOffice::SignInAudit.failed(env, opts) if opts[:scope] == :admin_user
end

# ActiveAdmin's controllers (resources, dashboard, pages) get the gate.
ActiveSupport.on_load(:active_admin_controller) do
  include BackOfficeGate
  include BackOfficeSortable
end
