require "test_helper"

class NotificationsUnsubscribeTest < ActiveSupport::TestCase
  setup { @user = users(:alice) }

  test "a token resolves to the person and the event type" do
    token = Notifications::Unsubscribe.token_for(@user, "alert")

    assert_equal [ @user, "alert" ], Notifications::Unsubscribe.resolve(token)
  end

  test "the token is safe in a URL and needs no session" do
    assert_match(/\A[A-Za-z0-9_\-=]+\z/, Notifications::Unsubscribe.token_for(@user, "weekly_report"))
  end

  test "a tampered token resolves to nothing" do
    token = Notifications::Unsubscribe.token_for(@user, "alert")
    payload, signature = token.split("--")

    forged_payload = Base64.urlsafe_encode64({ _rails: { data: [ users(:bob).id, "alert" ], pur: "notification_unsubscribe" } }.to_json)
    flipped = signature.dup.tap { |s| s[0] = s[0] == "a" ? "b" : "a" }

    [ "#{forged_payload}--#{signature}", "#{payload}--#{flipped}", payload, "", "garbage", token + "x", token.reverse ].each do |bad|
      assert_nil Notifications::Unsubscribe.resolve(bad), "#{bad.inspect} must not resolve"
    end
    assert_nil Notifications::Unsubscribe.resolve(nil)
  end

  test "a token for another purpose does not resolve" do
    other = Notifications::Unsubscribe.verifier.generate([ @user.id, "alert" ], purpose: :something_else)

    assert_nil Notifications::Unsubscribe.resolve(other)
  end

  test "a signed token naming an unknown type or a missing person does not resolve" do
    assert_nil Notifications::Unsubscribe.resolve(Notifications::Unsubscribe.verifier.generate([ @user.id, "password" ], purpose: :notification_unsubscribe))
    assert_nil Notifications::Unsubscribe.resolve(Notifications::Unsubscribe.verifier.generate([ 0, "alert" ], purpose: :notification_unsubscribe))
  end

  test "a token for a deleted account no longer resolves" do
    token = Notifications::Unsubscribe.token_for(@user, "alert")
    @user.update_column(:deleted_at, Time.current)

    assert_nil Notifications::Unsubscribe.resolve(token)
  end

  test "the token for one type cannot be turned into another" do
    token = Notifications::Unsubscribe.token_for(@user, "alert")

    assert_equal "alert", Notifications::Unsubscribe.resolve(token).last
    assert_not_equal Notifications::Unsubscribe.token_for(@user, "weekly_report"), token
  end
end
