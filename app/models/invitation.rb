class Invitation < ApplicationRecord
  belongs_to :household

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true
  validates :email, uniqueness: { scope: :household_id, message: "already invited to this household" }

  before_create :generate_token

private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end
end
