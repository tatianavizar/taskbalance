# The cookie banner's « OK ». The app only sets strictly necessary cookies
# (session, one-week session, intro seen), which need no consent: the banner
# informs, and remembering that it was read is itself a necessary cookie.
class CookieNoticesController < ApplicationController
  def create
    cookies[:cookie_notice_seen] = { value: "1", expires: 12.months.from_now, httponly: true, same_site: :lax }
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("cookie-banner") }
      format.html { redirect_back fallback_location: root_path }
    end
  end
end
