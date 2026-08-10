module JsonHelpers
  def json_response
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include JsonHelpers, type: :request
end
