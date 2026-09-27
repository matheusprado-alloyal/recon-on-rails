# ADR-0006 — Sessão Magalu: singleton no Postgres, renovada sob demanda

- **Status:** Aceito
- **Data:** 2026-09-23
- **Decisão de negócio relacionada:** [BDR-0007](../bdr/0007-sessao-magalu-sem-job.md)

## Contexto

A API de pedidos da Magalu exige o cookie `sessionid` da conta de afiliado. Ele é criado por
um login SSO (`magazinevoce.com.br/login/conta` → `id.magalu.com` → `magazinevoce.com.br/admin`)
e fica no navegador como cookie `HttpOnly` e `Secure` do domínio `.magazinevoce.com.br`.
Ele **não** está no corpo da página.

A validade declarada pelo servidor (`Expires` do cookie) foi observada duas vezes: **48 horas**
depois do login. A Magalu pode invalidar a sessão antes disso.

O legado resolve isso em ~710 linhas (lock entre processos, status `RENOVANDO`, cooldown,
backoff, watchdog, alertas).

## Decisão

- **Singleton = uma linha no Postgres**, e não um objeto em memória. Um singleton em Ruby
  vive dentro de um processo só; com vários processos, cada um teria o seu e cada um faria
  login.
- Tabela `magalu_session`:

| Coluna | Regra |
|---|---|
| `id` | `INTEGER`, default `1`, sem autoincremento, `CHECK (id = 1)` (`magalu_session_singleton`) |
| `session_id` | `TEXT NOT NULL` |
| `user_agent` | `TEXT NOT NULL` ([ADR-0007](0007-user-agent-gravado-com-a-sessao.md)) |
| `expires_at` | `TIMESTAMPTZ NOT NULL`, o `Expires` do cookie |
| `captured_at` | `TIMESTAMPTZ NOT NULL`, o momento do login |

- **Renovação sob demanda, sem job** (`Ingestion::Magalu::Session`,
  `app/services/ingestion/magalu/session.rb`):
  - `get_credentials`: devolve a sessão guardada; só faz login se não há linha ou se
    `expires_at` já passou;
  - `renew_credentials`: login forçado, para quando a API responder **401**. Grava por
    cima com `upsert` (`INSERT ... ON CONFLICT (id) DO UPDATE`).
- O scraper tenta **uma** vez de novo depois de um 401 renovado. Um segundo 401 não é
  problema de sessão, e insistir só irritaria o anti-bot.

## Consequências

- Com uma sessão válida guardada, nenhum navegador abre (confirmado em teste real).
- `captured_at` permite medir quanto a sessão dura **de verdade**, comparando renovações.
- Ficam de fora, por YAGNI: lock entre processos, cooldown, backoff, watchdog e alertas.
  Entram se a operação mostrar que são necessários.
