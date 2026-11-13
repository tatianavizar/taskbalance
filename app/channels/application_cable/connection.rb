module ApplicationCable
  # A WebSocket belongs to a signed-in person: the Devise session (Warden)
  # identifies them, and an anonymous connection is refused. A deleted account
  # cannot sign in, so it cannot connect either.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      user = env["warden"]&.user(:user)
      return user if user && !user.deleted?

      reject_unauthorized_connection
    end
  end
end
