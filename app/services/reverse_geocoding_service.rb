class ReverseGeocodingService
  class GeocodingError < StandardError; end

  def initialize(location_record)
    @location_record = location_record
  end

  def perform
    latitude = @location_record.latitude
    longitude = @location_record.longitude

    unless latitude.present? && longitude.present?
      return
    end

    begin
      
      # Perform reverse geocoding using Geocoder
      result = Geocoder.search([latitude, longitude]).first

      if result
        update_location_metadata(result)
      else
      end
    rescue StandardError => e
      # Log error but don't raise - geocoding failures should not break requests
 
    end
  end

  private

  def update_location_metadata(result)
    country_value = extract_country(result)
    region_value = extract_region(result)
    city_value = extract_city(result)
    county_value = extract_county(result)
    
    # Extract the full address JSON from the result
    address_data = result.data.is_a?(Hash) ? result.data["address"] : nil

    
    # Reload location record to ensure we have the latest version
    @location_record.reload
    
    # Prepare update hash
    update_hash = {
      country: country_value,
      region: region_value,
      city: city_value,
      county: county_value,
      address: address_data || {},
      updated_at: Time.current
    }
    
    Rails.logger.info("Updating #{@location_record.class.name} with: #{update_hash.inspect}")
    
    # Use update_all to directly update the database
    model_class = @location_record.class
    rows_updated = model_class.where(id: @location_record.id).update_all(update_hash)
    
    Rails.logger.info("Database rows updated: #{rows_updated}")
    
    if rows_updated == 0
      Rails.logger.error("WARNING: No rows were updated for #{@location_record.class.name} #{@location_record.id}")
    end
    
    # Reload to verify
    @location_record.reload
    Rails.logger.info("#{@location_record.class.name} metadata after update - Country: #{@location_record.country.inspect}, Region: #{@location_record.region.inspect}, City: #{@location_record.city.inspect}, County: #{@location_record.county.inspect}, Address: #{@location_record.address.inspect}")
  rescue StandardError => e
    Rails.logger.error("Failed to update #{@location_record.class.name} metadata for #{@location_record.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Don't re-raise - let it fail silently so the warehouse creation still succeeds
  end

  def extract_country(result)
    # Try multiple ways to get country
    country = result.country || result.country_code
    # Fallback to address components if available
    if country.blank? && result.respond_to?(:address_components)
      country = result.address_components&.find { |c| c["types"]&.include?("country") }&.dig("long_name")
    end
    # Fallback to raw data
    if country.blank? && result.data.is_a?(Hash)
      country = result.data["address"]&.dig("country") || result.data["address"]&.dig("country_code")
    end
    country.presence
  end

  def extract_region(result)
    # Try different field names for region/state
    region = result.state || result.province
    region ||= result.administrative_area_level_1 if result.respond_to?(:administrative_area_level_1)
    # Fallback to address components
    if region.blank? && result.respond_to?(:address_components)
      region = result.address_components&.find { |c| c["types"]&.include?("administrative_area_level_1") }&.dig("long_name")
    end
    # Fallback to raw data (Nominatim uses "state" or "region" in address)
    if region.blank? && result.data.is_a?(Hash)
      region = result.data["address"]&.dig("state") || result.data["address"]&.dig("region")
    end
    region.presence
  end

  def extract_city(result)
    # Try different field names for city
    city = result.city || result.town || result.village
    city ||= result.locality if result.respond_to?(:locality)
    # Fallback to address components
    if city.blank? && result.respond_to?(:address_components)
      city = result.address_components&.find { |c| 
        ["locality", "administrative_area_level_2", "sublocality"].any? { |type| c["types"]&.include?(type) }
      }&.dig("long_name")
    end
    # Fallback to raw data (Nominatim uses various city field names)
    if city.blank? && result.data.is_a?(Hash)
      address = result.data["address"]
      city = address&.dig("city") || address&.dig("town") || address&.dig("village") || 
             address&.dig("municipality") || address&.dig("locality") ||
             address&.dig("suburb") || address&.dig("neighbourhood")
    end
    city.presence
  end

  def extract_county(result)
    # Try to get county from raw data (Nominatim uses "county" in address)
    county = nil
    if result.data.is_a?(Hash)
      county = result.data["address"]&.dig("county")
    end
    county.presence
  end
end
