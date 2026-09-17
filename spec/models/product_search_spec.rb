require "rails_helper"

RSpec.describe Product, type: :model do
  describe ".matching_search" do
    it "matches hidden search keywords without requiring visible product text" do
      product = create(:product, name: "Galaxy Deal", search_keywords: [ "iphone", "cell phone" ])
      create(:product, name: "Rice Bag", search_keywords: [ "grain" ])

      expect(described_class.matching_search("cell phone")).to contain_exactly(product)
    end
  end
end
