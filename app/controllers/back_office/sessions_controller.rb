module BackOffice
  # Back-office sign-in: ActiveAdmin's Devise sessions page, plus the
  # one-time code (`otp_attempt`) that devise-two-factor's strategy reads.
  class SessionsController < ActiveAdmin::Devise::SessionsController
    private

    # Never the app's home: an AdminUser has no household.
    def after_sign_in_path_for(resource)
      stored_location_for(resource) || admin_root_path
    end
  end
end
