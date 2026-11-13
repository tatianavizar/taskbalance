require "io/console"

# Back-office accounts from the console. Nothing here is reachable from the web.
module AdminTasks
  module_function

  # Interactive: a prompt without echo, asked twice. Non-interactive (a deploy
  # script): ADMIN_PASSWORD, with a warning, since an environment variable can
  # end up in shell history, process listings and CI logs.
  def read_password(input: $stdin, output: $stderr, env: ENV)
    if input.tty?
      first = prompt("Mot de passe (12 caractères au moins) : ", input, output)
      again = prompt("Une seconde fois : ", input, output)
      abort "The two entries differ." unless first == again
      first
    elsif env["ADMIN_PASSWORD"].present?
      output.puts "Warning: the password comes from ADMIN_PASSWORD. It can leak through shell history, process listings or CI logs: prefer the prompt."
      env["ADMIN_PASSWORD"]
    else
      abort "No terminal to ask the password on, and ADMIN_PASSWORD is not set."
    end
  end

  def prompt(label, input, output)
    output.print label
    value = input.noecho(&:gets).to_s.chomp
    output.puts
    value
  end

  def print_link(result)
    return puts("Two-factor already set up: sign in with the password and a code.") unless result.enrolment_issued?

    puts "Enrolment link (valid #{AdminUser::ENROLMENT_LINK_VALIDITY.inspect}, single use, give it to #{result.admin.email} only):"
    puts "  #{BackOffice::Console.enrolment_url(result.enrolment_token)}"
    puts "Open it, sign in with the password, then scan or type the secret and enter the first code."
  end
end

namespace :admin do
  desc "Create a back-office account, or reset its password: ADMIN_EMAIL, ROLE (superadmin by default for a new account, admin; an existing account keeps its role unless ROLE is given), and the password asked on the terminal (ADMIN_PASSWORD only as a fallback when there is none)"
  task bootstrap: :environment do
    email = ENV["ADMIN_EMAIL"].to_s.strip
    abort "ADMIN_EMAIL is required." if email.blank?
    role = ENV["ROLE"].to_s.strip.presence
    abort "ROLE must be one of: #{AdminUser::ROLES.join(', ')}." if role && !AdminUser::ROLES.include?(role)

    password = AdminTasks.read_password
    result = BackOffice::Console.bootstrap(email: email, password: password, role: role)
    puts result.created ? "Back-office account created for #{result.admin.email} (#{result.admin.role})." : "Password reset for #{result.admin.email} (#{result.admin.role}; its sessions are ended)."
    AdminTasks.print_link(result)
  rescue BackOffice::Console::Invalid => e
    abort "Not saved: #{e.message}"
  end

  desc "Start the second factor over for ADMIN_EMAIL (lost phone): new secret, new link, all sessions ended"
  task reset_two_factor: :environment do
    result = BackOffice::Console.reset_two_factor(email: ENV["ADMIN_EMAIL"])
    puts "Two-factor reset for #{result.admin.email}; its sessions are ended."
    AdminTasks.print_link(result)
  rescue BackOffice::Console::Invalid => e
    abort e.message
  end
end
