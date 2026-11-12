# I4, « Comment on calcule ? » : the rules of the weekly engine in one screen.
# Public (the intro links to it before sign-up). Every number comes from
# HouseholdRules, which the engine reads too: nothing is repeated here.
class RulesController < ApplicationController
  def show
    @sizes = (2..HouseholdMember::COLORS.size).map do |members|
      { members: members, fair: HouseholdRules.fair_share(members), zone: HouseholdRules.zone(members) }
    end
    @back_path = user_signed_in? ? (current_household ? dashboard_path : account_path) : intro_path(3)
  end
end
