class OtpMailer < ApplicationMailer
  def send_otp(user, otp_code)
    @user = user
    @otp_code = otp_code
    @otp_expires_in = "#{User::OTP_INTERVAL / 60} minutes"
    mail(
      to: @user.email,
      subject: "Your OTP Code"
    )
  end
end
