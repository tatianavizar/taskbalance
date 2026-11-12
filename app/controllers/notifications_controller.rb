# The in-app feed: what 50/50 told the person, read and unread. Opening an item
# marks it read and goes to the screen it is about.
class NotificationsController < ApplicationController
  before_action :authenticate_user!

  FEED_SIZE = 50

  def index
    @notifications = Notification.where(user_id: current_user.id).feed.limit(FEED_SIZE).to_a
  end

  def show
    notification = Notification.where(user_id: current_user.id).feed.find(params[:id])
    notification.read!
    target = Notifications::Catalogue.fetch(notification.kind).target
    redirect_to public_send("#{target}_path")
  end

  def read_all
    Notification.mark_all_read!(current_user)
    redirect_to notifications_path
  end
end
