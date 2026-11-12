# Signing out of the native app unregisters that phone from push
# (docs/plan-de-travail.md, F4: « La déconnexion désinscrit aussi le téléphone
# des push »). PushDevicesController remembers in the session which device
# this session registered; every sign-out of a user (the button, a password
# reset that signs out, Devise's sign_out) passes here before the session is
# cleared. Other phones of the same person stay registered.
Warden::Manager.before_logout do |user, auth, options|
  next unless options[:scope] == :user && user.is_a?(User)

  device_id = auth.raw_session["push_device_id"]
  PushDevice.where(id: device_id, user_id: user.id).delete_all if device_id
end
