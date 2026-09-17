require "aws-sdk-s3"

if ENV["R2_ACCOUNT_ID"].present?
  R2_CLIENT = Aws::S3::Client.new(
    access_key_id: ENV["R2_ACCESS_KEY_ID"],
    secret_access_key: ENV["R2_SECRET_ACCESS_KEY"],
    endpoint: "https://#{ENV['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com",
    region: "auto",
    force_path_style: true
  )

  R2_PRESIGNER = Aws::S3::Presigner.new(client: R2_CLIENT)
end
