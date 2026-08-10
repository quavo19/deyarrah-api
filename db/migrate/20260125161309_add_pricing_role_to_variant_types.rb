class AddPricingRoleToVariantTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :variant_types, :pricing_role, :string
    add_index :variant_types, :pricing_role
  end
end
