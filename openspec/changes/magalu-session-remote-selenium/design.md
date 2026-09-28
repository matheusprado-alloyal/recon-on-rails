# Design

## Context

- A sessão Magalu ainda não tem código no Backbone: só a ingestão Alloyal existe
  (`app/services/ingestion/alloyal/ingest.rb`, módulo com métodos `self.`). O desenho vigente
  (ADR-0006/0007/0008, BDR-0007) previa Ferrum + Chrome num estágio do Dockerfile e `MAGALU_UA` no
  `.env`. Motivação da troca: ver `proposal.md` — Why.
- O legado (`recon_alloyal/core/infrastructure/magalu_session_manager.py`) usa **patchright** (um
  Playwright com o fingerprint de automação removido) com `launch_persistent_context`, flags
  `--no-sandbox`, `--disable-dev-shm-usage`, `--disable-blink-features=AutomationControlled`,
  viewport 1366x768 e UA forçado. O entrypoint do legado apaga `Singleton*` do perfil ao subir.
- O compose já tem o serviço `chrome` (`docker/chrome/Dockerfile`: `FROM
  selenium/standalone-chrome:latest` + `mkdir` do perfil), com `SE_NODE_MAX_SESSIONS: 1`, noVNC em
  `127.0.0.1:7900` e o volume `browser_profile` em `/home/seluser/browser-profile`.
- `Selenium::WebDriver::Remote::Driver` (gem `selenium-webdriver`) **não** tem `execute_cdp`; só
  expõe `se:cdp` para o `devtools`, que depende da gem `selenium-devtools` amarrada à versão do CDP.
- ADR-0011 fixa os seams de teste do navegador: `login_and_capture` e `login_with_retry`.

## Goals / Non-Goals

**Goals:**
- Imagem da aplicação sem navegador; o navegador é um serviço à parte no mesmo compose.
- Portar o fluxo de login do legado com o mínimo de peças (ADR-0006: YAGNI).
- User-agent sem configuração manual e sempre coerente com o Chrome que fez o login.
- Todo o comportamento do spec testável sem abrir navegador.

**Non-Goals:**
- Ingestão de pedidos Magalu, e o uso das credenciais pela API (fica para outra change).
- Resolução humana de captcha em produção (ver Open Questions).
- Scripts de stealth por CDP, lock entre processos, cooldown, backoff, watchdog, alertas externos.
- Executar qualquer comando (bundle, migração, rspec, docker): tudo vai para o runbook.

## Decisions

### D1. Selenium WebDriver remoto contra `selenium/standalone-chrome`
`Selenium::WebDriver.for(:remote, url: ENV.fetch("SELENIUM_URL"), options:)`.

Alternativas avaliadas e descartadas (vão para o ADR-0008):
- **Ferrum + Chrome na imagem da aplicação** (desenho anterior): imagem pesada, todo deploy
  rebuilda o navegador.
- **Ferrum remoto por CDP** (Chrome com `--remote-debugging-port` em container próprio): mantém o
  CDP sem chromedriver, mas exige manter um container nosso (entrypoint, socat, sem noVNC pronto).
- **Híbrido** (Grid cria a sessão, Ferrum pluga no `se:cdp`): soma a complexidade das duas.
- **Navegador sob demanda** (a ingestão sobe/derruba o container): exigiria controlar o Docker de
  dentro da aplicação.
- **Gem de stealth nativa em Ruby**: não há uma mantida (`undetected-chromedriver` e
  `selenium-stealth` são Python). O disfarce fica nas flags/opções (D4).

### D2. User-agent derivado do Chrome por uma sessão-sonda
O `--user-agent` precisa ser passado na abertura do Chrome, mas a versão só é conhecida depois que
ele abre. Solução: `login_and_capture` abre uma **sessão-sonda** sem perfil, lê
`navigator.userAgent` em `about:blank` (nenhum tráfego para a Magalu), encerra, e abre a sessão de
login com `--user-agent=<ua da sonda com HeadlessChrome → Chrome>`.
- Função pura `headful_user_agent(ua)` (`sub("HeadlessChrome", "Chrome")`), testada direto.
- Descartadas: `MAGALU_UA` no `.env` (decisão do usuário: manter em sincronia manual é o erro que se
  quer evitar); `execute_cdp("Network.setUserAgentOverride")` (indisponível no driver remoto);
  `devtools` (gem extra amarrada à versão do CDP); `/status` do Grid (depende de detalhe da
  configuração do docker-selenium).
