# BDR-0006 — A ingestão traz todos os pedidos Magalu da Alloyal

- **Status:** Aceito
- **Data:** 2026-09-24

## Decisão

A ingestão Alloyal deixou de ser uma amostra (`LIMIT 10`) e passou a trazer **todos** os pedidos
com `organization_name = 'Magalu'` da origem. "Agora a ingestão é pra valer."

## Consequências

- A execução demora mais do que a amostra.
- Como a gravação é imutável e idempotente ([ADR-0003](../adr/0003-ingestao-bruta-imutavel.md)),
  rodar de novo não duplica pedidos.
