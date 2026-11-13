require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build(attrs = {})
    User.new({ email: "new@test.com", first_name: "Nina", password: "password123" }.merge(attrs))
  end

  test "first name is required and limited" do
    assert build.valid?
    assert_not build(first_name: " ").valid?
    assert_not build(first_name: "a" * 51).valid?
  end

  test "first name is stripped" do
    assert_equal "Nina", build(first_name: "  Nina ").tap(&:valid?).first_name
  end

  test "time zone defaults to Europe/Paris and must be a real zone" do
    assert_equal "Europe/Paris", build.time_zone
    assert_not build(time_zone: "Nowhere/Land").valid?
  end

  test "a user has one household, and chores come from it" do
    alice = users(:alice)
    assert_equal households(:smith_home), alice.household
    assert_equal households(:smith_home).chores.order(:id).pluck(:id), alice.chores.order(:id).pluck(:id)
    assert_nil users(:dana).household
    assert_empty users(:dana).chores
  end

  test "a new account is created unconfirmed and can still sign in" do
    user = build.tap(&:save!)
    assert_not user.confirmed?
    assert user.active_for_authentication?
  end

  test "the confirmation link lasts 24 hours" do
    assert_equal 24.hours, Devise.confirm_within
    user = build.tap(&:save!)
    user.update_column(:confirmation_sent_at, 25.hours.ago)
    assert user.send(:confirmation_period_expired?)
  end

  test "sessions are always remembered" do
    assert build.remember_me
    assert_equal 1.week, Devise.remember_for
  end
end
