FactoryBot.define do
  factory :role do
    name { "USER" }
    description { "Regular user role" }

    trait :admin do
      name { "ADMIN" }
      description { "Administrator role" }
    end

    trait :customer do
      name { "CUSTOMER" }
      description { "Default user role with basic access" }
    end

    trait :affiliate do
      name { "AFFILIATE" }
      description { "Affiliate marketer role" }
    end

    trait :super_admin do
      name { "SUPER_ADMIN" }
      description { "Super administrator role" }
    end
  end
end
