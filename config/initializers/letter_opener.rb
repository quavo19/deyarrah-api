# Letter Opener configuration
# This gem opens emails in your browser instead of sending them
# Perfect for development environment

if Rails.env.development?
  LetterOpener.configure do |config|
    # Location where letter_opener will open emails
    # Default is tmp/letter_opener
    config.location = Rails.root.join("tmp", "letter_opener")
  end
end
