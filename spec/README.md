# RSpec Test Suite

This directory contains comprehensive unit tests for all API endpoints using RSpec.

## Setup

1. Install the required gems:
   ```bash
   bundle install
   ```

2. Set up the test database:
   ```bash
   rails db:test:prepare
   ```

## Running Tests

Run all tests:
```bash
bundle exec rspec
```

Run a specific test file:
```bash
bundle exec rspec spec/requests/api/v1/auth/sessions_spec.rb
```

Run tests with documentation format:
```bash
bundle exec rspec --format documentation
```

## Test Coverage

The test suite covers all API endpoints:

### Authentication Endpoints
- `POST /api/v1/auth/login` - User login (with OTP support)
- `DELETE /api/v1/auth/logout` - User logout
- `POST /api/v1/auth/signup` - User registration
- `POST /api/v1/auth/password` - Password reset request
- `PUT /api/v1/auth/password` - Password reset confirmation

### User Management Endpoints
- `GET /api/v1/users/profile` - Get user profile
- `PUT /api/v1/users/profile` - Update user profile
- `POST /api/v1/users/otp/verify` - Verify OTP code
- `POST /api/v1/users/otp/toggle` - Enable/disable OTP

### Admin Endpoints
- `GET /api/v1/roles` - List all roles
- `PUT /api/v1/roles/:id` - Update role
- `GET /api/v1/permissions` - List all permissions
- `POST /api/v1/users/:id/role/:role_id` - Assign role to user
- `POST /api/v1/users/:id/permissions` - Assign permissions to user

## Test Structure

Tests are organized by controller in `spec/requests/api/v1/`:
- `auth/` - Authentication controllers
- `users/` - User management controllers
- `roles_spec.rb` - Roles controller
- `permissions_spec.rb` - Permissions controller
- `users_spec.rb` - Admin user management

## Factories

Factories are defined in `spec/factories/`:
- `users.rb` - User factory with traits for admin, blocked, OTP-enabled users
- `roles.rb` - Role factory with traits for different role types
- `permissions.rb` - Permission factory

## Helpers

Test helpers are in `spec/support/`:
- `factory_bot.rb` - FactoryBot configuration
- `devise.rb` - Devise test helpers
- `json_helpers.rb` - JSON response parsing helpers
