namespace :admin do
  desc "Create the first back-office account, or reset its password, from ADMIN_EMAIL and ADMIN_PASSWORD (12 characters at least)"
  task bootstrap: :environment do
    email = ENV["ADMIN_EMAIL"].to_s.strip
    password = ENV["ADMIN_PASSWORD"].to_s
    abort "ADMIN_EMAIL and ADMIN_PASSWORD are required." if email.blank? || password.blank?

    admin = AdminUser.find_or_initialize_by(email: email.downcase)
    created = admin.new_record?
    admin.password = password
    admin.password_confirmation = password
    admin.unlock_access! if admin.persisted? && admin.access_locked?
    abort "Not saved: #{admin.errors.full_messages.to_sentence}" unless admin.save

    puts created ? "Back-office account created for #{admin.email}." : "Password reset for #{admin.email}."
    puts(admin.two_factor_enrolled? ? "Two-factor already set up." : "Sign in at /admin: the two-factor secret is shown at the first sign-in.")
  end

  desc "Start the second factor over for ADMIN_EMAIL (lost phone): the account enrols again at its next sign-in"
  task reset_two_factor: :environment do
    admin = AdminUser.find_by(email: ENV["ADMIN_EMAIL"].to_s.strip.downcase)
    abort "No back-office account for that ADMIN_EMAIL." unless admin

    admin.reset_two_factor!
    puts "Two-factor reset for #{admin.email}."
  end
end
