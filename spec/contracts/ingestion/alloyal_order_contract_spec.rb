require "rails_helper"

RSpec.describe Ingestion::AlloyalOrderContract do
  let(:row) do
    {
      "id" => 47986256,
      "number" => "LC216407539",
      "organization_name" => "Magalu",
      "user_name" => "Teste",
      "user_id" => 6066857
    }
  end

  # ADR-0004: o contrato declara o fuso; nunca soma nem subtrai horas.
  it "created_at sem fuso é declarado UTC" do
    contract = described_class.new(created_at: "2026-08-11 20:32:05.949")

    expect(contract.created_at).to eq(Time.utc(2026, 8, 11, 20, 32, 5, 949_000))
    expect(contract.created_at.utc_offset).to eq(0)
  end

  # ADR-0019: sem a afiliadora, o pedido não entra na conciliação.
  it "pedido sem organization_name é recusado" do
    contract = described_class.new(organization_name: nil)

    expect(contract).not_to be_valid
    expect(contract.errors).to be_added(:organization_name, :blank)
  end

  # ADR-0004: dinheiro é BigDecimal, nunca Float.
  it "cashback_value é BigDecimal" do
    contract = described_class.new(cashback_value: "15.00")

    expect(contract.cashback_value).to eq(BigDecimal("15.00"))
    expect(contract.cashback_value).to be_an_instance_of(BigDecimal)
  end

  # ADR-0003: o pedido é guardado como veio; a linha inteira fica no raw_payload.
  it "raw_payload guarda a linha inteira da origem" do
    contract = described_class.from_row(row)

    expect(contract.raw_payload).to eq(row)
  end

  # Campo promovido: sai da linha da origem e ganha campo próprio no contrato.
  it "from_row promove os campos que o contrato conhece" do
    row = { "organization_name" => "Magalu", "user_id" => 6066857 }

    contract = described_class.from_row(row)

    expect(contract.organization_name).to eq("Magalu")
  end

  # Um pedido real traz mais que os campos promovidos; só eles é sinal de dado forjado.
  it "raw_payload só com campos promovidos é recusado" do
    row = { "organization_name" => "Magalu" }

    contract = described_class.from_row(row)

    expect(contract).not_to be_valid
    expect(contract.errors).to be_added(:raw_payload, :only_promoted)
  end

  # BDR-0005: o nome é chave do match com a afiliadora; sem ele o pedido não concilia.
  it "pedido sem user_name é recusado" do
    contract = described_class.new(user_name: nil)

    expect(contract).not_to be_valid
    expect(contract.errors).to be_added(:user_name, :blank)
  end
end
