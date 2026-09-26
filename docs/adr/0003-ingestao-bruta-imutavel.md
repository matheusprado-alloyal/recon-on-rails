# ADR-0003 — Ingestão bruta e imutável, com o id da fonte

- **Status:** Aceito
- **Data:** 2026-09-23
- **Decisão de negócio relacionada:** [BDR-0004](../bdr/0004-pedido-alloyal-e-imutavel.md)

## Contexto

A primeira fonte é o banco da Alloyal (tabela `orders`), lido em modo somente leitura via
`ALLOYAL_SOURCE_DB_URL`. Cada linha é o **Pedido do lado da Alloyal**, identificado por
`number`. A operação decidiu que as mudanças de status desse pedido são irrelevantes para
o Backbone.

## Decisão

- A tabela `cashback.alloyal_raw_orders` guarda o pedido **como veio**:
  - alguns campos são "promovidos" para colunas tipadas (`number`, `organization_name`,
    `user_name`, `cashback_value`, `status`, `created_at`...);
  - a linha original inteira fica em `raw_payload` (JSONB).
- **Imutável:** a gravação usa `insert_all(..., unique_by: :number)`, que o ActiveRecord
  traduz para `INSERT ... ON CONFLICT (number) DO NOTHING`. Um pedido já gravado nunca é
  atualizado, e reingerir é idempotente.
- `number` é `NOT NULL` e `UNIQUE` no schema, então a regra "number não pode ser nulo" não é
  repetida no código.
- O `id` gravado é o **id da Alloyal**, sempre informado no `INSERT`. Ele não é gerado pelo
  banco.
- A consulta à origem traz **todos** os pedidos com `organization_name = 'Magalu'`
  ([BDR-0006](../bdr/0006-ingerir-todos-os-pedidos-magalu.md)).

## Consequências

- O `status` gravado é uma foto do momento da ingestão. Nenhuma regra deve depender dele.
- O `raw_payload` é gravado como JSONB; datas e decimais viram texto na serialização.
- A tabela é criada com `id: false` e a coluna `id` declarada como `bigint` chave primária, sem
  sequence. Um teste garante que o `id` gravado é o da Alloyal.
