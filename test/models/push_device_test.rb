require "test_helper"

class PushDeviceTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
  end

  test "registering stores the token encrypted, found by its digest" do
    device = PushDevice.register!(@alice, token: "fcm-token-1", platform: "ios")

    assert_equal "fcm-token-1", device.reload.token
    assert_equal OpenSSL::Digest::SHA256.hexdigest("fcm-token-1"), device.token_digest
    raw = PushDevice.connection.select_value("SELECT token FROM push_devices WHERE id = #{device.id}")
    assert_not_includes raw, "fcm-token-1"
  end

  test "registering the same token again refreshes it instead of adding a row" do
    first = PushDevice.register!(@alice, token: "t", platform: "android", now: 3.days.ago)
    again = PushDevice.register!(@alice, token: "t", platform: "android")

    assert_equal first.id, again.id
    assert_equal 1, PushDevice.count
    assert_in_delta Time.current, again.last_seen_at, 1.second
  end

  test "a phone signed in to another account moves to it" do
    PushDevice.register!(@alice, token: "shared-phone", platform: "ios")
    PushDevice.register!(@bob, token: "shared-phone", platform: "ios")

    assert_equal [ @bob.id ], PushDevice.pluck(:user_id)
  end

  test "only known platforms and plausible tokens" do
    assert_raises(ActiveRecord::RecordInvalid) { PushDevice.register!(@alice, token: "t", platform: "web") }
    assert_raises(ActiveRecord::RecordInvalid) { PushDevice.register!(@alice, token: "", platform: "ios") }
    assert_raises(ActiveRecord::RecordInvalid) { PushDevice.register!(@alice, token: "x" * 5000, platform: "ios") }
  end

  test "unregistering only touches the person's own token" do
    PushDevice.register!(@alice, token: "a", platform: "ios")

    assert_equal 0, PushDevice.unregister!(@bob, token: "a")
    assert_equal 1, PushDevice.unregister!(@alice, token: "a")
  end

  test "a phone silent for more than two months is not reachable" do
    fresh = PushDevice.register!(@alice, token: "fresh", platform: "ios")
    PushDevice.register!(@alice, token: "stale", platform: "ios", now: PushDevice::STALE_AFTER.ago - 1.minute)

    assert_equal [ fresh ], @alice.push_devices.reachable.to_a
  end

  test "deleting the account drops its phones" do
    PushDevice.register!(@alice, token: "a", platform: "ios")

    assert AccountDeletion.new(@alice).save_as_admin(typed_email: @alice.email)
    assert_not PushDevice.exists?(user_id: @alice.id)
  end
end
