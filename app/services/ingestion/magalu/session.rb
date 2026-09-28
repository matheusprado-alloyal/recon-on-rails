module Ingestion
  module Magalu
    # Sessão Magalu (ADR-0006, BDR-0007): singleton no Postgres; login só quando estritamente
    # necessário, para não irritar o anti-bot.
    module Session
      # ADR-0008: em dev, troque para false e acompanhe o login pelo noVNC (localhost:7900).
      HEADLESS = true

      # Perfil persistente dentro do container do navegador (volume browser_profile).
      PROFILE_DIR = "/home/seluser/browser-profile"

      # ADR-0008: flags do ADR e do legado; o que o patchright escondia fica a cargo delas.
      CHROME_ARGS = [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-blink-features=AutomationControlled",
        "--window-size=1366,768"
      ].freeze

      # ADR-0008: SSO direto, sem aquecer a home, com o e-mail da conta na URL.
      SSO_URL = "https://id.magalu.com/login" \
                "?client_id=UNXjOnzXxirS-SusqRmmM39J24tsb8l-hoF4V9WrC4o" \
                "&redirect_uri=https://www.magazinevoce.com.br/login/id-magalu" \
                "&response_type=code&scope=openid&email=%<email>s".freeze

      # Seletores do legado, do mais estável (type) ao mais frágil (id).
      EMAIL_FIELD = "input[type='email'], input[name='email'], input[name='login'], #login-input"
      PASSWORD_FIELD = "input[type='password'], input[name='password'], #password-input"
      SUBMIT_BUTTON = "//button[@type='submit' or contains(., 'Continuar') or " \
                      "contains(., 'Entrar')]"

      MAX_SSO_STEPS = 12
      RETRY_DELAY = 30

      # Falha de login com motivo próprio; nunca devolve uma sessão vazia em silêncio.
      class LoginError < StandardError; end
      class MissingCredentialError < LoginError; end
      class CaptchaError < LoginError; end
      class SsoFieldNotFoundError < LoginError; end
      class SsoNotCompletedError < LoginError; end
      class SessionIdNotExtractedError < LoginError; end

      # ADR-0006: sessão guardada e não vencida é devolvida sem abrir navegador.
      def self.get_credentials
        session = Ingestion::MagaluSession.find_by(id: 1)
        return to_credentials(session) if session && session.expires_at > Time.current

        save_session(login_with_retry)
      end

      # ADR-0006: login forçado (ex.: a API respondeu 401), mesmo com sessão válida guardada.
      def self.renew_credentials
        save_session(login_with_retry)
      end

      # ADR-0006: grava por cima; nunca existe mais de uma sessão.
      def self.save_session(captured)
        previous = Ingestion::MagaluSession.find_by(id: 1)
        warn_browser_update(previous, captured[:user_agent]) if previous

        Ingestion::MagaluSession.upsert(captured.merge(id: 1), unique_by: :id)
        Credentials.new(session_id: captured[:session_id], user_agent: captured[:user_agent])
      end

      # ADR-0007: troca de versão do Chrome é aviso, não bloqueio.
      def self.warn_browser_update(previous, user_agent)
        before = chrome_major(previous.user_agent)
        after = chrome_major(user_agent)
        return if before == after

        Rails.logger.warn(
          "Imagem do navegador atualizada: sessão anterior com Chrome #{before}, " \
          "login atual com Chrome #{after}"
        )
      end

      def self.to_credentials(session)
        Credentials.new(session_id: session.session_id, user_agent: session.user_agent)
      end

      # ADR-0008: uma nova tentativa depois de 30 s, e só uma. Captcha e credencial ausente não
      # melhoram com outra tentativa: só irritariam o anti-bot.
      def self.login_with_retry
        login_and_capture
      rescue LoginError => e
        raise if e.is_a?(CaptchaError) || e.is_a?(MissingCredentialError)

        Rails.logger.warn("Login Magalu falhou; nova tentativa em #{RETRY_DELAY} s")
        sleep(RETRY_DELAY)
        login_and_capture
      end

      # Seam de teste (ADR-0011): a fronteira entre decidir renovar e abrir o navegador.
      # Devolve o que save_session grava: session_id, user_agent, expires_at e captured_at.
      def self.login_and_capture
        email, password = credentials_from_env
        user_agent = headful_user_agent(probe_user_agent)

        driver = open_browser(user_agent: user_agent)
        run_sso(driver, email, password, user_agent)
        sleep(3) # legado: o cookie chega depois do último redirecionamento
        extract_session(cookies: driver.manage.all_cookies, user_agent: user_agent)
      ensure
        driver&.quit
      end

      def self.credentials_from_env
        email = ENV["MAGALU_EMAIL"].presence
        password = ENV["MAGALU_SENHA"].presence
        return [ email, password ] if email && password

        fail_login(MissingCredentialError, "MAGALU_EMAIL e MAGALU_SENHA precisam estar no .env")
      end

      # ADR-0007: o user-agent sai do próprio Chrome. A sonda não abre o perfil e não fala com a
      # Magalu: só lê o navigator.userAgent numa página em branco.
      def self.probe_user_agent
        driver = open_browser
        driver.execute_script("return navigator.userAgent")
      ensure
        driver&.quit
      end

      # ADR-0007: o user-agent nunca anuncia headless.
      def self.headful_user_agent(user_agent)
        user_agent.sub("HeadlessChrome", "Chrome")
      end

      def self.chrome_major(user_agent)
        user_agent[%r{Chrome/(\d+)}, 1]
      end

      # Sem user_agent: sessão-sonda. Com user_agent: sessão de login, com o perfil persistente.
      def self.open_browser(user_agent: nil)
        Selenium::WebDriver.for(
          :remote, url: ENV.fetch("SELENIUM_URL"), options: browser_options(user_agent)
        )
      end

      # ADR-0008: esconde os sinais de automação do chromedriver.
      def self.browser_options(user_agent)
        options = Selenium::WebDriver::Chrome::Options.new(
          args: CHROME_ARGS.dup, exclude_switches: [ "enable-automation" ]
        )
        # Sem acessor próprio na gem: vai direto para o goog:chromeOptions.
        options.add_chromium_option("useAutomationExtension", false)
        options.add_argument("--headless=new") if HEADLESS
        if user_agent
          options.add_argument("--user-agent=#{user_agent}")
          options.add_argument("--user-data-dir=#{PROFILE_DIR}")
        end
        options
      end

      # ADR-0008: reage à tela que aparecer, até voltar ao Magazine Você fora do login.
      def self.run_sso(driver, email, password, user_agent)
        driver.navigate.to(format(SSO_URL, email: ERB::Util.url_encode(email)))
        typed = { email: false, password: false }

        MAX_SSO_STEPS.times do
          return if sso_completed?(driver.current_url)

          sso_step(driver, typed, email, password)
        end

        failure, message = sso_failure(page_source: driver.page_source, typed: typed,
                                       user_agent: user_agent)
        fail_login(failure, message)
      end

      def self.sso_completed?(url)
        url.include?("magazinevoce.com.br") && !url.include?("login")
      end

      def self.sso_step(driver, typed, email, password)
        if (field = visible(driver, css: EMAIL_FIELD))
          Rails.logger.info("Login Magalu: preenchendo e-mail")
          type_and_submit(driver, field, email)
          typed[:email] = true
        elsif (field = visible(driver, css: PASSWORD_FIELD))
          Rails.logger.info("Login Magalu: preenchendo senha")
          type_and_submit(driver, field, password)
          typed[:password] = true
        end
        sleep(rand(1.5..4.0))
      rescue Selenium::WebDriver::Error::StaleElementReferenceError,
             Selenium::WebDriver::Error::ElementNotInteractableError
        # A tela trocou no meio do passo; o próximo passo olha a tela nova.
        sleep(rand(1.5..4.0))
      end

      # O primeiro elemento visível do seletor (css: ou xpath:), ou nil.
      def self.visible(driver, **selector)
        driver.find_elements(**selector).find(&:displayed?)
      end

      # ADR-0008: digitação letra por letra, com intervalo sorteado.
      def self.type_and_submit(driver, field, text)
        field.clear
        text.each_char do |char|
          field.send_keys(char)
          sleep(rand(0.08..0.25))
        end

        button = visible(driver, xpath: SUBMIT_BUTTON)
        button ? button.click : field.send_keys(:enter)
      end

      # Motivo da falha na ordem do legado: captcha primeiro, porque ele esconde os campos.
      # Toda mensagem cita o Chrome do login, para saber se a versão pode ter causado a falha.
      def self.sso_failure(page_source:, typed:, user_agent:)
        chrome = "(Chrome #{chrome_major(user_agent)})"

        if page_source.include?("<title>Captcha") || page_source.include?("perfdrive")
          [ CaptchaError, "PerimeterX apresentou captcha no SSO #{chrome}" ]
        elsif !typed[:email]
          [ SsoFieldNotFoundError, "Campo de e-mail não encontrado no SSO #{chrome}" ]
        elsif !typed[:password]
          [ SsoFieldNotFoundError, "Campo de senha não encontrado no SSO #{chrome}" ]
        else
          [ SsoNotCompletedError, "SSO não concluiu depois de preencher e-mail e senha #{chrome}" ]
        end
      end

      # ADR-0006: o sessionid só vale com a validade declarada pelo servidor.
      def self.extract_session(cookies:, user_agent:)
        cookie = cookies.find do |c|
          c[:name] == "sessionid" && c[:domain].to_s.include?("magazinevoce.com.br")
        end
        unless cookie && cookie[:expires]
          fail_login(SessionIdNotExtractedError, "SSO concluído sem cookie sessionid com validade")
        end

        {
          session_id: cookie[:value],
          user_agent: user_agent,
          expires_at: cookie[:expires].to_time,
          captured_at: Time.current
        }
      end

      def self.fail_login(error_class, message)
        Rails.logger.error("Login Magalu falhou (#{error_class.name.demodulize}): #{message}")
        raise error_class, message
      end
    end
  end
end
