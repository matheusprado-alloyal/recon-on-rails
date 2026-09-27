# ADR-0001 — Um repositório por setor, monólito modular por contexto, múltiplas unidades de implantação

- **Status:** Aceito
- **Data:** 2026-09-23

## Contexto

A operação tem mais de um setor ([BDR-0002](../bdr/0002-escopo-inicial-cashback.md)), e este vai
rodar mais de um processo (ingestão, scraper, interface de conciliação). Precisávamos nomear a arquitetura a partir do que existe, sem
misturar três perguntas diferentes: onde o código mora, como ele se divide e como ele roda.

## Decisão

São três eixos independentes:

| Eixo | Decisão | No repositório |
|---|---|---|
| Repositório | **Um repositório por setor**; monorepo dentro dele | este é o do Cashback: a aplicação Rails e o front em TypeScript |
| Código | **Monólito modular por contexto** | uma aplicação Rails, com um namespace Ruby por contexto: `Ingestion`, `Reconciliation` |
| Execução | **Múltiplas unidades de implantação** (tipos de processo, no sentido do 12-Factor) | jobs (tarefas `rake`), o servidor HTTP e o front |

- Os limites dos contextos vêm do **DDD estratégico** (subdomínios e contextos delimitados),
  não dos processos. Um processo usa contextos; um contexto pode rodar em mais de um processo.
- O que é genérico e não conhece negócio (conexão, `ApplicationRecord`) é o **Shared Kernel**,
  e o próprio Rails já entrega a maior parte dele.
- Os testes espelham o código (`spec/services/ingestion/...` espelha `app/services/ingestion/...`).

## Consequências

- Um limite técnico (como o Shared Kernel) nunca é tratado como contexto de negócio.
- Cada setor tem o seu banco. Por isso não existe schema por setor: as tabelas ficam no
  `public` ([ADR-0014](0014-camadas-medallion-no-nome-da-tabela.md)).
- Todo conteúdo novo no Shared Kernel acopla todos os contextos; por isso ele deve continuar
  mínimo.
