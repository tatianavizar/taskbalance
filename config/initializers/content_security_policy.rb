# Be sure to restart your server when you modify this file.

# Content-Security-Policy for every page (mails are not concerned: no header
# goes with an email). Everything the app needs is on its own origin: scripts
# through importmap, the Tailwind stylesheet, the self-hosted fonts, Action
# Cable. Nothing comes from a third party.
#
#   scripts        'self' + the request nonce (importmap's inline map and
#                  module tag carry it); no inline script anywhere else.
#   style elements 'self' + the nonce (Turbo's progress bar reads it from the
#                  csp-nonce meta tag).
#   style="…"      allowed (style-src-attr 'unsafe-inline'): the views size
#                  bars and colour avatars with computed inline values. An
#                  attribute cannot run code; it is the one inline exception.
#   connect        'self', plus the wss:// origin of Action Cable (Safari does
#                  not count ws/wss as 'self').
#   framing        nobody (frame-ancestors 'none'); <base> and form targets
#                  stay on this origin (the cookie banner posts to /cookies).
Rails.application.configure do
  cable_origins =
    if Rails.env.production?
      AppHosts.all(ENV, Rails.application.credentials).map { |host| "wss://#{host}" } # config/app_hosts.rb
    else
      [ "ws://localhost:*", "ws://127.0.0.1:*" ]
    end

  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self
    policy.style_src       :self
    policy.style_src_attr  :unsafe_inline
    policy.font_src        :self
    policy.img_src         :self, :data
    policy.connect_src     :self, *cable_origins
    policy.object_src      :none
    policy.frame_ancestors :none
    policy.base_uri        :self
    policy.form_action     :self
  end

  # One nonce per session rather than per request: Turbo Drive keeps the first
  # page's policy while it swaps pages, so the nonce must not change between
  # visits. It is kept in the session itself: `session.id` is still nil on a
  # visitor's very first page (no cookie yet), which would leave that page
  # without a nonce and block importmap.
  config.content_security_policy_nonce_generator = ->(request) {
    request.session[:csp_nonce] ||= SecureRandom.urlsafe_base64(18)
  }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
