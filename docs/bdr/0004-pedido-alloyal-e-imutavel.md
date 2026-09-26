# BDR-0004 — O Pedido do lado da Alloyal é identificado por `number` e é imutável

- **Status:** Aceito
- **Data:** 2026-09-23

## Contexto

Cada linha da tabela `orders` do banco da Alloyal é o **Pedido do lado da Alloyal**. O mesmo
código aparece no link enviado à Magalu: `number = LC216407539` e
`deep_link = ...?xtra=LC216407539`.

O pedido é atualizado sempre que o status muda (`updated_at`, log de `transaction_status`).
Essas mudanças são feitas por pessoas, e o controle delas já existe por outros meios.

## Decisão

- O identificador do Pedido Alloyal é **`number`**.
- As mudanças de status são **irrelevantes** para o Backbone: seriam excesso de informação.
- Por isso o Pedido Alloyal é tratado como **imutável**: gravado uma vez, nunca atualizado.

## Consequências

- Técnica: [ADR-0003](../adr/0003-ingestao-bruta-imutavel.md).
- O `status` guardado é o do momento da ingestão e não deve ser usado como regra.
