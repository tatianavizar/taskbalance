module Notifications
  # Where a notification can go, in order of preference (D9: push when the
  # person has a device that accepts it, otherwise email).
  #
  # A channel is a class with
  #   NAME                       stored in notifications.channel
  #   .available_for?(user)      can this person be reached this way now?
  #   #deliver(notification)     hands the message over (enqueue; never raises
  #                              for a recoverable problem)
  # Lot 8b adds `Channels::Push` and lists it before Email in `registry`; the
  # Notifier does not change.
  module Channels
    class << self
      # Most preferred first. Email last: it is the fallback.
      def registry
        @registry ||= [ Email ]
      end
      attr_writer :registry

      # The first channel that reaches this person, or nil.
      def for(user)
        registry.find { |channel| channel.available_for?(user) }
      end

      def fetch(name)
        registry.find { |channel| channel::NAME == name.to_s } or raise KeyError, "unknown channel #{name}"
      end
    end
  end
end
