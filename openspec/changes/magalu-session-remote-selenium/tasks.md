# Tasks

> Nenhum comando é executado durante a implementação (bundle, migração, rspec, rubocop, docker).
> "Verificar" abaixo significa: o spec/arquivo existe e o passo correspondente está no
> `RUNBOOK_MAGALU_SESSION.md` para o operador rodar.

## 1. Dependência e infraestrutura

- [x] 1.1 Adicionar `gem "selenium-webdriver"` ao `Gemfile` (grupo default); verificar que o runbook tem `bundle install` e o commit do `Gemfile.lock`
- [x] 1.2 `docker/chrome/Dockerfile`: `FROM selenium/standalone-chrome:<major>.0` (tag fixa, sem `latest`), mantendo o `mkdir` do perfil com o comentário do porquê (D8); verificar que o runbook confere a tag com `docker pull`
- [x] 1.3 `docker-compose.yaml`: `hostname: recon_chrome` no serviço `chrome`, mantendo `SE_NODE_MAX_SESSIONS: 1`, portas em `127.0.0.1`, volume e limites; verificar por leitura do diff
- [x] 1.4 `.rubocop.yml`: incluir `upsert` em `Rails/SkipsModelValidations.AllowedMethods` com comentário citando ADR-0006; verificar por leitura

## 2. Persistência da sessão

- [x] 2.1 Migração `CreateMagaluSession` escrita à mão (ADR-0006, D7): colunas, `CHECK (id = 1)` nomeado `magalu_session_singleton`, sem timestamps do Rails; verificar que o runbook roda `bin/rails db:migrate` e commita o `db/structure.sql`
- [x] 2.2 Model `Ingestion::MagaluSession` com `self.table_name = "magalu_session"` (sem `record_timestamps`: a tabela não tem colunas de timestamp do Rails), e `Ingestion::Magalu::Credentials = Data.define(:session_id, :user_agent)`; verificar pelo spec de 3.x que carrega os dois
- [x] 2.3 Spec: "duas capturas seguidas deixam uma sessão só" (upsert real no Postgres de teste); verificar que o arquivo existe em `spec/services/ingestion/magalu/session_spec.rb`

## 3. Sessão: reuso, renovação e alerta de imagem

- [x] 3.1 `Ingestion::Magalu::Session.get_credentials`, `renew_credentials` e `save_session` (D7), com comentários de invariante em português; verificar pelos specs de 3.3
- [x] 3.2 Funções puras `headful_user_agent` e `chrome_major` e o alerta em `save_session` (D2, D3); verificar pelos specs de 3.4
- [x] 3.3 Specs com `allow(described_class).to receive(:login_with_retry)`: sessão válida não faz login; sem sessão faz login e grava; vencida faz login e substitui; renovação forçada substitui sessão válida; sessão gravada tem `session_id`, `user_agent`, `expires_at` e `captured_at`
- [x] 3.4 Specs: `HeadlessChrome/153.0.0.0` vira `Chrome/153.0.0.0`; troca 153 → 154 gera `warn` com as duas versões e grava; mesma versão não gera `warn`

## 4. Login no navegador remoto

- [x] 4.1 Hierarquia `Ingestion::Magalu::Session::LoginError` e subclasses (dentro de `Session`: o Zeitwerk espera uma constante por arquivo) (`MissingCredentialError`, `CaptchaError`, `SsoFieldNotFoundError`, `SsoNotCompletedError`, `SessionIdNotExtractedError`) com mensagens em português; verificar pelos specs de 4.5
- [x] 4.2 `login_and_capture` (D2, D4, D5): checagem de credencial antes do navegador, sessão-sonda, sessão de login com as opções de D4 e constante `HEADLESS = true`, SSO direto sem home, laço de 12 passos com digitação letra por letra, `quit` em `ensure`; verificar que nenhum método passa de complexidade 10 por leitura e que o runbook roda `bundle exec rubocop`
- [x] 4.3 Função pura `sso_failure(page_source:, email_typed:, password_typed:)` e extração do cookie `sessionid` com `expires` (D5); verificar pelos specs de 4.5
- [x] 4.4 `login_with_retry` (D6): uma nova tentativa depois de `sleep(30)`, nunca depois de `CaptchaError` nem de `MissingCredentialError`; verificar pelos specs de 4.6
- [x] 4.5 Specs: senha ausente falha sem abrir navegador (`expect(Selenium::WebDriver).not_to receive(:for)`); página com `<title>Captcha`/`perfdrive` vira captcha citando a versão do Chrome; sem e-mail/sem senha viram campo não encontrado; senão SSO não concluído; navegador é encerrado quando o login levanta erro (`instance_double` devolvido por `Selenium::WebDriver.for`)
- [x] 4.6 Specs com `allow(described_class).to receive(:login_and_capture)` e `receive(:sleep)`: falha e depois sucesso espera 30 s e devolve a segunda; duas falhas param na segunda; captcha não tenta de novo

