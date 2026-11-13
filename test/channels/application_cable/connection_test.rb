require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  FakeWarden = Struct.new(:signed_in) do
    def user(scope) = (signed_in if scope == :user)
  end

  test "a signed-in person connects, identified by their account" do
    connect env: { "warden" => FakeWarden.new(users(:alice)) }

    assert_equal users(:alice), connection.current_user
  end

  test "an anonymous connection is refused" do
    assert_reject_connection { connect env: { "warden" => FakeWarden.new(nil) } }
    assert_reject_connection { connect }
  end

  test "a deleted account is refused" do
    users(:alice).update_column(:deleted_at, Time.current)

    assert_reject_connection { connect env: { "warden" => FakeWarden.new(users(:alice)) } }
  end
end
