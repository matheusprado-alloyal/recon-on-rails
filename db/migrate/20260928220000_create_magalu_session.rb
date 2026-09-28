# rubocop:disable Rails/CreateTableWithTimestamps -- singleton (ADR-0006): captured_at é o login
class CreateMagaluSession < ActiveRecord::Migration[8.1]
  def change
    # ADR-0006: no máximo uma linha; o id é sempre 1, sem sequência.
    create_table :magalu_session, id: :integer, default: 1 do |t|
      t.text :session_id, null: false
      t.text :user_agent, null: false
      t.timestamptz :expires_at, null: false
      t.timestamptz :captured_at, null: false

      t.check_constraint "id = 1", name: "magalu_session_singleton"
    end
  end
end
# rubocop:enable Rails/CreateTableWithTimestamps
