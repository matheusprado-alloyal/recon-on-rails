# ADR-0010 — Conventional Commits, um commit por intenção

- **Status:** Aceito
- **Data:** 2026-09-23

## Decisão

- Mensagens no formato `tipo(escopo): descrição`, em inglês, como o histórico existente.
- Tipos em uso: `feat`, `chore`, `build`. Escopo: o pacote afetado (ex.: `ingestion`).
- **Um commit por intenção.** Mudanças com objetivos diferentes vão em commits separados,
  mesmo quando feitas no mesmo dia (ex.: a tabela da sessão separada da remoção do `LIMIT`).
- Um passo pequeno e com os testes passando vira um commit, antes do passo seguinte.