- Custo: um Chrome a mais aberto e fechado por login (segundos), só quando há login (~48 h).

### D3. Alerta de atualização da imagem ao gravar
`save_session(captured)` lê a linha atual antes do upsert. Se `chrome_major(antiga.user_agent) !=
chrome_major(captured.user_agent)`, `Rails.logger.warn("Imagem do navegador atualizada: sessão
anterior com Chrome 153, login atual com Chrome 154")`. Não bloqueia. Hipótese de trabalho: um salto
de versão pequeno (152→153) não provoca captcha; um salto grande (140→150) pode, por isso o
`CaptchaError` também cita a versão do Chrome (spec: Falhas de login classificadas).
`chrome_major(ua)` é função pura (`ua[%r{Chrome/(\d+)}, 1]`).

### D4. Opções do Chrome: união do ADR-0008, do legado e do Selenium
```
--no-sandbox  --disable-setuid-sandbox  --disable-dev-shm-usage
--disable-blink-features=AutomationControlled  --window-size=1366,768
--user-agent=<D2>  --user-data-dir=/home/seluser/browser-profile   (só na sessão de login)
--headless=new                                                     (se HEADLESS)
excludeSwitches: ["enable-automation"]   useAutomationExtension: false
```
`HEADLESS = true` é uma constante em `Session`. Em dev, edita-se para `false` e acompanha-se pelo
noVNC (`http://localhost:7900`). Sem variável de ambiente (decisão do usuário).

### D5. Fluxo de login (porta do legado, sem aquecer a home)
1. Credencial: sem `MAGALU_EMAIL` ou `MAGALU_SENHA` → `MissingCredentialError` antes de abrir o
   navegador.
2. `navigate.to` da URL do SSO do legado (`id.magalu.com/login?client_id=…&redirect_uri=…&
   response_type=code&scope=openid&email=<MAGALU_EMAIL>`).
3. Laço de até 12 passos, cada um: se a URL é `magazinevoce.com.br` sem `login` → concluído; senão
   o primeiro campo **visível** de e-mail (`input[type='email'], input[name='email'],
   input[name='login'], #login-input`) ou de senha (`input[type='password'],
   input[name='password'], #password-input`) é digitado letra por letra (`sleep(rand(0.08..0.25))`)
   e submetido pelo botão (XPath: `button[@type='submit']` ou texto `Continuar`/`Entrar`) ou
   `Enter`; pausas sorteadas entre passos.
4. Sem conclusão, a falha é classificada numa função pura `sso_failure(page_source:,
   email_typed:, password_typed:)`: captcha (`<title>Captcha`/`perfdrive`) → `CaptchaError`;
   sem e-mail → `SsoFieldNotFoundError` (e-mail); sem senha → idem (senha); senão
   `SsoNotCompletedError`.
5. Concluído: `driver.manage.cookie_named("sessionid")`; ausente ou sem `expires` →
   `SessionIdNotExtractedError`. `expires` pode vir como `DateTime`: converter com `to_time`.
6. `driver&.quit` em `ensure`, na sonda e no login.

Erros: `Ingestion::Magalu::Session::LoginError < StandardError` (aninhados em `Session` pelo Zeitwerk) e as subclasses acima, cada uma logada com
`Rails.logger.error` com o motivo. Métodos pequenos para caber em complexidade ≤ 10.

### D6. Nova tentativa em `login_with_retry`
`login_and_capture`; em `LoginError` que não seja `CaptchaError` nem `MissingCredentialError`,
`sleep(30)` e `login_and_capture` de novo, sem terceiro. Testes fazem `allow(described_class).to
receive(:sleep)`.

### D7. Persistência e API pública
- Tabela `magalu_session` (ADR-0006): `id integer default 1`, `CHECK (id = 1)` com nome
  `magalu_session_singleton`, `session_id text not null`, `user_agent text not null`, `expires_at
  timestamptz not null`, `captured_at timestamptz not null`. O model `Ingestion::MagaluSession`
  declara `self.table_name = "magalu_session"`, porque o Rails derivaria o plural.
- Gravação: `upsert({ id: 1, ... }, unique_by: :id)` (`ON CONFLICT (id) DO UPDATE`); `upsert` entra
  em `Rails/SkipsModelValidations.AllowedMethods`.
