module Ingestion
  # Banco de origem do App Alloyal: somente leitura, nunca migrado por nós.
  class AlloyalSourceRecord < ActiveRecord::Base
    self.abstract_class = true

    connects_to database: { reading: :alloyal_source }
  end
end