## 5. Entrypoint

- [x] 5.1 `lib/tasks/magalu_session.rake`: `ingestion:magalu_session` chama `get_credentials`; com o argumento `force` chama `renew_credentials`; imprime só 15 caracteres do `sessionid`, sem regra no task; verificar que o runbook tem os dois comandos

## 6. Documentação

- [x] 6.1 Reescrever ADR-0008 no lugar: Selenium remoto no `standalone-chrome`, opções de D4, sem home, seletores do legado, digitação humana, perfil no volume, `hostname` fixo, `SE_NODE_MAX_SESSIONS: 1`, e a seção "Alternativas avaliadas e descartadas" de D1/D2; verificar por leitura
- [x] 6.2 Reescrever ADR-0007 (UA derivado do Chrome, gravado com a sessão, alerta de atualização da imagem, sem `MAGALU_UA`) e conferir ADR-0006 (não cita Ferrum: sem mudança) e ADR-0011 (a chamada `Selenium::WebDriver.for` como fronteira da regra de liberação do navegador); verificar por leitura
- [x] 6.3 Reescrever BDR-0007: sem aquecer a home, navegador em container próprio no servidor e não na imagem da aplicação; verificar por leitura
- [x] 6.4 `docs/design-doc.md` §6.2, §7.2 e §9 e `CLAUDE.md` (stack, arquitetura da sessão, env vars: entra `SELENIUM_URL`, sai `MAGALU_UA`); verificar com uma busca por `Ferrum`, `MAGALU_UA` e `.browser_profile` que não restou referência ao desenho antigo fora do histórico
- [x] 6.5 `CONTEXT.md`: ajustar o verbete Sessão Magalu se citar o user-agent vindo do `.env` (não cita: sem mudança); verificar por leitura

## 7. Runbook (temporário)

- [x] 7.1 `RUNBOOK_MAGALU_SESSION.md` na raiz: índice de revisão do código para quem está começando em Ruby, pré-requisitos (`.env` com `SELENIUM_URL`, `MAGALU_EMAIL`, `MAGALU_SENHA`; remover `MAGALU_UA`), conferir a tag (`docker pull`), `docker compose build chrome && docker compose up -d chrome`, `bundle install`, `bin/rails db:migrate` (commitar `db/structure.sql` e `Gemfile.lock`), `bundle exec rspec`, `bundle exec rubocop`
- [x] 7.2 Runbook, validação em dev: `HEADLESS = false`, noVNC em `http://localhost:7900` (senha padrão `secret`), `bin/rails ingestion:magalu_session`, conferir a linha em `magalu_session` e o log; critério de aceite: login sem captcha
- [x] 7.3 Runbook, validação em produção: `HEADLESS = true`, `SELENIUM_URL=http://chrome:4444`, rodar a task; critério de aceite: login sem captcha em headless; se houver captcha, anotar a versão do Chrome logada, testar com tela (Xvfb) e registrar o resultado
- [x] 7.4 Runbook, recuperação: perfil contaminado depois de bloqueio (`docker volume rm` do `browser_profile`), trava `Singleton*` persistente, troca de tag da imagem (esperar o alerta de atualização no próximo login), rollback (`bin/rails db:rollback`)
