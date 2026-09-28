# rubocop:disable Rails/CreateTableWithTimestamps -- imutável (ADR-0003): created_at é da fonte
class CreateAlloyalRawOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :alloyal_raw_orders, id: :bigint, default: nil do |t|
      t.string :number, limit: 100, null: false
      t.string :organization_name, limit: 255, null: false
      t.string :user_name, limit: 255, null: false
      t.string :business_name, limit: 255
      t.string :discount_type, limit: 50
      t.string :cashback_type, limit: 50
      t.decimal :discount_value, precision: 10, scale: 2
      t.decimal :cashback_value, precision: 10, scale: 2
      t.timestamptz :created_at
      t.jsonb :raw_payload, null: false
      t.timestamptz :ingested_at, null: false, default: -> { 'now()' }
    end

    add_index :alloyal_raw_orders, :number, unique: true,
              name: 'index_alloyal_raw_orders_on_number'
  end
end
# rubocop:enable Rails/CreateTableWithTimestamps
