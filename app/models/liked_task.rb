class LikedTask < ApplicationRecord
  belongs_to :user
  belongs_to :task

  validates :liked, inclusion: { in: [true, false] }
  validates :task_id, uniqueness: { scope: :user_id }
end
