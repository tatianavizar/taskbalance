# Jobs (mails included) are enqueued only once the surrounding database
# transaction has committed. Solid Queue lives in its own database: a job
# enqueued inside a transaction could otherwise run before the commit and not
# find its record (a Notification, an Invitation). A rolled-back transaction
# enqueues nothing.
#
# Set on ActiveJob::Base so it also covers ActionMailer::MailDeliveryJob and
# Turbo's broadcast jobs, which do not inherit from ApplicationJob.
# (config.active_job.enqueue_after_transaction_commit is deprecated in 8.0.)
ActiveSupport.on_load(:active_job) do
  self.enqueue_after_transaction_commit = true
end
