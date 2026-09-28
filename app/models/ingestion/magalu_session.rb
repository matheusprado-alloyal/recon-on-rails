module Ingestion
  # Singleton (ADR-0006): no máximo uma linha, id = 1, gravada por cima a cada login.
  class MagaluSession < ApplicationRecord
    # O Rails derivaria o plural (magalu_sessions); a tabela é singular por ser singleton.
    self.table_name = "magalu_session"
  end
end
