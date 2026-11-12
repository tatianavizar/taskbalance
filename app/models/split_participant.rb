# Someone the split is made for: a member of the household, or, for the
# starting split only, a person invited but not yet in (decision D15: they
# count in the fair share, and the split is marked provisional).
#
#   key          "user:12" or "invitation:5", used in chore_assignees,
#                week_plans and the proposal
#   user_id      nil for an invitation without an account yet
#   provisional  true for someone not yet a member
#
# Not persisted. Household#split_participants builds them.
SplitParticipant = Data.define(:key, :user_id, :invitation_id, :first_name, :monogram, :color, :provisional) do
  def self.for_member(member)
    new(key: "user:#{member.user_id}", user_id: member.user_id, invitation_id: nil,
        first_name: member.user.first_name, monogram: member.monogram, color: member.color,
        provisional: false)
  end

  # The first name given on B3, the account's once the person signed up.
  def self.for_invitation(invitation, color:, user: nil)
    name = user&.first_name.presence || invitation.display_name
    new(key: "invitation:#{invitation.id}", user_id: user&.id, invitation_id: invitation.id,
        first_name: name, monogram: invitation.monogram.presence || name.first.to_s.upcase, color: color, provisional: true)
  end

  def provisional?
    provisional
  end

  def to_h
    { "key" => key, "user_id" => user_id, "invitation_id" => invitation_id, "first_name" => first_name,
      "monogram" => monogram, "color" => color, "provisional" => provisional }
  end

  def self.from_h(hash)
    hash = hash.stringify_keys
    new(key: hash["key"], user_id: hash["user_id"], invitation_id: hash["invitation_id"],
        first_name: hash["first_name"], monogram: hash["monogram"], color: hash["color"],
        provisional: hash["provisional"] == true)
  end
end
