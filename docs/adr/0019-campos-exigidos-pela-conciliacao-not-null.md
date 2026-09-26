# ADR-0019 — `total` e `organization_name` são NOT NULL

- **Status:** Aceito
- **Data:** 2026-09-25
- **Decisões de negócio relacionadas:** [BDR-0009](../bdr/0009-conciliacao-por-afiliadora-app-alloyal-pivo.md),
  [BDR-0012](../bdr/0012-todo-vinculo-e-informado-ao-lojista.md)

## Contexto

A conciliação depende de dois campos que não podem faltar:

- o `order_amount` do contrato do Lojista Alloyal vem de `magalu_raw_orders.total`;
- o escopo dos candidatos vem de `alloyal_raw_orders.organization_name`.

A operação confirma que o `organization_name` nunca é nulo e nunca muda.

## Decisão

- O `total` é obrigatório no `Ingestion::MagaluOrderContract`, e `magalu_raw_orders.total` é
  `NOT NULL` (`null: false`). Um pedido sem `total` é recusado pelo contrato: ele é logado e o fluxo segue
  ([ADR-0005](0005-invariante-violada-e-registrada.md)).
- O `organization_name` é obrigatório no `Ingestion::AlloyalOrderContract`, e
  `alloyal_raw_orders.organization_name` é `NOT NULL` (`null: false`).
- As duas colunas já nascem `NOT NULL` na migration que cria as tabelas.

## Consequências

- Um Pedido Magalu sem `total` não entra na raw, então nunca vira vínculo nem vai para o Lojista
  Alloyal. Fica só o log.
