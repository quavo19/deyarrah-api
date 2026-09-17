FactoryBot.define do
  factory :support_request do
    topic { "general_support" }
    status { "pending" }
    message { "I need help with my order." }
    guest_full_name { "Ama Mensah" }
    guest_email { Faker::Internet.email }
    guest_phone { "+233555000000" }
  end
end
