FactoryBot.define do
  factory :permission do
    name { Faker::Lorem.word.upcase }
  end
end
