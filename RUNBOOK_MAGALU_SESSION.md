# Runbook temporário: sessão Magalu com Selenium remoto

> Arquivo temporário da change `openspec/changes/magalu-session-remote-selenium/`. Apague depois
> de validar em produção.
>
> **Nenhum comando foi executado** na implementação. `Gemfile.lock` e `db/structure.sql` ainda
> não refletem a change: a suíte só roda depois dos passos da seção 2.

---

## 1. Índice de revisão do código (leia nesta ordem)

A ordem vai do mais simples ao mais denso. Cada item diz **o que olhar** e **qual conceito de Ruby
aparece ali**. Leia o teste junto com o código: cada `it "..."` do spec é uma regra de negócio.

### 1.1 `app/services/ingestion/magalu/credentials.rb` (5 linhas)
- **O que olhar:** o par `session_id` + `user_agent`, que sempre anda junto (ADR-0007).
- **Ruby:** `Data.define(:a, :b)` cria uma classe imutável com esses campos (um *value object*).
  `Credentials.new(session_id: "x", user_agent: "y")`; dois objetos com os mesmos valores são `==`.

### 1.2 `db/migrate/20260928220000_create_magalu_session.rb`
- **O que olhar:** `id: :integer, default: 1` (sem sequência), `CHECK (id = 1)` com nome
  `magalu_session_singleton`, todas as colunas `null: false`. Compare com a tabela do ADR-0006.
- **Ruby/Rails:** `create_table ... do |t| ... end` é um bloco. O `t` é o "construtor" da tabela.
  `# rubocop:disable ...` desliga uma regra de lint só neste arquivo, com o motivo ao lado.

### 1.3 `app/models/ingestion/magalu_session.rb`
- **O que olhar:** `self.table_name = "magalu_session"`. Sem isso, o Rails procuraria
  `magalu_sessions` (plural).
- **Ruby/Rails:** `class X < ApplicationRecord` é um model do ActiveRecord: uma classe ligada a uma
  tabela. `Ingestion::MagaluSession.find_by(id: 1)` devolve a linha ou `nil`.

### 1.4 `app/services/ingestion/magalu/session.rb`, em 5 blocos
O arquivo é um `module` com métodos `def self.nome`. Isso é como uma classe só com métodos
estáticos: chama-se `Ingestion::Magalu::Session.get_credentials`, sem `new`.

1. **Constantes e erros (topo do arquivo).**
   - Confira as flags (`CHROME_ARGS`) contra o ADR-0008 e o legado, e a `SSO_URL` contra o legado
     (o `client_id` foi copiado de `magalu_session_manager.py`).
   - **Ruby:** `NOME = valor` é constante; `.freeze` impede alteração. `"a" \ "b"` (barra no fim da
     linha) concatena strings em várias linhas. `class CaptchaError < LoginError; end` declara um
     erro que herda de outro.
2. **API pública: `get_credentials`, `renew_credentials`, `save_session`, `warn_browser_update`.**
   - Confira a regra do ADR-0006: sessão válida não abre navegador; vencida ou forçada faz login e
     grava **por cima** (`upsert`).
   - **Ruby:** `return x if cond` é um *guard clause* (sai cedo). `captured.merge(id: 1)` devolve um
     novo Hash com a chave a mais. `"#{variavel}"` interpola dentro de aspas duplas.
3. **Nova tentativa: `login_with_retry`.**
   - Confira: uma nova tentativa só, depois de 30 s, e nunca depois de `CaptchaError` ou
     `MissingCredentialError`.
   - **Ruby:** `rescue LoginError => e` no corpo do método funciona como um `try/catch` do método
     inteiro. `raise` sem argumento relança o mesmo erro.
