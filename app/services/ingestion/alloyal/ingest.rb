module Ingestion
  module Alloyal
    # Ingestão dos pedidos do App Alloyal: lê a origem, confere e grava.
    module Ingest
      # ADR-0003: imutável; pedido já gravado é ignorado, nunca atualizado.
      def self.save_raw_orders(contracts)
        rows = contracts.map { |contract| contract.attributes }
        Ingestion::AlloyalRawOrder.insert_all(rows, unique_by: :number).length
      end

      # BDR-0005, ADR-0019: contrato inválido é registrado e não segue para a gravação.
      def self.reject_invalid(contracts)
        accepted, rejected = contracts.partition { |contract| contract.valid? }

        rejected.each do |contract|
          reasons = contract.errors.full_messages.join(", ")
          Rails.logger.error("Pedido Alloyal recusado: number=#{contract.number} (#{reasons})")
        end

        accepted
      end

      # BDR-0006: todos os pedidos da Magalu, sem amostra.
      def self.fetch_source_rows
        connection = PG.connect(ENV.fetch("ALLOYAL_SOURCE_DB_URL"))
        connection.exec("SELECT * FROM orders WHERE organization_name = 'Magalu'").to_a
      ensure
        connection&.close
      end

      def self.run
        contracts = fetch_source_rows.map { |row| Ingestion::AlloyalOrderContract.from_row(row) }
        inserted = save_raw_orders(reject_invalid(contracts))
        Rails.logger.info("Ingestão Alloyal: #{contracts.size} lidos, #{inserted} novos")
      end
    end
  end
end
