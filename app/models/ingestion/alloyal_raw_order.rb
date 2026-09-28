module Ingestion
  # Imutável: pedido já gravado é ignorado, nunca atualizado.
  class AlloyalRawOrder < ApplicationRecord
    self.record_timestamps = false
  end
end
