puts "Seeding task catalogue..."

Task.destroy_all

tasks_data = [
  # cooking
  { name: "Cook a meal",              time_required: 45, priority: 5, recurring: true,  category: "cooking" },
  { name: "Do the dishes",            time_required: 20, priority: 5, recurring: true,  category: "cooking" },
  { name: "Empty the dishwasher",     time_required: 10, priority: 4, recurring: true,  category: "cooking" },
  { name: "Clean the kitchen",        time_required: 20, priority: 4, recurring: true,  category: "cooking" },
  { name: "Prepare lunchboxes",       time_required: 15, priority: 4, recurring: true,  category: "cooking" },
  { name: "Clean the oven",           time_required: 40, priority: 2, recurring: false, category: "cooking" },
  { name: "Clean the fridge",         time_required: 30, priority: 2, recurring: false, category: "cooking" },

  # groceries
  { name: "Buy groceries",            time_required: 60, priority: 4, recurring: true,  category: "groceries" },
  { name: "Plan weekly meals",        time_required: 20, priority: 3, recurring: true,  category: "groceries" },
  { name: "Manage the shopping list", time_required: 10, priority: 3, recurring: true,  category: "groceries" },
  { name: "Order groceries online",   time_required: 20, priority: 3, recurring: false, category: "groceries" },

  # cleaning
  { name: "Vacuum",                   time_required: 30, priority: 3, recurring: true,  category: "cleaning" },
  { name: "Mop the floors",           time_required: 40, priority: 3, recurring: true,  category: "cleaning" },
  { name: "Dust",                     time_required: 20, priority: 2, recurring: true,  category: "cleaning" },
  { name: "Clean the toilets",        time_required: 20, priority: 3, recurring: true,  category: "cleaning" },
  { name: "Clean the bathroom",       time_required: 30, priority: 3, recurring: true,  category: "cleaning" },
  { name: "Empty the bins",           time_required: 10, priority: 4, recurring: true,  category: "cleaning" },
  { name: "Take out recycling",       time_required: 10, priority: 3, recurring: true,  category: "cleaning" },
  { name: "Clean the windows",        time_required: 60, priority: 1, recurring: false, category: "cleaning" },
  { name: "Tidy the living room",     time_required: 20, priority: 3, recurring: true,  category: "cleaning" },
  { name: "Make the beds",            time_required: 10, priority: 3, recurring: true,  category: "cleaning" },
  { name: "Change the bed sheets",    time_required: 20, priority: 2, recurring: true,  category: "cleaning" },

  # laundry
  { name: "Start a wash",             time_required: 10, priority: 3, recurring: true,  category: "laundry" },
  { name: "Hang the laundry",         time_required: 15, priority: 3, recurring: true,  category: "laundry" },
  { name: "Fold the laundry",         time_required: 20, priority: 3, recurring: true,  category: "laundry" },
  { name: "Iron clothes",             time_required: 45, priority: 2, recurring: true,  category: "laundry" },
  { name: "Put away laundry",         time_required: 15, priority: 3, recurring: true,  category: "laundry" },

  # childcare
  { name: "Drop kids off at school",  time_required: 30, priority: 5, recurring: true,  category: "childcare" },
  { name: "Pick kids up from school", time_required: 30, priority: 5, recurring: true,  category: "childcare" },
  { name: "Help with homework",       time_required: 45, priority: 4, recurring: true,  category: "childcare" },
  { name: "Bathe the kids",           time_required: 30, priority: 4, recurring: true,  category: "childcare" },
  { name: "Pack school bags",         time_required: 10, priority: 4, recurring: true,  category: "childcare" },
  { name: "Manage extracurriculars",  time_required: 30, priority: 3, recurring: true,  category: "childcare" },
  { name: "Paediatrician appointment",time_required: 60, priority: 3, recurring: false, category: "childcare" },
  { name: "Buy school supplies",      time_required: 60, priority: 2, recurring: false, category: "childcare" },

  # admin
  { name: "Pay bills",                time_required: 20, priority: 4, recurring: true,  category: "admin" },
  { name: "Manage insurance",         time_required: 30, priority: 2, recurring: false, category: "admin" },
  { name: "File taxes",               time_required: 120, priority: 3, recurring: false, category: "admin" },
  { name: "Book medical appointments",time_required: 15, priority: 3, recurring: false, category: "admin" },
  { name: "Handle health reimbursements", time_required: 15, priority: 2, recurring: true, category: "admin" },
  { name: "Renew subscriptions",      time_required: 20, priority: 2, recurring: false, category: "admin" },
  { name: "Manage bank and budget",   time_required: 30, priority: 3, recurring: true,  category: "admin" },
  { name: "Plan holidays",            time_required: 120, priority: 2, recurring: false, category: "admin" },

  # maintenance
  { name: "DIY / minor repairs",      time_required: 60, priority: 2, recurring: false, category: "maintenance" },
  { name: "Water the plants",         time_required: 10, priority: 3, recurring: true,  category: "maintenance" },
  { name: "Garden maintenance",       time_required: 90, priority: 2, recurring: true,  category: "maintenance" },
  { name: "Car maintenance",          time_required: 60, priority: 2, recurring: false, category: "maintenance" },
  { name: "Manage tradespeople",      time_required: 60, priority: 2, recurring: false, category: "maintenance" },
  { name: "Home supplies shopping",   time_required: 60, priority: 2, recurring: false, category: "maintenance" }
]

tasks_data.each do |attrs|
  Task.create!(attrs)
end

puts "Done — #{Task.count} tasks in catalogue."
