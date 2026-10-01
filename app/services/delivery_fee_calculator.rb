class DeliveryFeeCalculator
  class DeliveryUnavailableError < StandardError; end

  attr_reader :fulfillment, :order, :zone

  def initialize(fulfillment)
    @fulfillment = fulfillment
    @order = fulfillment.order
    @zone = resolve_zone!
  end

  def calculate
    bulk_fee + high_value_fee
  end

  private

  def resolve_zone!
    address = order.customer_address
    zone = DeliveryZone.resolve(
      region: address&.region,
      city: address&.city,
      town: address&.town,
      market_name: address&.market_name
    )
    return zone if zone

    raise DeliveryUnavailableError, "Delivery is not available for this destination yet"
  end

  def bulk_fee
    total_weight = fulfillment.order_items.includes(variant_stock: :product).sum do |item|
      product = item.variant_stock&.product
      next BigDecimal("0") unless product&.shipping_bulk?

      product.estimated_shipping_weight_kg.to_d * item.quantity.to_i
    end
    return BigDecimal("0") unless total_weight.positive?

    tier = DeliveryWeightTier.match(
      pricing_zone: zone.pricing_zone,
      weight_kg: total_weight
    )
    raise DeliveryUnavailableError, "No bulk delivery tier is configured for #{total_weight.to_f}kg" unless tier

    tier.fee
  end

  def high_value_fee
    grouped_quantities.sum do |shipping_category, quantity|
      rate = DeliveryHighValueRate.for(
        pricing_zone: zone.pricing_zone,
        shipping_category: shipping_category
      )
      raise DeliveryUnavailableError, "No high-value delivery rate is configured for #{shipping_category}" unless rate

      category_fee(rate.fee, quantity)
    end
  end

  def grouped_quantities
    fulfillment.order_items.includes(variant_stock: :product).each_with_object(Hash.new(0)) do |item, totals|
      product = item.variant_stock&.product
      next unless product&.shipping_high_value?

      totals[product.shipping_category] += item.quantity.to_i
    end
  end

  def category_fee(base_fee, quantity)
    return BigDecimal("0") if quantity <= 0

    base_fee + (base_fee * DeliverySetting.high_value_additional_unit_multiplier * (quantity - 1))
  end
end
