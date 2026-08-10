class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "noreply@platinumvaultltd.com")
  layout "mailer"
end
