class AddRoleColorAndMonogramToHouseholdMembers < ActiveRecord::Migration[8.0]
  COLORS = %w[mint blue stone sky sage sand].freeze

  def up
    add_column :household_members, :role, :integer, null: false, default: 0 # 0 member, 1 manager
    add_column :household_members, :color, :string
    add_column :household_members, :monogram, :string
    add_column :household_members, :monogram_customized, :boolean, null: false, default: false

    members = select_rows(<<~SQL.squish)
      SELECT hm.id, hm.household_id, u.first_name
      FROM household_members hm JOIN users u ON u.id = hm.user_id
      ORDER BY hm.household_id, hm.created_at, hm.id
    SQL

    members.group_by { |_, household_id, _| household_id }.each_value do |rows|
      rows.each_with_index do |(id, _, first_name), index|
        color = COLORS[index] # a household with more than 6 members keeps nil: flagged below
        execute "UPDATE household_members SET color = #{quote(color)} WHERE id = #{id.to_i}" if color
        execute "UPDATE household_members SET role = 1 WHERE id = #{id.to_i}" if index.zero?
      end
      assign_monograms(rows)
    end

    add_index :household_members, [ :household_id, :color ], unique: true
  end

  def down
    remove_index :household_members, [ :household_id, :color ]
    remove_column :household_members, :monogram_customized
    remove_column :household_members, :monogram
    remove_column :household_members, :color
    remove_column :household_members, :role
  end

  private

  # Same rule as HouseholdMember.refresh_monograms!: the initial, two letters
  # only when two initials coincide.
  def assign_monograms(rows)
    initials = rows.map { |_, _, name| name.to_s.strip[0].to_s.upcase }
    taken = []
    rows.each_with_index do |(id, _, name), i|
      letters = name.to_s.strip
      monogram = initials[i]
      if initials.count(initials[i]) > 1 && letters.length > 1
        candidates = letters[1..].chars.reverse.map { |c| initials[i] + c.downcase }
        monogram = candidates.find { |c| !taken.include?(c) } || candidates.first
      end
      taken << monogram
      execute "UPDATE household_members SET monogram = #{quote(monogram)} WHERE id = #{id.to_i}"
    end
  end
end
