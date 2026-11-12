# Lot 9: the files Apple and Google fetch to let the 50/50 apps open the
# site's links (universal links, App Links). Content in NativeApp.
#
# Plain ActionController::Base on purpose: Apple's and Google's fetchers are
# not browsers (allow_browser must not answer 406), never signed in, and the
# files must be served as JSON, without a redirect, at these exact paths.
class WellKnownController < ActionController::Base
  def apple_app_site_association
    expires_in 1.hour, public: true
    render json: NativeApp.apple_app_site_association
  end

  def asset_links
    expires_in 1.hour, public: true
    render json: NativeApp.asset_links
  end
end
