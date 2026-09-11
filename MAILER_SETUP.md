# Mailer Setup Guide

This application uses **Letter Opener** for development and SMTP for production.

## Development Setup (Letter Opener)

### What is Letter Opener?

Letter Opener opens emails in your browser instead of actually sending them. Perfect for development!

### How it Works

1. When an email is sent in development, it opens automatically in your browser
2. Emails are stored in `tmp/letter_opener/` directory
3. No actual email delivery happens

### Configuration

- **Gem**: `letter_opener` (already added to Gemfile)
- **Location**: `config/environments/development.rb`
- **Initializer**: `config/initializers/letter_opener.rb`

### Usage

Just send emails normally:

```ruby
OtpMailer.send_otp(user, otp_code).deliver_now
```

The email will automatically open in your browser!

## Production Setup (SMTP)

### Configuration Steps

1. **Add SMTP credentials to Rails credentials:**

   ```bash
   rails credentials:edit
   ```

2. **Add your SMTP settings:**

   ```yaml
   smtp:
     user_name: your_smtp_username
     password: your_smtp_password
     address: smtp.local
     port: 587
     authentication: plain
     domain: yourdomain.local
   ```

3. **Update production environment** (`config/environments/production.rb`):
   ```ruby
   config.action_mailer.delivery_method = :smtp
   config.action_mailer.smtp_settings = {
     user_name: Rails.application.credentials.dig(:smtp, :user_name),
     password: Rails.application.credentials.dig(:smtp, :password),
     address: Rails.application.credentials.dig(:smtp, :address),
     port: Rails.application.credentials.dig(:smtp, :port) || 587,
     authentication: :plain,
     domain: Rails.application.credentials.dig(:smtp, :domain)
   }
   ```

### Popular SMTP Providers

#### Gmail

```yaml
smtp:
  address: smtp.gmail.local
  port: 587
  authentication: plain
  domain: gmail.local
```

#### SendGrid

```yaml
smtp:
  address: smtp.sendgrid.net
  port: 587
  authentication: plain
  domain: yourdomain.local
```

#### Mailgun

```yaml
smtp:
  address: smtp.mailgun.org
  port: 587
  authentication: plain
  domain: yourdomain.local
```

## Mailer Configuration

### Application Mailer

Located at: `app/mailers/application_mailer.rb`

Default sender email is configured via environment variable:

```ruby
default from: ENV.fetch("MAILER_FROM", "noreply@localhost")
```

Set in your environment:

```bash
export MAILER_FROM="noreply@localhost"
```

### Creating New Mailers

1. **Generate a mailer:**

   ```bash
   rails generate mailer NotificationMailer
   ```

2. **Add methods:**

   ```ruby
   class NotificationMailer < ApplicationMailer
     def welcome_email(user)
       @user = user
       mail(to: @user.email, subject: "Welcome!")
     end
   end
   ```

3. **Create views:**

   - `app/views/notification_mailer/welcome_email.html.erb`
   - `app/views/notification_mailer/welcome_email.text.erb`

4. **Send emails:**
   ```ruby
   NotificationMailer.welcome_email(user).deliver_now  # Synchronous
   NotificationMailer.welcome_email(user).deliver_later # Async (requires Active Job)
   ```

## Current Mailers

### OtpMailer

- **Location**: `app/mailers/otp_mailer.rb`
- **Method**: `send_otp(user, otp_code)`
- **Views**:
  - `app/views/otp_mailer/send_otp.html.erb`
  - `app/views/otp_mailer/send_otp.text.erb`

**Usage:**

```ruby
OtpMailer.send_otp(user, otp_code).deliver_now
```

## Testing Emails

### In Development

- Emails automatically open in browser
- Check `tmp/letter_opener/` for stored emails

### In Test Environment

- Emails are stored in `ActionMailer::Base.deliveries`
- Test with:
  ```ruby
  expect(ActionMailer::Base.deliveries.count).to eq(1)
  expect(ActionMailer::Base.deliveries.last.to).to eq(user.email)
  ```

```bash
# Development (optional)
MAILER_FROM=noreply@localhost

# Production (required)
MAILER_FROM=noreply@localhost
SMTP_USER_NAME=your_smtp_username
SMTP_PASSWORD=your_smtp_password
SMTP_ADDRESS=smtp.local
SMTP_PORT=587
SMTP_DOMAIN=yourdomain.local
```
