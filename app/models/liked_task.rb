class LikedTask < ApplicationRecord
  belongs_to :user
  belongs_to :task

  validates :liked, inclusion: { in: [true, false] }
end