4. **Login: `login_and_capture` → `probe_user_agent` → `open_browser`/`browser_options` →
   `run_sso` → `sso_step` → `type_and_submit`.**
   - Confira: a credencial é checada **antes** de abrir o navegador. A sonda lê o user-agent sem
     perfil. O `ensure` fecha o navegador sempre. O laço tem no máximo 12 passos. A digitação é
     letra por letra.
   - **Ruby:** `ensure` roda sempre, com erro ou sem (o `finally` de outras linguagens). `driver&.quit`
     só chama `quit` se `driver` não for `nil`. `12.times do ... end` repete o bloco; um `return`
     dentro do bloco sai do **método**. `find(&:displayed?)` é um atalho para
     `find { |e| e.displayed? }`. `**selector` recebe argumentos nomeados (`css:` ou `xpath:`) e os
     repassa. `if (field = visible(...))` atribui e testa ao mesmo tempo.
   - **Ponto de atenção:** se a tela de senha mantiver o campo de e-mail visível, o laço digitaria
     o e-mail de novo (o legado tem o mesmo comportamento). Observe isso no teste em dev (seção 3).
5. **Funções puras: `headful_user_agent`, `chrome_major`, `sso_completed?`, `sso_failure`,
   `extract_session`, `fail_login`.**
   - São a parte mais fácil de testar e a que decide o motivo de cada falha.
   - **Ruby:** `ua[%r{Chrome/(\d+)}, 1]` aplica a regex e devolve o grupo 1 (ou `nil`). Um método
     terminado em `?` devolve booleano, por convenção. `failure, message = [A, B]` desempacota um
     array em duas variáveis.

### 1.5 `spec/services/ingestion/magalu/session_spec.rb`
- **O que olhar:** cada `describe ".metodo"` testa um método. Leia os nomes dos `it`: eles são as
  regras do spec em `openspec/changes/.../specs/magalu-session/spec.md`.
- **RSpec:**
  - `let(:x) { ... }` define uma variável preguiçosa (calculada no primeiro uso, por teste).
  - `described_class` é `Ingestion::Magalu::Session`.
  - `allow(obj).to receive(:metodo).and_return(v)` substitui um método só neste teste (o *seam* do
    ADR-0011). `expect(obj).to receive(:metodo)` **antes** da ação exige que ele seja chamado.
  - `and_invoke(-> { raise ... }, -> { captured })`: a 1ª chamada levanta, a 2ª devolve.
  - `instance_double(Selenium::WebDriver::Driver, ...)` é um dublê que só aceita métodos que a
    classe real tem.
  - `stub_const("ENV", {...})` troca as variáveis de ambiente só dentro do teste.
  - Cada teste roda numa transação desfeita no fim (ADR-0009): nada fica no banco de teste.

### 1.6 `lib/tasks/magalu_session.rake`
- **O que olhar:** a task não tem regra, só chama o serviço. Com `[force]`, renova.
- **Ruby:** `cond ? a : b` é o `if` numa linha. `str[0, 15]` pega os 15 primeiros caracteres.

### 1.7 Infra: `Gemfile`, `docker/chrome/Dockerfile`, `docker-compose.yaml`, `.rubocop.yml`
- `Gemfile`: entrou `selenium-webdriver`.
- `Dockerfile`: tag fixa `153.0` e o `mkdir` do perfil, com o motivo comentado.
- `docker-compose.yaml`: `hostname: recon_chrome` (a trava do perfil depende do hostname).
- `.rubocop.yml`: `upsert` liberado em `Rails/SkipsModelValidations`.

### 1.8 Documentação
ADR-0007 e ADR-0008 foram reescritos, com as alternativas descartadas. BDR-0007, ADR-0011, o índice
de ADRs, `docs/design-doc.md` e `CLAUDE.md` foram ajustados. O nome do arquivo do ADR-0008 continua
com `ferrum`, porque 8 links apontam para ele.

---

## 2. Preparar o ambiente

1. `.env`: remova `MAGALU_UA`. Confira `MAGALU_EMAIL` e `MAGALU_SENHA`. Acrescente:
   ```
   SELENIUM_URL=http://localhost:4444
   ```
