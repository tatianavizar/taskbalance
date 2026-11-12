require "test_helper"

# Mails and jobs wait for the transaction that wrote their record.
class EnqueueAfterCommitTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "every job class enqueues after commit, mail deliveries included" do
    assert ActiveJob::Base.enqueue_after_transaction_commit
    assert ActionMailer::MailDeliveryJob.enqueue_after_transaction_commit
    assert NotificationsDispatchJob.enqueue_after_transaction_commit
  end

  test "a mail enqueued inside a transaction waits for the commit" do
    ApplicationRecord.transaction do
      AccountMailer.already_registered(users(:alice)).deliver_later
      assert_no_enqueued_jobs
    end
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob
  end

  test "a rolled-back transaction enqueues nothing" do
    ApplicationRecord.transaction do
      AccountMailer.already_registered(users(:alice)).deliver_later
      raise ActiveRecord::Rollback
    end
    assert_no_enqueued_jobs
  end
end
