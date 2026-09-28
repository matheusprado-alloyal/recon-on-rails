require "rails_helper"

RSpec.describe Ingestion::Magalu::Session do
  # ADR-0007: valor observado num login real.
  let(:user_agent) do
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) " \
      "Chrome/153.0.0.0 Safari/537.36"
  end
  let(:captured) do
    {
      session_id: "sessionid-novo",
      user_agent: user_agent,
      expires_at: 48.hours.from_now,
      captured_at: Time.current
    }
  end

  def store_session(expires_at:, stored_user_agent: user_agent)
    Ingestion::MagaluSession.create!(
      id: 1,
      session_id: "sessionid-guardado",
      user_agent: stored_user_agent,
      expires_at: expires_at,
      captured_at: 1.day.ago
    )
  end

  def stub_env(values)
    stub_const("ENV", ENV.to_h.except("MAGALU_EMAIL", "MAGALU_SENHA").merge(values))
  end

  describe ".get_credentials" do
    # ADR-0006: com sessão válida guardada, nenhum navegador abre.
    it "sessão válida guardada é devolvida sem login" do
      store_session(expires_at: 1.day.from_now)

      expect(described_class).not_to receive(:login_with_retry)

      expect(described_class.get_credentials).to eq(
        Ingestion::Magalu::Credentials.new(session_id: "sessionid-guardado", user_agent: user_agent)
      )
    end

    it "sem sessão guardada, faz login e grava a sessão capturada" do
      allow(described_class).to receive(:login_with_retry).and_return(captured)

      expect(described_class.get_credentials.session_id).to eq("sessionid-novo")
      expect(Ingestion::MagaluSession.find(1).session_id).to eq("sessionid-novo")
    end

    it "sessão vencida é substituída por um login novo" do
      store_session(expires_at: 1.minute.ago)
      allow(described_class).to receive(:login_with_retry).and_return(captured)

      expect(described_class.get_credentials.session_id).to eq("sessionid-novo")
      expect(Ingestion::MagaluSession.find(1).session_id).to eq("sessionid-novo")
    end
  end

  describe ".renew_credentials" do
    # ADR-0006: para quando a API responde 401, mesmo com sessão ainda no prazo.
    it "renovação forçada substitui a sessão válida guardada" do
      store_session(expires_at: 1.day.from_now)
      allow(described_class).to receive(:login_with_retry).and_return(captured)

      expect(described_class.renew_credentials.session_id).to eq("sessionid-novo")
      expect(Ingestion::MagaluSession.find(1).session_id).to eq("sessionid-novo")
    end
  end

  describe ".save_session" do
    # ADR-0006: singleton; gravar de novo substitui, nunca acumula.
    it "duas capturas seguidas deixam uma sessão só, a mais recente" do
      described_class.save_session(captured.merge(session_id: "primeira"))
      described_class.save_session(captured.merge(session_id: "segunda"))

      expect(Ingestion::MagaluSession.count).to eq(1)
      expect(Ingestion::MagaluSession.find(1).session_id).to eq("segunda")
    end

    it "sessão gravada tem sessionid, user-agent, validade e momento do login" do
      expires_at = Time.utc(2026, 9, 30, 21, 0, 0)
      captured_at = Time.utc(2026, 9, 28, 21, 0, 0)

      described_class.save_session(
        captured.merge(expires_at: expires_at, captured_at: captured_at)
      )

      expect(Ingestion::MagaluSession.find(1)).to have_attributes(
        session_id: "sessionid-novo",
        user_agent: user_agent,
        expires_at: expires_at,
        captured_at: captured_at
      )
    end

    # ADR-0007: troca de versão do Chrome é aviso, não bloqueio.
    it "troca de Chrome 153 para 154 gera alerta de atualização da imagem e grava" do
      store_session(expires_at: 1.day.from_now)
      novo_user_agent = user_agent.sub("Chrome/153", "Chrome/154")

      expect(Rails.logger).to receive(:warn).with(/Chrome 153.*Chrome 154/)

      described_class.save_session(captured.merge(user_agent: novo_user_agent))
      expect(Ingestion::MagaluSession.find(1).user_agent).to eq(novo_user_agent)
    end

    it "mesma versão do Chrome não gera alerta de atualização" do
      store_session(expires_at: 1.day.from_now)

      expect(Rails.logger).not_to receive(:warn)

      described_class.save_session(captured)
    end
  end

  describe ".headful_user_agent" do
    # ADR-0007: o user-agent nunca anuncia headless.
    it "HeadlessChrome vira Chrome e o resto fica igual" do
      headless = user_agent.sub("Chrome/153", "HeadlessChrome/153")

      expect(described_class.headful_user_agent(headless)).to eq(user_agent)
    end
  end

  describe ".login_with_retry" do
    before { allow(Rails.logger).to receive(:warn) }

    # ADR-0008: uma nova tentativa depois de 30 s, e só uma.
    it "primeira tentativa falha, espera 30 s e devolve a sessão da segunda" do
      allow(described_class).to receive(:login_and_capture).and_invoke(
        -> { raise described_class::SsoNotCompletedError },
        -> { captured }
      )

      expect(described_class).to receive(:sleep).with(30)

      expect(described_class.login_with_retry).to eq(captured)
    end

    it "duas falhas seguidas param na segunda, sem terceira tentativa" do
      allow(described_class).to receive(:sleep)

      expect(described_class).to receive(:login_and_capture).twice
        .and_raise(described_class::SsoNotCompletedError)

      expect { described_class.login_with_retry }
        .to raise_error(described_class::SsoNotCompletedError)
    end

    # BDR-0007: insistir depois de captcha só irrita o anti-bot.
    it "captcha não é tentado de novo" do
      expect(described_class).to receive(:login_and_capture).once
        .and_raise(described_class::CaptchaError)
      expect(described_class).not_to receive(:sleep)

      expect { described_class.login_with_retry }.to raise_error(described_class::CaptchaError)
    end
  end

  describe ".login_and_capture" do
    before { allow(Rails.logger).to receive(:error) }

    it "senha não configurada falha sem abrir navegador" do
      stub_env("MAGALU_EMAIL" => "afiliados@lecupon.com")

      expect(Selenium::WebDriver).not_to receive(:for)

      expect { described_class.login_and_capture }
        .to raise_error(described_class::MissingCredentialError)
    end

    # O Chrome remoto atende uma sessão por vez: uma sessão esquecida trava o próximo login.
    it "navegador é encerrado quando o login levanta erro" do
      stub_env(
        "MAGALU_EMAIL" => "afiliados@lecupon.com",
        "MAGALU_SENHA" => "senha",
        "SELENIUM_URL" => "http://localhost:4444"
      )
      driver = instance_double(Selenium::WebDriver::Driver, execute_script: user_agent)
      allow(Selenium::WebDriver).to receive(:for).and_return(driver)
      allow(driver).to receive(:navigate).and_raise(Selenium::WebDriver::Error::WebDriverError)

      expect(driver).to receive(:quit).twice # a sonda e o login

      expect { described_class.login_and_capture }
        .to raise_error(Selenium::WebDriver::Error::WebDriverError)
    end
  end

  describe ".sso_completed?" do
    it "volta ao Magazine Você fora da tela de login conclui o SSO" do
      expect(described_class.sso_completed?("https://www.magazinevoce.com.br/admin")).to be(true)
      expect(described_class.sso_completed?("https://www.magazinevoce.com.br/login/id-magalu"))
        .to be(false)
    end
  end

  describe ".sso_failure" do
    let(:typed) { { email: true, password: true } }

    # ADR-0013: mesmas marcas da página de captcha da Magalu.
    it "página com title Captcha vira captcha citando a versão do Chrome" do
      failure, message = described_class.sso_failure(
        page_source: "<html><title>Captcha</title></html>", typed: typed, user_agent: user_agent
      )

      expect(failure).to eq(described_class::CaptchaError)
      expect(message).to include("Chrome 153")
    end

    it "página com perfdrive vira captcha" do
      failure, _message = described_class.sso_failure(
        page_source: "<script src='https://perfdrive.com'></script>", typed: typed,
        user_agent: user_agent
      )

      expect(failure).to eq(described_class::CaptchaError)
    end

    it "sem e-mail digitado, o campo de e-mail não foi encontrado" do
      failure, message = described_class.sso_failure(
        page_source: "<html></html>", typed: { email: false, password: false },
        user_agent: user_agent
      )

      expect(failure).to eq(described_class::SsoFieldNotFoundError)
      expect(message).to include("e-mail")
    end

    it "com e-mail e sem senha digitada, o campo de senha não foi encontrado" do
      failure, message = described_class.sso_failure(
        page_source: "<html></html>", typed: { email: true, password: false },
        user_agent: user_agent
      )

      expect(failure).to eq(described_class::SsoFieldNotFoundError)
      expect(message).to include("senha")
    end

    it "e-mail e senha digitados sem conclusão viram SSO não concluído" do
      failure, _message = described_class.sso_failure(
        page_source: "<html></html>", typed: typed, user_agent: user_agent
      )

      expect(failure).to eq(described_class::SsoNotCompletedError)
    end
  end

  describe ".extract_session" do
    before { allow(Rails.logger).to receive(:error) }

    let(:cookie) do
      {
        name: "sessionid",
        value: "sessionid-do-cookie",
        domain: ".magazinevoce.com.br",
        expires: DateTime.new(2026, 9, 30, 21, 0, 0)
      }
    end

    it "cookie sessionid com validade vira a sessão capturada" do
      session = described_class.extract_session(cookies: [ cookie ], user_agent: user_agent)

      expect(session).to include(
        session_id: "sessionid-do-cookie",
        user_agent: user_agent,
        expires_at: Time.utc(2026, 9, 30, 21, 0, 0)
      )
    end

    it "SSO concluído sem cookie sessionid falha com sessionid não extraído" do
      expect { described_class.extract_session(cookies: [], user_agent: user_agent) }
        .to raise_error(described_class::SessionIdNotExtractedError)
    end

    it "cookie sessionid sem validade falha com sessionid não extraído" do
      expect do
        described_class.extract_session(cookies: [ cookie.except(:expires) ],
                                        user_agent: user_agent)
      end.to raise_error(described_class::SessionIdNotExtractedError)
    end
  end
end
