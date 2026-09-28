# CLAUDE.md

This file provides guidance to Claude when working with code in this repository.

## What this is

Data backbone for reconciling App Alloyal orders against affiliate orders, starting with Magalu (magazinevoce.com.br). It has two stages: **ingestion** (App Alloyal orders from a read-only source DB, Magalu orders from the Magalu affiliate API, both landing raw in a local Postgres) and **reconciliation** (candidates, order links confirmed by an analyst, statuses sent to the Lojista Alloyal).

**Current state: M0 in progress** (App Alloyal ingestion). The documentation is the specification. Implementation follows the roadmap in `docs/design-doc.md` §7.

Read `CONTEXT.md` (domain glossary) before naming domain concepts, and `docs/design-doc.md` for the designed system. Technical decisions live in `docs/adr/`, business decisions in `docs/bdr/`.

## Stack

- Ruby 3.4 (pinned in `mise.toml` and `.ruby-version`) and Rails 8.1 (`Gemfile.lock`).
- Postgres 17 via `docker compose` (reads `POSTGRES_*` from `.env`).
- ActiveRecord migrations, schema dumped to `db/structure.sql` (ADR-0002).
- RSpec (`rspec-rails`), SimpleCov for coverage, RuboCop (`rubocop-rails-omakase`) for lint.
- `selenium-webdriver` against a remote real Chrome (`selenium/standalone-chrome`, pinned tag, its own compose service) for the Magalu login (ADR-0008). The app image has no browser.
- The front end is TypeScript and calls the Rails controllers over HTTP (ADR-0018).

## Commands (once the app exists)

```bash
docker compose up -d                          # local Postgres 17
bundle install                                # install gems
bin/rails db:prepare                          # create + migrate dev and test databases
bin/rails generate migration NameOfChange     # new migration file (content is written by hand)
bin/rails db:migrate                          # apply migrations, updates db/structure.sql

bundle exec rspec                             # all tests
bundle exec rspec spec/services/ingestion/magalu/orders_spec.rb:42   # single test by line
bundle exec rubocop                           # lint (incl. cyclomatic complexity)

bin/rails ingestion:alloyal                   # App Alloyal ingestion
bin/rails ingestion:magalu_session            # ensure a Magalu session ("ingestion:magalu_session[force]" renews)
bin/rails ingestion:magalu_orders             # Magalu orders ingestion
```

## Tests

- `spec/` mirrors `app/` (e.g. `spec/services/ingestion/magalu/orders_spec.rb`).
- Tests hit a **real Postgres**: the Rails test database, separate from the development one (ADR-0009). Each test runs in a transaction that Rails rolls back, so no test data survives.
- Because the test database is separate, the real captured `magalu_session` in the development database is never touched by tests.
- External systems that aren't our Postgres are replaced at existing method seams with RSpec `allow(...).to receive`, never through dependency injection (ADR-0011). The seams are `login_and_capture` / `login_with_retry` for the browser and `fetch_page` for the Magalu API. The App Alloyal source DB gets a connectivity check only (`SELECT version();`).

## Engineering guidelines

### Karpathy guidelines

These come from Andrej Karpathy's observations on common LLM coding mistakes. They bias toward caution over speed; use judgment on trivial tasks.

1. **Think before coding.** State assumptions explicitly. If a request has more than one interpretation, lay them out instead of picking one silently. If something is unclear, stop and ask. If a simpler approach exists, say so.
2. **Simplicity first.** Write the minimum code that solves the problem. Add no speculative features, no abstractions for single-use code, no configurability nobody asked for, and no error handling for impossible cases. If 200 lines could be 50, rewrite it.
3. **Surgical changes.** Touch only what the task requires. Don't "improve" adjacent code, comments or formatting. Match the existing style. Remove only the dead code your own change created, and mention any other dead code instead of deleting it. Every changed line should trace back to the request.
4. **Goal-driven execution.** Turn the task into verifiable success criteria (e.g. "write a test that reproduces the bug, then make it pass"). For multi-step work, state a short plan with a check for each step, and loop until the checks pass.

### TDD

- Red → green → refactor. Write a test that fails for the right reason, make it pass with the smallest change, then clean up with the test still green.
- A test calls the **production method**, never a copy of its SQL or logic (ADR-0009). A good test fails when the rule it protects disappears.
- Each test proves **one** rule, with only the fields that rule needs, and values taken from real data where possible.
- Name the test after the rule it protects, in Portuguese, e.g. `it "pedido sem user_name é recusado"`.

### Test coverage

- Floor: **80% line coverage** (SimpleCov `minimum_coverage 80`).
- Coverage is a floor, not a goal. Prefer a test that protects a business rule over a test that only touches lines.

### Cyclomatic complexity

- Max **10** per method, enforced by RuboCop `Metrics/CyclomaticComplexity`.
- If a method crosses the limit, split out the decision it's making, and don't raise the limit.

## Style

