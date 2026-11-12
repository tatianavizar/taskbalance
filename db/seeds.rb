# Task catalogue. Each task is found by its stable `key` (the former English
# name, so databases seeded before the translation keep their chores): run the
# seeds again to rename, translate or change a default without losing the
# households' chores. Nothing is deleted.
#
#   loads   :m mental load, :x execution, :mx both
#   freq    daily, weekly, monthly, annually (times: per period, daily and
#           weekly only)
#   regular ticked by default in the catalogue (C1)
puts "Seeding task catalogue..."

load_flags = { m: [ true, false ], x: [ false, true ], mx: [ true, true ] }

tasks_data = [
  # cooking
  [ "cook_a_meal",               "Préparer un repas",                  "cooking",     45, 5, true,  :x,  :daily ],
  [ "do_the_dishes",             "Faire la vaisselle",                 "cooking",     20, 5, true,  :x,  :daily ],
  [ "empty_the_dishwasher",      "Vider le lave-vaisselle",            "cooking",     10, 4, true,  :x,  :daily ],
  [ "clean_the_kitchen",         "Nettoyer la cuisine",                "cooking",     20, 4, true,  :x,  :weekly ],
  [ "prepare_lunchboxes",        "Préparer les lunchbox",              "cooking",     15, 4, false, :mx, :weekly, 5 ],
  [ "clean_the_oven",            "Nettoyer le four",                   "cooking",     40, 2, false, :x,  :monthly ],
  [ "clean_the_fridge",          "Nettoyer le réfrigérateur",          "cooking",     30, 2, false, :x,  :monthly ],

  # groceries
  [ "buy_groceries",             "Faire les courses",                  "groceries",   60, 4, true,  :mx, :weekly ],
  [ "plan_weekly_meals",         "Planifier les repas",                "groceries",   20, 3, true,  :m,  :weekly ],
  [ "manage_the_shopping_list",  "Faire la liste de courses",          "groceries",   10, 3, true,  :m,  :weekly ],
  [ "order_groceries_online",    "Commander les courses en ligne",     "groceries",   20, 3, false, :m,  :weekly ],

  # cleaning
  [ "vacuum",                    "Passer l'aspirateur",                "cleaning",    30, 3, true,  :x,  :weekly ],
  [ "mop_the_floors",            "Laver les sols",                     "cleaning",    40, 3, false, :x,  :weekly ],
  [ "dust",                      "Faire la poussière",                 "cleaning",    20, 2, false, :x,  :weekly ],
  [ "clean_the_toilets",         "Nettoyer les toilettes",             "cleaning",    20, 3, false, :x,  :weekly ],
  [ "clean_the_bathroom",        "Nettoyer la salle de bain",          "cleaning",    30, 3, true,  :x,  :weekly ],
  [ "empty_the_bins",            "Sortir les poubelles",               "cleaning",     5, 4, true,  :x,  :weekly, 2 ],
  [ "take_out_recycling",        "Sortir le tri",                      "cleaning",     5, 3, false, :x,  :weekly ],
  [ "clean_the_windows",         "Laver les vitres",                   "cleaning",    60, 1, false, :x,  :monthly ],
  [ "tidy_the_living_room",      "Ranger le salon",                    "cleaning",    20, 3, false, :x,  :weekly, 2 ],
  [ "make_the_beds",             "Faire les lits",                     "cleaning",    10, 3, false, :x,  :daily ],
  [ "change_the_bed_sheets",     "Changer les draps",                  "cleaning",    20, 2, false, :x,  :weekly ],

  # laundry
  [ "start_a_wash",              "Lancer une lessive",                 "laundry",     10, 3, true,  :x,  :weekly, 3 ],
  [ "hang_the_laundry",          "Étendre le linge",                   "laundry",     15, 3, false, :x,  :weekly, 3 ],
  [ "fold_the_laundry",          "Plier et ranger le linge",           "laundry",     20, 3, true,  :x,  :weekly ],
  [ "iron_clothes",              "Repasser",                           "laundry",     45, 2, false, :x,  :weekly ],
  [ "put_away_laundry",          "Trier le linge sale",                "laundry",     10, 3, false, :mx, :weekly ],

  # childcare
  [ "drop_kids_off_at_school",   "Déposer les enfants à l'école",      "childcare",   30, 5, false, :x,  :weekly, 5 ],
  [ "pick_kids_up_from_school",  "Récupérer les enfants à l'école",    "childcare",   30, 5, false, :x,  :weekly, 5 ],
  [ "help_with_homework",        "Aider aux devoirs",                  "childcare",   45, 4, false, :mx, :weekly, 4 ],
  [ "bathe_the_kids",            "Donner le bain",                     "childcare",   30, 4, false, :x,  :daily ],
  [ "pack_school_bags",          "Préparer les sacs d'école",          "childcare",   10, 4, true,  :mx, :daily ],
  [ "manage_extracurriculars",   "Gérer les activités extrascolaires", "childcare",   30, 3, false, :m,  :weekly ],
  [ "paediatrician_appointment", "Prendre RDV pédiatre",               "childcare",   15, 3, true,  :m,  :monthly ],
  [ "buy_school_supplies",       "Acheter les fournitures scolaires",  "childcare",   60, 2, false, :mx, :annually ],

  # admin
  [ "pay_bills",                 "Payer les factures",                 "admin",       20, 4, true,  :m,  :monthly ],
  [ "manage_insurance",          "Gérer les assurances",               "admin",       30, 2, false, :m,  :annually ],
  [ "file_taxes",                "Déclarer les impôts",                "admin",      120, 3, false, :m,  :annually ],
  [ "book_medical_appointments", "Prendre les rendez-vous médicaux",   "admin",       15, 3, false, :m,  :monthly ],
  [ "handle_health_reimbursements", "Suivre les remboursements santé", "admin",       15, 2, false, :m,  :monthly ],
  [ "renew_subscriptions",       "Renouveler les abonnements",         "admin",       20, 2, false, :m,  :annually ],
  [ "manage_bank_and_budget",    "Gérer le budget et les comptes",     "admin",       30, 3, false, :m,  :monthly ],
  [ "plan_holidays",             "Organiser les vacances",             "admin",      120, 2, false, :m,  :annually ],

  # maintenance
  [ "diy_minor_repairs",         "Bricoler et réparer",                "maintenance", 60, 2, false, :mx, :monthly ],
  [ "water_the_plants",          "Arroser les plantes",                "maintenance", 10, 3, false, :x,  :weekly, 2 ],
  [ "garden_maintenance",        "Entretenir le jardin",               "maintenance", 90, 2, false, :x,  :weekly ],
  [ "car_maintenance",           "Entretenir la voiture",              "maintenance", 60, 2, false, :mx, :annually ],
  [ "manage_tradespeople",       "Gérer les artisans",                 "maintenance", 60, 2, false, :m,  :monthly ],
  [ "home_supplies_shopping",    "Acheter les produits ménagers",      "maintenance", 60, 2, false, :mx, :monthly ]
]

tasks_data.each do |key, name, category, minutes, priority, regular, loads, frequency, times|
  mental, execution = load_flags.fetch(loads)
  task = Task.find_or_initialize_by(key: key)
  task.update!(
    name: name, category: category, time_required: minutes, priority: priority, recurring: regular,
    default_mental_load: mental, default_execution_load: execution,
    frequency: frequency, times_per_period: times || 1
  )
end

# Chores created before the catalogue had default loads carry none: they take
# their task's.
Chore.catalogue.where(mental_load: false, execution_load: false).joins(:task).find_each do |chore|
  chore.update_columns(mental_load: chore.task.default_mental_load, execution_load: chore.task.default_execution_load)
end

puts "Done — #{Task.count} tasks in catalogue."
