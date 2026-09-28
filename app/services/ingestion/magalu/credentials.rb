module Ingestion
  module Magalu
    # ADR-0007: sessionid e user-agent andam sempre juntos; o scraper nunca usa um sem o outro.
    Credentials = Data.define(:session_id, :user_agent)
  end
end
