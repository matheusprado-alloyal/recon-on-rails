# ADR-0016 — Curated append-only, com o estado atual calculado por view

- **Status:** Aceito
- **Data:** 2026-09-25
- **Decisões de negócio relacionadas:** [BDR-0012](../bdr/0012-todo-vinculo-e-informado-ao-lojista.md),
  [BDR-0013](../bdr/0013-operador-confirma-import-do-lojista.md)

## Contexto

A curated é a réplica local do que foi dito ao Lojista Alloyal. Ela existe para resolver ruído de
comunicação entre operadores ("mandamos canceled no dia 22"). Se ela guardasse o estado atual e o
histórico em duas tabelas gravadas, as duas poderiam divergir.

## Decisão

- **`magalu_curated_statuses`** é append-only. Cada linha é um status incluído numa remessa:
  - os campos do contrato (`external_id`, `order_number`, `order_amount`, `transaction_status`);
  - o vínculo;
  - `remitted_at`, o momento em que o status entrou na remessa.

  O `order_amount` é um snapshot do valor enviado.
- **`magalu_curated_imports`** é append-only. Cada linha é uma confirmação de import:
  `confirmed_until`, quem confirmou e quando.
- **`magalu_curated_orders`** é uma **view**. Ela mostra o último status de cada pedido, entre os
  vínculos ativos, e se esse status já foi confirmado.
- Um status está **confirmado** quando o `remitted_at` dele é menor ou igual ao maior
  `confirmed_until`.
- **A remessa** leva os status dos vínculos ativos que ainda não foram confirmados. Reenviar não
  cria linha nova.
- **A urgência é uma consulta:** um canceled de um vínculo que já tem pending na tabela.
- **O rollback de vínculo não toca a curated.** A view e a remessa ignoram os vínculos devolvidos.
  A linha que já tinha saído numa remessa continua gravada, como histórico.

## Consequências

- Existe uma fonte de verdade só. O estado atual é derivado do histórico, então os dois nunca
  divergem.
- A view entra na migration com `execute` (e o inverso no `down`), e o `db/structure.sql` a
  registra.
- A view usa um índice em `(external_id, remitted_at)`. Se um dia ela pesar, vira view
  materializada.
- O canal (CSV hoje, API depois) não muda a tabela: é só mais um jeito de entregar as mesmas
  linhas.
