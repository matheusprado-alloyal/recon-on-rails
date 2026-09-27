# BDR-0002 — Um repositório por setor; este é o do Cashback

- **Status:** Aceito
- **Data:** 2026-09-23

## Contexto

A operação tem quatro setores: **Cashback**, **Suporte**, **Infraestrutura** e **Deployment**.
Cada setor tem o seu repositório e o seu banco
([ADR-0001](../adr/0001-monorepo-monolito-modular-por-pacote.md)).

## Decisão

- Este repositório é o do **Cashback**, o processo que existe hoje.
- **Suporte:** depois.
- **Infraestrutura:** ainda amadurecendo.
- **Deployment:** fora do escopo por enquanto.
- KISS e YAGNI: um processo, um passo por vez.

## Consequências

- Os limites dos pacotes serão descobertos a partir do processo real de Cashback (Event
  Storming), e não do legado. Esse mapeamento ainda não foi feito.
