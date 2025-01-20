class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :household_members
  has_many :households, through: :household_members
  has_many :liked_tasks
  has_many :tasks, through: :liked_tasks
  has_many :chores, through: :households

  before_validation :normalize_name


  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  private

def normalize_name
  self.name = name.capitalize if name.present?
end

end
