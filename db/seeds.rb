# Create Roles
roles_data = [
  { name: 'CUSTOMER', description: 'Default user role with basic access' },
  { name: 'STAFF', description: 'Staff member with limited administrative access' },
  { name: 'ADMIN', description: 'Administrator with full system access' },
  { name: 'SUPER_ADMIN', description: 'Super administrator with complete system control' }
]

roles_data.each do |role_data|
  Role.find_or_create_by(name: role_data[:name]) do |role|
    role.description = role_data[:description]
  end
end

# Create Permissions
permissions_data = [
  'CAN_PAY_ON_DELIVERY'
]

permissions_data.each do |permission_name|
  Permission.find_or_create_by(name: permission_name)
end

puts "Seeded #{Role.count} roles and #{Permission.count} permissions"
