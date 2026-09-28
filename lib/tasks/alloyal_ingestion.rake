namespace :ingestion do
  desc "Ingere os pedidos Magalu do App Alloyal"
  task alloyal: :environment do
    Ingestion::Alloyal::Ingest.run
  end
end
