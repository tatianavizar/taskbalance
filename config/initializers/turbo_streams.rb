# Household streams are for current members only
# (app/channels/application_cable/household_stream_guard.rb).
Rails.application.config.to_prepare do
  unless Turbo::StreamsChannel < ApplicationCable::HouseholdStreamGuard
    Turbo::StreamsChannel.prepend(ApplicationCable::HouseholdStreamGuard)
  end
end