2. Confira se a tag da imagem existe (se não existir, troque em `docker/chrome/Dockerfile` pela tag
   estável mais próxima de `selenium/standalone-chrome`):
   ```bash
   docker pull selenium/standalone-chrome:153.0
   ```
3. Suba o navegador:
   ```bash
   docker compose build chrome && docker compose up -d chrome
   ```
4. Gems, migração e testes:
   ```bash
   bundle install                 # atualiza o Gemfile.lock (commitar)
   bin/rails db:migrate           # cria magalu_session e atualiza db/structure.sql (commitar)
   bundle exec rspec spec/services/ingestion/magalu/session_spec.rb
   bundle exec rspec              # suíte inteira + cobertura mínima de 80%
   bundle exec rubocop            # lint, incluindo complexidade ≤ 10
   ```
   Se `add_chromium_option` der `NoMethodError`, a gem instalada é antiga:
   `bundle update selenium-webdriver`.

---

## 3. Validação em dev (com tela)

1. Em `app/services/ingestion/magalu/session.rb`, troque `HEADLESS = true` por `HEADLESS = false`
   (**não commite essa troca**).
2. Abra o noVNC: `http://localhost:7900/?autoconnect=1&resize=scale` (senha padrão: `secret`).
3. Rode e acompanhe o navegador pelo noVNC:
   ```bash
   bin/rails ingestion:magalu_session
   ```
4. Confira:
   - a saída `Sessão Magalu OK: sessionid=...`;
   - `log/development.log`: "preenchendo e-mail", "preenchendo senha", nenhum erro;
   - a linha gravada:
     ```bash
     bin/rails runner 'p Ingestion::MagaluSession.find(1).attributes.except("session_id")'
     ```
     O `user_agent` deve ter `Chrome/153...` **sem** `HeadlessChrome`, e o `expires_at` deve ficar
     cerca de 48 h depois do `captured_at`.
5. Rode de novo `bin/rails ingestion:magalu_session`: **nenhum navegador** deve abrir (a sessão é
   reusada).
6. **Critério de aceite em dev:** login concluído sem captcha.
7. Volte `HEADLESS = true`.

---

## 4. Validação em produção (headless)

1. `.env` de produção: `SELENIUM_URL=http://chrome:4444` (o nome do serviço na rede do compose),
   sem `MAGALU_UA`.
2. `HEADLESS = true` (valor commitado).
3. Suba `chrome`, rode a migração e depois `bin/rails ingestion:magalu_session`.
4. **Critério de aceite em produção:** login concluído sem captcha, em headless.
5. Se aparecer `CaptchaError`:
   - anote a versão do Chrome citada na mensagem;
   - **não** repita o login em sequência (captcha atrai captcha);
   - teste com tela (`HEADLESS = false`, Xvfb do container) e registre o resultado no ADR-0008;
   - se nem com tela passar, o plano B está no ADR-0008 (Ferrum remoto por CDP).
6. Se a Magalu mostrar uma página de "navegador desatualizado", guarde o HTML: ainda não existe
   detecção para ela.

---

## 5. Recuperação

| Situação | O que fazer |
|---|---|
| Perfil contaminado depois de um bloqueio | `docker compose down chrome && docker volume rm <projeto>_browser_profile && docker compose up -d chrome` |
| Erro de "perfil em uso" (`SingletonLock`) mesmo com `hostname` fixo | Com o container parado: `docker run --rm -v <projeto>_browser_profile:/p alpine rm -f /p/SingletonLock /p/SingletonCookie /p/SingletonSocket` |
| Trocar a versão do Chrome | Mude a tag em `docker/chrome/Dockerfile`, `docker compose build chrome && docker compose up -d chrome`. O próximo login registra `Imagem do navegador atualizada: ... Chrome X ... Chrome Y` |
| Renovar a sessão manualmente | `bin/rails "ingestion:magalu_session[force]"` |
| Desfazer a migração | `bin/rails db:rollback` (a tabela só é usada por esta change) |
