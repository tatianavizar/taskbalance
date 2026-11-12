# Journal : tout ce que l'équipe a écrit depuis le back-office. Lecture seule.
ActiveAdmin.register AdminAction do
  menu label: "Journal", priority: 5
  actions :index, :show

  config.sort_order = "created_at_desc"
  config.comments = false

  filter :action, label: "Action", as: :select, collection: -> { BackOffice::Labels.action_options }
  filter :admin_email, label: "Par"
  filter :created_at, label: "Le"

  index title: "Journal", download_links: false do
    column("Le", :created_at)
    column("Par", :admin_email)
    column("Action", :action) { |entry| BackOffice::Labels.action(entry.action) }
    column("Sur", sortable: false) { |entry| entry.record_type ? "#{entry.record_type} ##{entry.record_id}" : "—" }
    column("Détail", sortable: false) { |entry| entry.detail.present? ? entry.detail.to_json : "—" }
  end

  show title: "Entrée du journal" do
    attributes_table do
      row("Le") { |entry| l(entry.created_at, format: :long) }
      row("Par") { |entry| entry.admin_email }
      row("Action") { |entry| BackOffice::Labels.action(entry.action) }
      row("Sur") { |entry| entry.record_type ? "#{entry.record_type} ##{entry.record_id}" : "—" }
      row("Détail") { |entry| pre entry.detail.to_json }
    end
  end
end
