module Ingestion
  # Contrato da fonte App Alloyal: como ela fala, não o que fazemos com o dado.
  class AlloyalOrderContract
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :created_at, :datetime
    attribute :organization_name, :string
    attribute :cashback_value, :decimal
    attribute :raw_payload
    attribute :number, :string
    attribute :user_name, :string
    attribute :id, :integer
    attribute :business_name, :string
    attribute :discount_type, :string
    attribute :discount_value, :decimal
    attribute :cashback_type, :string

    # BDR-0005: o nome é chave do match com a afiliadora; sem ele o pedido não concilia.
    validates :user_name, presence: true

    # ADR-0019: sem a afiliadora, o pedido não entra na conciliação.
    validates :organization_name, presence: true

    # Um pedido real traz mais que os campos promovidos; só eles é sinal de dado forjado.
    validate :raw_payload_has_more_than_promoted

    # Premissa não confirmada na origem: created_at chega sem fuso e está em UTC.
    def created_at=(value)
      value = ActiveSupport::TimeZone["UTC"].parse(value) if value.is_a?(String)
      super(value)
    end

    # CGI: converte o hash de entrada em um contrato.
    def self.from_row(row)
      new(row.slice(*attribute_names).merge("raw_payload" => row))
    end

    private

    # Validação: o raw_payload deve conter mais campos do que os promovidos.
    def raw_payload_has_more_than_promoted
      extra = raw_payload.to_h.keys - self.class.attribute_names
      errors.add(:raw_payload, :only_promoted,
message: "traz só os campos promovidos") if extra.empty?
    end
  end
end
