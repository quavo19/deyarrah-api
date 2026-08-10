FactoryBot.define do
  factory :role do
    name { "USER" }
    description { "Regular user role" }

    trait :admin do
      name { "ADMIN" }
      description { "Administrator role" }
    end

    trait :super_admin do
      name { "SUPER_ADMIN" }
      description { "Super administrator role" }
    end
  end
end
