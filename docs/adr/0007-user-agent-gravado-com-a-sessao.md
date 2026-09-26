# ADR-0007 — O user-agent do login é fixado no `.env` e gravado junto com a sessão

- **Status:** Aceito
- **Data:** 2026-09-24

## Contexto

O login acontece num navegador, mas o scraper chama a API por HTTP, só com o `sessionid`.
Se as duas pontas se apresentarem com user-agents diferentes, a Magalu vê a mesma sessão
vindo de "dois computadores". O legado registra isso como causa de sessão invalidada.

A receita de login que passa pelo anti-bot sem ajuda humana
([ADR-0008](0008-navegador-ferrum-chrome-perfil-persistente.md)) usa um user-agent fixo,
sem `HeadlessChrome`.

## Decisão

- O user-agent vem do `.env` (`MAGALU_UA`) e é **forçado** no navegador do login.
- O mesmo valor é gravado na coluna `magalu_session.user_agent`, junto com o `sessionid`.
- As duas funções públicas da sessão devolvem `Ingestion::Magalu::Credentials`, um
  `Data.define(:session_id, :user_agent)`. O scraper usa sempre os dois juntos.

## Consequências

- Login e scraper se apresentam sempre com o mesmo user-agent.
- Quando o Chrome do servidor for atualizado, o `MAGALU_UA` precisa acompanhar a versão.
- Valor observado num login real: `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36
  (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36` (sem `HeadlessChrome`).
