# The identity of the iOS and Android shells (native/), and the links that
# open them instead of the browser (lot 9: universal links and App Links).
# Read by WellKnownController (apple-app-site-association, assetlinks.json);
# native/android/app/src/main/AndroidManifest.xml lists the same paths.
#
#   APPLE_TEAM_ID                 10 characters, from the Apple developer account
#   IOS_BUNDLE_ID                 default app.cinquante.mobile
#   ANDROID_PACKAGE               default app.cinquante.mobile
#   ANDROID_CERT_FINGERPRINTS     SHA-256 fingerprints of the signing
#                                 certificates (Play App Signing and upload key),
#                                 comma-separated, "AA:BB:..."
#
# Until they are set, the files carry visible placeholders: the files stay
# valid JSON, and no app can claim the links.
module NativeApp
  DEFAULT_BUNDLE_ID = "app.cinquante.mobile".freeze
  TEAM_ID_PLACEHOLDER = "TEAMID0000".freeze
  FINGERPRINT_PLACEHOLDER = "00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00".freeze

  # Opened by the app: the email links (invitation, password reset, address
  # confirmation) and the buttons of the notification emails
  # (Notifications::Catalogue targets). "*" matches anything.
  LINK_PATHS = %w[
    /invitations/*
    /users/password/edit
    /users/confirmation
    /dashboard
    /bilan
    /bilan/*
    /niveaux
    /chores
    /chores/*
    /journal
    /journal/*
    /absences
    /absences/*
    /pauses
    /pauses/*
    /notifications
    /notifications/*
  ].freeze

  # Always the browser: the one-click unsubscribe (works without the app or
  # an account), the back office and the machine-readable files.
  EXCLUDED_PATHS = %w[/desinscription/* /admin /admin/* /.well-known/* /configurations/*].freeze

  def self.apple_app_id(env = ENV)
    "#{env["APPLE_TEAM_ID"].presence || TEAM_ID_PLACEHOLDER}.#{env["IOS_BUNDLE_ID"].presence || DEFAULT_BUNDLE_ID}"
  end

  def self.android_package(env = ENV)
    env["ANDROID_PACKAGE"].presence || DEFAULT_BUNDLE_ID
  end

  def self.android_fingerprints(env = ENV)
    list = env["ANDROID_CERT_FINGERPRINTS"].to_s.split(",").map(&:strip).reject(&:empty?)
    list.presence || [ FINGERPRINT_PLACEHOLDER ]
  end

  # https://developer.apple.com/documentation/xcode/supporting-associated-domains
  # (the "components" form, iOS 14 and later). Exclusions come first: the first
  # matching component wins.
  def self.apple_app_site_association(env = ENV)
    components = EXCLUDED_PATHS.map { |path| { "/" => path, "exclude" => true } } +
                 LINK_PATHS.map { |path| { "/" => path } }
    {
      applinks: { details: [ { appIDs: [ apple_app_id(env) ], components: components } ] },
      webcredentials: { apps: [ apple_app_id(env) ] }
    }
  end

  # https://developer.android.com/training/app-links/verify-android-applinks
  def self.asset_links(env = ENV)
    [
      {
        relation: [ "delegate_permission/common.handle_all_urls", "delegate_permission/common.get_login_creds" ],
        target: { namespace: "android_app", package_name: android_package(env), sha256_cert_fingerprints: android_fingerprints(env) }
      }
    ]
  end
end
