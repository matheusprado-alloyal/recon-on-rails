# ADR-0005 — Invariante violada é registrada como erro, nunca descartada

- **Status:** Aceito
- **Data:** 2026-09-23
- **Decisão de negócio relacionada:** [BDR-0005](../bdr/0005-todo-pedido-alloyal-tem-nome.md)

## Contexto

A operação afirma que todo Pedido Alloyal tem `user_name`, porque só um usuário logado
compra. O legado descartava pedidos sem nome, porque o match dele era por nome. Isso fazia
dado sumir sem ninguém ver.

## Decisão

- "Todo Pedido Alloyal tem nome" é uma **invariante**.
- Um pedido que a viole é **gravado mesmo assim**, e gera um `Rails.logger.error` com o `number`:

```
Pedido Alloyal sem user_name (invariante violada): number=...
```

- A verificação mora num método próprio (`log_missing_user_name`), para poder ser testada
  isoladamente.

## Consequências

- O dado bruto fica completo, e a violação fica visível no log.
- A coluna `user_name` continua aceitando nulo no banco. Se um dia a decisão mudar para
  "rejeitar a linha", a mudança é pequena e fica registrada num ADR novo.