- `get_credentials`: linha com `expires_at > Time.current` → `Credentials`; senão
  `save_session(login_with_retry)`. `renew_credentials`: `save_session(login_with_retry)`. Ambos
  devolvem `Ingestion::Magalu::Credentials = Data.define(:session_id, :user_agent)` (ADR-0007).
- Task: `bin/rails ingestion:magalu_session` (garante sessão) e
  `bin/rails "ingestion:magalu_session[force]"` (renova), imprimindo só os 15 primeiros caracteres do
  `sessionid`.

### D8. Compose: tag fixa, `hostname` fixo, Dockerfile mínimo mantido
- `docker/chrome/Dockerfile` **fica**, com `FROM selenium/standalone-chrome:<tag fixa>` e o `mkdir`:
  um volume nomeado montado num caminho que não existe na imagem nasce com dono `root`, e o
  `seluser` não conseguiria escrever o perfil. O build é de uma camada, cacheado, e não toca a imagem
  da aplicação, então o deploy da aplicação continua sem navegador.
- `hostname: recon_chrome`: a trava `SingletonLock` é `<hostname>-<pid>`. Com o mesmo hostname e o
  pid morto, o Chrome reassume o perfil sozinho, sem script de limpeza.
- `SE_NODE_MAX_SESSIONS: 1` fica (outros consumidores futuros entram na fila).

### D9. Testes (ADR-0009, ADR-0011)
- `get_credentials`/`renew_credentials`: `allow(described_class).to receive(:login_with_retry)`.
- Nova tentativa: `allow(described_class).to receive(:login_and_capture)` com
  `and_raise`/`and_return` em sequência.
- Credencial ausente: `login_and_capture` direto, com `ENV` sem a senha, e
  `expect(Selenium::WebDriver).not_to receive(:for)`.
- Liberação do navegador: `allow(Selenium::WebDriver).to receive(:for)` devolvendo um
  `instance_double(Selenium::WebDriver::Driver)` cujo `navigate` levanta; espera-se `quit`. É a
  chamada que sai da nossa infraestrutura; o ADR-0011 ganha essa linha.
- Funções puras (`headful_user_agent`, `chrome_major`, `sso_failure`) e o alerta de D3 (linha real
  no Postgres de teste + `expect(Rails.logger).to receive(:warn)`).

## Risks / Trade-offs

- [chromedriver deixa sinais que o patchright escondia (`cdc_`, `navigator.webdriver`)] → opções
  de D4; validar primeiro em dev com tela, depois headless em produção. Critério de aceite no
  runbook. Plano B documentado: Ferrum remoto (D1), trocando só o corpo de `login_and_capture`.
- [Headless anuncia `HeadlessChrome` nos Client Hints (`Sec-CH-UA`) mesmo com UA forçado] → se o
  headless for bloqueado e o com tela passar, produção vira `HEADLESS = false` no Xvfb do container.
- [Tag do docker-selenium não existir exatamente como `<major>.0`] → o runbook confere com
  `docker pull` antes de subir.
- [`db/structure.sql` e `Gemfile.lock` ficam desatualizados até o operador rodar os comandos; a suíte
  de testes não sobe antes disso] → o runbook ordena `bundle install` → `db:migrate` → `rspec`.
- [Sessão-sonda soma segundos e um Chrome extra por login] → aceitável: login a cada ~48 h.
- [Navegador compartilhado com outros serviços, 1 sessão por vez] → login pode esperar na fila do
  Grid; subir `SE_NODE_MAX_SESSIONS` quando houver o segundo consumidor.

## Migration Plan

Não há dados nem código anteriores. Sequência de subida e rollback no `RUNBOOK_MAGALU_SESSION.md`:
`docker compose build chrome && docker compose up -d chrome`, `bundle install`, `bin/rails
db:migrate`, `bundle exec rspec`, login real em dev com tela, depois em produção headless. Rollback:
`bin/rails db:rollback` (a tabela só é usada por esta change).

## Open Questions

- Como uma pessoa resolve o captcha em produção (BDR-0007)? Hoje o login para com `CaptchaError` e
  fecha o navegador. Resolver exige manter o navegador aberto para o noVNC; isso não muda esta change
  e entra quando o captcha aparecer de verdade.
- Se a Magalu mostrar uma página de "navegador desatualizado" em vez de captcha, guardar o HTML para
  criar a detecção (não há amostra hoje).
