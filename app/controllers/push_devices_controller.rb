# Lot 8b: the native shell's phone token. Called from the page, by the
# `push-notifications` bridge component (app/javascript/controllers/bridge/),
# with the signed-in person's session cookie and the page's CSRF token: the
# same protection as every other form, nothing exempted for the shells.
#
#   POST   /appareils  { token, platform }  register or refresh (204)
#   DELETE /appareils  { token }            the person withdrew the permission (204)
#
# The device registered by this session is remembered in it, so signing out
# of this phone unregisters it (config/initializers/push_devices.rb).
class PushDevicesController < ApplicationController
  before_action :authenticate_user!

  rate_limit to: 30, within: 1.hour, by: -> { current_user.id }, with: -> { head :too_many_requests }

  def create
    device = PushDevice.register!(current_user, token: params.require(:token).to_s, platform: params.require(:platform).to_s)
    session[:push_device_id] = device.id
    head :no_content
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  def destroy
    PushDevice.unregister!(current_user, token: params.require(:token).to_s)
    session.delete(:push_device_id)
    head :no_content
  end
end