- RuboCop: `rubocop-rails-omakase` (double quotes, 2-space indentation), plus line length 100.
- Comments, log messages and error messages are in **Portuguese**. Comments state the invariant or contract, not the mechanics (e.g. "Imutável: pedido já gravado é ignorado, nunca atualizado.").
- Every index gets an explicit `name:` in its migration (ADR-0014).

## Architecture

**Two database connections:**
- The backbone Postgres, the only one in `config/database.yml`, built from `POSTGRES_*` env vars.
- The App Alloyal source DB, read-only, opened directly with the `pg` gem from `ALLOYAL_SOURCE_DB_URL` (credentials embedded in the URL). It is not an ActiveRecord connection and not in `config/database.yml` (ADR-0002). `pg` returns every value as text, so the contract is the only place where source data gets types.

**Schema ownership:** one repository and one database per business sector; this one is Cashback, and its tables live in `public` (ADR-0001, ADR-0014). Each table has an ActiveRecord model in the namespace of the context that writes to it; Rails derives the table name from the class name (ADR-0002). Table names follow `<affiliate>_<raw|refined|curated>_<entity>`; the App Alloyal is the pivot and only has `alloyal_raw_orders`. Control tables (`magalu_session`, `magalu_orders_watermark`, `magalu_anomalies`) have no layer.

**Layers** (ADR-0018): entrypoint (controller, `rake` task) → service (`app/services/`) → model (`app/models/`). Source contracts and outbound rows are `ActiveModel` classes in `app/contracts/`. Controllers and tasks hold no rules. Nothing is shared across affiliates before a second one needs it.

**Ingestion (App Alloyal)**, `Ingestion::Alloyal::Ingest`:
1. Source rows are validated through `Ingestion::AlloyalOrderContract`, built with `from_row(row)`. The promoted fields are the contract's `attribute`s; the full original row is kept in `raw_payload` (JSONB). A `raw_payload` with only promoted keys is rejected. The source `status` and `external_id` are not promoted.
2. Timezone-naive `created_at` is treated as UTC, declared in the contract's `created_at=` (it arrives as text from `pg`). This is a source contract.
3. Writes use `insert_all(..., unique_by: :number)` (`ON CONFLICT (number) DO NOTHING`). **Raw tables are immutable.** The primary key `id` is the Alloyal source id, not a sequence.
4. An invalid contract (missing `user_name` or `organization_name`, or a `raw_payload` with only promoted keys) is logged with `Rails.logger.error` and skipped by `reject_invalid`; the run goes on (ADR-0005, BDR-0005).

**Magalu session**, `Ingestion::Magalu::Session`:
- `magalu_session` is a singleton table (`CHECK id = 1`) holding the `sessionid` cookie and the user-agent.
- `get_credentials` returns the stored session and logs in only when there is none or it has expired. `renew_credentials` forces a login, e.g. after a 401, with one retry only.
- Login uses Selenium in `:remote` mode against the `chrome` compose service (`SELENIUM_URL`), **headless** via the `HEADLESS` constant (set it to `false` in dev and watch through noVNC on `localhost:7900`), the flags and flow in ADR-0008 (straight to the SSO, no home warm-up), and a persistent profile in the `browser_profile` volume inside the browser container (a secret). One retry after 30 s, never after a captcha or a missing credential. Avoid repeated forced logins: they attract captcha.
- The user-agent comes from the browser itself (a probe session reads `navigator.userAgent`, `HeadlessChrome` becomes `Chrome`), is forced on the login and stored with the session. A Chrome major version change between the stored session and the new login logs an image-update warning (ADR-0007).

**Magalu orders**, `Ingestion::Magalu::Orders`:
- `fetch_page` calls `rochelle.magazinevoce.com.br/v1/showcase/orders` with the session cookie and the same user-agent. A 401 raises `SessionRejectedError`; a 200 whose body is the captcha page raises `BlockedByAntiBotError` (ADR-0013).
- Orders are validated through `Ingestion::MagaluOrderContract`. A naive `created_at` is assumed **BRT**. `total` is required. An order the contract rejects is logged and skipped.
- `save_orders` upserts on `ml_order_id` and **only writes when `billed`/`commission` change** (`IS DISTINCT FROM`), with hand-written SQL (BDR-0008).
- `ingest_orders` paginates newest-first by `meta.next` and stops at `watermark - 90 days`. `magalu_orders_watermark` advances only after the whole run succeeds (ADR-0012).

**Reconciliation**: see BDR-0009 to 0014 and ADR-0014 to 0019. Exclusivity is enforced by partial unique indexes, never by application locks (ADR-0015). Curated tables are append-only and the current state is a view (ADR-0016).

**Env vars:** `POSTGRES_*`, `ALLOYAL_SOURCE_DB_URL`, `MAGALU_EMAIL`, `MAGALU_SENHA`, `SELENIUM_URL`. `.env` is loaded by `dotenv-rails` in development and test only.

## Agent skills

### Issue tracker

Issues live in GitHub Issues for `Alloyal-Platform/use-backbone`, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the default labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
