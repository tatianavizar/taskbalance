# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

Task.destroy_all
puts "start seeding"
tasks_data = [
  {
    name: "Faire la vaisselle",
    time_required: 30,
    priority: 1
  },

  {
    name: "Faire les courses",
    time_required: 60,
    priority: 1
  },

  {
    name: "Lessive",
    time_required: 30,
    priority: 2
  },

  {
    name: "Cuisiner",
    time_required: 60,
    priority: 1
  },

  {
    name: "Passer l'aspirateur",
    time_required: 45,
    priority: 3
  },

  {
    name: "Nettoyer la cuisine",
    time_required: 30,
    priority: 1
  }
]

tasks_data.each do |task|
  task = Task.create!(
    name: task[:name],
    time_required: task[:time_required],
    priority: task[:priority],
  )
end

puts "seeding completed"
