# A phone that accepted notifications (lot 8b). The native shell asks for the
# permission (H1), gets an FCM registration token and hands it to the page
# through the `push-notifications` bridge component, which posts it to
# PushDevicesController. Both platforms go through FCM HTTP v1 (FCM relays to
# APNs for iOS), so there is one kind of token.
#
#   PushDevice.register!(user, token:, platform:)  # create or refresh; a token
#                                                  # that moved to another account
#                                                  # (shared phone) follows it
#   PushDevice.unregister!(user, token:)           # the shell, when the
#                                                  # permission is withdrawn
#   PushDevice.reachable                           # seen within STALE_AFTER
#
# The token is encrypted at rest; `token_digest` (SHA-256) is how a row is
# found and kept unique, so the clear token is never queried. A row goes when
# FCM says the token is dead (Push::Delivery), at sign-out of the phone that
# registered it (Warden hook, config/initializers/push_devices.rb) and with
# the account (AccountDeletion; the foreign key also cascades). Leaving a
# household keeps the phone: notifications about the old household are
# withdrawn by HouseholdDeparture and checked again at sending.
class PushDevice < ApplicationRecord
  PLATFORMS = %w[ios android].freeze

  # Firebase considers a token that has not checked in for two months stale.
  # The shell refreshes `last_seen_at` at every launch.
  STALE_AFTER = 60.days

  # FCM tokens are about 160 characters; anything far beyond is not one.
  MAX_TOKEN_LENGTH = 4096

  belongs_to :user

  encrypts :token

  validates :platform, inclusion: { in: PLATFORMS }
  validates :token, presence: true, length: { maximum: MAX_TOKEN_LENGTH }

  before_validation { self.token_digest = self.class.digest(token) if token.present? }

  scope :reachable, ->(now = Time.current) { where(last_seen_at: (now - STALE_AFTER)..) }

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  def self.register!(user, token:, platform:, now: Time.current)
    device = find_or_initialize_by(token_digest: digest(token))
    device.assign_attributes(user: user, token: token, platform: platform, last_seen_at: now)
    device.save!
    device
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def self.unregister!(user, token:)
    where(user_id: user.id, token_digest: digest(token)).delete_all
  end
end
