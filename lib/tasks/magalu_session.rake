namespace :ingestion do
  desc "Garante a sessão Magalu; com [force], renova mesmo com sessão válida"
  task :magalu_session, [ :mode ] => :environment do |_task, args|
    session = Ingestion::Magalu::Session
    credentials = args[:mode] == "force" ? session.renew_credentials : session.get_credentials

    # O sessionid é segredo: só o começo, para conferência.
    puts "Sessão Magalu OK: sessionid=#{credentials.session_id[0, 15]}..."
  end
end
