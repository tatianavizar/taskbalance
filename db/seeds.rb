puts "Seeding task catalogue..."

tasks_data = [
  # Cuisine
  { name: "Cuisiner le repas", time_required: 45, priority: 5, recurring: true },
  { name: "Faire la vaisselle", time_required: 20, priority: 5, recurring: true },
  { name: "Vider le lave-vaisselle", time_required: 10, priority: 4, recurring: true },
  { name: "Nettoyer la cuisine", time_required: 20, priority: 4, recurring: true },
  { name: "Préparer les lunchboxes", time_required: 15, priority: 4, recurring: true },
  { name: "Nettoyer le four", time_required: 40, priority: 2, recurring: false },
  { name: "Nettoyer le réfrigérateur", time_required: 30, priority: 2, recurring: false },

  # Courses & provisions
  { name: "Faire les courses alimentaires", time_required: 60, priority: 4, recurring: true },
  { name: "Planifier les menus de la semaine", time_required: 20, priority: 3, recurring: true },
  { name: "Gérer la liste de courses", time_required: 10, priority: 3, recurring: true },
  { name: "Commander en ligne", time_required: 20, priority: 3, recurring: false },

  # Ménage
  { name: "Passer l'aspirateur", time_required: 30, priority: 3, recurring: true },
  { name: "Laver les sols", time_required: 40, priority: 3, recurring: true },
  { name: "Dépoussiérer", time_required: 20, priority: 2, recurring: true },
  { name: "Nettoyer les sanitaires", time_required: 20, priority: 3, recurring: true },
  { name: "Nettoyer la salle de bain", time_required: 30, priority: 3, recurring: true },
  { name: "Vider les poubelles", time_required: 10, priority: 4, recurring: true },
  { name: "Sortir les poubelles de tri", time_required: 10, priority: 3, recurring: true },
  { name: "Nettoyer les vitres", time_required: 60, priority: 1, recurring: false },
  { name: "Ranger le salon", time_required: 20, priority: 3, recurring: true },
  { name: "Faire les lits", time_required: 10, priority: 3, recurring: true },
  { name: "Changer les draps", time_required: 20, priority: 2, recurring: true },

  # Linge
  { name: "Lancer une lessive", time_required: 10, priority: 3, recurring: true },
  { name: "Étendre le linge", time_required: 15, priority: 3, recurring: true },
  { name: "Plier le linge", time_required: 20, priority: 3, recurring: true },
  { name: "Repasser", time_required: 45, priority: 2, recurring: true },
  { name: "Ranger le linge", time_required: 15, priority: 3, recurring: true },

  # Enfants
  { name: "Emmener les enfants à l'école", time_required: 30, priority: 5, recurring: true },
  { name: "Récupérer les enfants à l'école", time_required: 30, priority: 5, recurring: true },
  { name: "Aide aux devoirs", time_required: 45, priority: 4, recurring: true },
  { name: "Donner le bain aux enfants", time_required: 30, priority: 4, recurring: true },
  { name: "Préparer les cartables", time_required: 10, priority: 4, recurring: true },
  { name: "Gérer les activités extrascolaires", time_required: 30, priority: 3, recurring: true },
  { name: "Rendez-vous pédiatre", time_required: 60, priority: 3, recurring: false },
  { name: "Acheter les fournitures scolaires", time_required: 60, priority: 2, recurring: false },

  # Charge mentale / administratif
  { name: "Payer les factures", time_required: 20, priority: 4, recurring: true },
  { name: "Gérer les assurances", time_required: 30, priority: 2, recurring: false },
  { name: "Déclarer les impôts", time_required: 120, priority: 3, recurring: false },
  { name: "Prendre des rendez-vous médicaux", time_required: 15, priority: 3, recurring: false },
  { name: "Gérer les remboursements santé", time_required: 15, priority: 2, recurring: true },
  { name: "Renouveler les abonnements", time_required: 20, priority: 2, recurring: false },
  { name: "Gérer la banque et le budget", time_required: 30, priority: 3, recurring: true },
  { name: "Organiser les vacances", time_required: 120, priority: 2, recurring: false },

  # Entretien & maintenance
  { name: "Bricolage / petites réparations", time_required: 60, priority: 2, recurring: false },
  { name: "Arroser les plantes", time_required: 10, priority: 3, recurring: true },
  { name: "Entretien du jardin", time_required: 90, priority: 2, recurring: true },
  { name: "Entretien de la voiture", time_required: 60, priority: 2, recurring: false },
  { name: "Gérer les prestataires (plombier, électricien...)", time_required: 60, priority: 2, recurring: false },
  { name: "Achats pour la maison", time_required: 60, priority: 2, recurring: false }
]

tasks_data.each do |attrs|
  Task.find_or_create_by!(name: attrs[:name]) do |task|
    task.time_required = attrs[:time_required]
    task.priority      = attrs[:priority]
    task.recurring     = attrs[:recurring]
  end
end

puts "Done — #{Task.count} tasks in catalogue."
