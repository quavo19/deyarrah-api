FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "password123" }
    password_confirmation { "password123" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    otp_enabled { false }
    otp_secret { nil }
    blocked { false }

    role do
      Role.find_by(name: "CUSTOMER") || create(:role, :customer)
    end

    trait :with_otp do
      otp_enabled { true }
      otp_secret { ROTP::Base32.random }
    end

    trait :blocked do
      blocked { true }
    end

    trait :admin do
      role do
        Role.find_by(name: "ADMIN") || create(:role, :admin)
      end
    end

    trait :affiliate do
      role do
        Role.find_by(name: "AFFILIATE") || create(:role, :affiliate)
      end
    end

    trait :super_admin do
      role do
        Role.find_by(name: "SUPER_ADMIN") || create(:role, :super_admin)
      end
    end
  end
end
