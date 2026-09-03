# Demo data. Idempotent: keyed on usernames.

admin = User.find_or_create_by!(username: "admin") do |u|
  u.name = "Admin"
  u.password = "password123"
end

alice = User.find_or_create_by!(username: "alice") do |u|
  u.name = "Alice Nguyen"
  u.password = "password123"
end

bob = User.find_or_create_by!(username: "bob") do |u|
  u.name = "Bob Marsh"
  u.password = "password123"
end

[alice, bob].each do |user|
  next if user.profile

  profile = Profile.create!(user: user)

  questions = [
    { text: "How are you feeling today?", question_type: "text", config: {}, position: 1 },
    { text: "Preferred topic", question_type: "select", config: { "options" => ["Family", "Work", "Hobbies", "Travel"] }, position: 2 },
    { text: "Length of chat", question_type: "radio", config: { "options" => ["Short", "Medium", "Long"] }, position: 3 }
  ]
  questions.each { |attrs| profile.questions.create!(attrs) }

  queue = profile.current_queue

  2.times do |i|
    interaction = queue.interactions.create!(name: "Catch-up ##{i + 1}")
    profile.questions.ordered.each do |question|
      interaction.answers.create!(question: question, value: question.options.first || "Doing well, thanks!")
    end
  end
end

puts "Seeded #{User.count} users, #{Profile.count} profiles, #{Interaction.count} interactions."
puts "Log in with admin / password123 (or alice, bob)."
