require "rails_helper"

RSpec.describe Product, type: :model do
  it "allows zero affiliate commission" do
    product = build(:product, affiliate_commission_amount: 0)

    expect(product).to be_valid
  end

  it "does not allow negative affiliate commission" do
    product = build(:product, affiliate_commission_amount: -1)

    expect(product).not_to be_valid
    expect(product.errors[:affiliate_commission_amount]).to be_present
  end
end
