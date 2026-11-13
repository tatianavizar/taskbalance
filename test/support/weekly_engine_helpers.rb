# Builders for the weekly engine tests: households with members who joined at
# a chosen moment, and logs at a chosen local time.
module WeeklyEngineHelpers
  PARIS = "Europe/Paris".freeze

  def local(zone, *args) = ActiveSupport::TimeZone[zone].local(*args)
  def paris(*args) = local(PARIS, *args)

  # Creates a household whose members all joined at `joined_at` (default: long
  # before the weeks under test). Returns [household, [user, ...]].
  def build_household(*first_names, zone: PARIS, joined_at: paris(2026, 9, 1, 9))
    users = first_names.map.with_index do |name, i|
      User.create!(first_name: name, email: "member#{i}-#{SecureRandom.hex(4)}@example.test",
                   password: "password123", confirmed_at: joined_at)
    end
    household = Household.create_for(users.first, name: "Foyer test", time_zone: zone)
    assert household.persisted?, household.errors.full_messages.to_sentence
    users.drop(1).each { |user| household.household_members.create!(user: user) }
    household.update_columns(created_at: joined_at)
    household.household_members.update_all(created_at: joined_at)
    [ household.reload, users ]
  end

  def join(household, first_name, at:)
    user = User.create!(first_name: first_name, email: "joiner-#{SecureRandom.hex(4)}@example.test",
                        password: "password123", confirmed_at: at)
    member = household.household_members.create!(user: user)
    member.update_columns(created_at: at)
    user
  end

  def membership(household, user)
    household.household_members.find_by!(user: user)
  end

  # `count` logs by `user`, each carrying the given dimensions.
  def log!(household, user, at:, mental: true, execution: true, minutes: 10, count: 1, chore: nil, category: "cleaning")
    Array.new(count) do
      ChoreLog.create!(user: user, household: household, chore: chore, chore_name: chore ? nil : "Ménage",
                       category: category, mental_load: mental, execution_load: execution,
                       time_spent: minutes, completed_at: at)
    end
  end

  # A balanced week for two members: equal mental and execution logs.
  def log_balanced_week!(household, users, week)
    at = week.start_at + 2.days + 10.hours
    users.each { |user| log!(household, user, at: at) }
  end

  def run_engine(household, now)
    travel_to(now) { WeeklyEngine.new(household.reload).run(now: now) }
  ensure
    household.reload
  end
end
