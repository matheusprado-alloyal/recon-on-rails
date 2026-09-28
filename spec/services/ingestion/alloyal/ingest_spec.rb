require "rails_helper"

RSpec.describe Ingestion::Alloyal::Ingest do
  let(:row) do
    {
      "id" => 47986256,
      "number" => "LC216407539",
      "organization_name" => "Magalu",
      "user_name" => "Teste",
      "user_id" => 6066857
    }
  end

  # ADR-0003: imutável; reingerir o mesmo pedido não duplica nem atualiza.
  it "gravar o mesmo pedido duas vezes grava uma vez só" do
    contract = Ingestion::AlloyalOrderContract.from_row(row)

    expect(described_class.save_raw_orders([ contract ])).to eq(1)
    expect(described_class.save_raw_orders([ contract ])).to eq(0)
    expect(Ingestion::AlloyalRawOrder.where(number: "LC216407539").count).to eq(1)
  end

  # ADR-0003: o id é o da Alloyal, nunca gerado pelo banco.
  it "o id gravado é o da Alloyal" do
    contract = Ingestion::AlloyalOrderContract.from_row(row)

    described_class.save_raw_orders([ contract ])

    expect(Ingestion::AlloyalRawOrder.find_by(number: "LC216407539").id).to eq(47986256)
  end

  # BDR-0005, ADR-0019: contrato inválido é registrado no log e não segue para a gravação.
  it "contrato inválido é registrado no log e fica de fora" do
    contract = Ingestion::AlloyalOrderContract.from_row(row.merge("user_name" => nil))

    expect(Rails.logger).to receive(:error).with(/LC216407539/)

    expect(described_class.reject_invalid([ contract ])).to be_empty
  end

  # Sem alarme falso: contrato válido segue para a gravação, sem log.
  it "contrato válido segue para a gravação sem log" do
    contract = Ingestion::AlloyalOrderContract.from_row(row)

    expect(Rails.logger).not_to receive(:error)

    expect(described_class.reject_invalid([ contract ])).to eq([ contract ])
  end

  # ADR-0003: os campos promovidos ganham coluna própria.
  it "grava os campos promovidos nas suas colunas" do
    promoted = {
      "discount_type" => "percent",
      "discount_value" => "72.00",
      "cashback_type" => "percent",
      "cashback_value" => "15.00",
      "business_name" => "Elevita",
      "created_at" => "2026-08-11 20:32:05.949"
    }
    contract = Ingestion::AlloyalOrderContract.from_row(row.merge(promoted))

    described_class.save_raw_orders([ contract ])

    expect(Ingestion::AlloyalRawOrder.find_by(number: "LC216407539")).to have_attributes(
      discount_type: "percent",
      business_name: "Elevita",
      discount_value: BigDecimal("72.00"),
      cashback_type: "percent",
      cashback_value: BigDecimal("15.00"),
      created_at: Time.utc(2026, 8, 11, 20, 32, 5, 949_000)
    )
  end

  # ADR-0011: a origem só recebe um teste de disponibilidade, nunca de regra.
  it "a origem do App Alloyal responde" do
    connection = PG.connect(ENV.fetch("ALLOYAL_SOURCE_DB_URL"))

    expect(connection.exec("SELECT version()").getvalue(0, 0)).to start_with("PostgreSQL")
  ensure
    connection&.close
  end
end
