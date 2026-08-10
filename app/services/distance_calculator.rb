class DistanceCalculator
  EARTH_RADIUS_KM = 6371.0
  ROAD_DISTANCE_MULTIPLIER = 1.225

  # Calculate distance between two coordinates using Haversine formula
  # with road distance multiplier
  #
  # @param lat1 [Float] Latitude of first point
  # @param lon1 [Float] Longitude of first point
  # @param lat2 [Float] Latitude of second point
  # @param lon2 [Float] Longitude of second point
  # @return [Float] Distance in kilometers
  def self.calculate_distance(lat1, lon1, lat2, lon2)
    return 0.0 unless lat1.present? && lon1.present? && lat2.present? && lon2.present?

    # Convert degrees to radians
    d_lat = (lat2 - lat1) * Math::PI / 180.0
    d_lon = (lon2 - lon1) * Math::PI / 180.0

    # Haversine formula
    a = Math.sin(d_lat / 2.0) * Math.sin(d_lat / 2.0) +
        Math.cos(lat1 * Math::PI / 180.0) * Math.cos(lat2 * Math::PI / 180.0) *
        Math.sin(d_lon / 2.0) * Math.sin(d_lon / 2.0)

    c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))

    # Straight line distance
    straight_line_distance = EARTH_RADIUS_KM * c

    # Apply road distance multiplier
    straight_line_distance * ROAD_DISTANCE_MULTIPLIER
  end

  # Calculate delivery fee based on distance and rate per km
  #
  # @param distance [Float] Distance in kilometers
  # @param delivery_rate_per_km [Float] Rate per kilometer
  # @return [Float] Delivery fee amount
  def self.calculate_delivery_fee(distance, delivery_rate_per_km)
    return 0.0 unless distance.present? && delivery_rate_per_km.present?
    return 0.0 if distance <= 0 || delivery_rate_per_km <= 0

    (distance * delivery_rate_per_km).round(2)
  end
end
