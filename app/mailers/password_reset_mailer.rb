class PasswordResetMailer < ApplicationMailer
  def reset_password_email(user, reset_token)
    @user = user
    @reset_token = reset_token
    @frontend_url = ENV.fetch("FRONTEND_URL", "https://platinumvaultltd.com")
    @reset_url = "#{@frontend_url}/reset-password?token=#{@reset_token}"

    mail(
      to: @user.email,
      subject: "Reset Your Password"
    )
  end
end
