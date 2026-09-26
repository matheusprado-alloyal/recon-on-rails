# BDR-0005 — Todo Pedido Alloyal tem nome; a ausência é erro

- **Status:** Aceito
- **Data:** 2026-09-23

## Contexto

Não existe compra "fantasma" no app: para comprar, o usuário precisa estar logado. Logo, todo
pedido tem o nome do usuário.

## Decisão

- Um Pedido Alloyal sem `user_name` **não é descartado**.
- Ele é **registrado como erro**, porque indica um problema no dado.

## Consequências

- Técnica: [ADR-0005](../adr/0005-invariante-violada-e-registrada.md).
