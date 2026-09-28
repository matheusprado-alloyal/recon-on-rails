# BDR-0005 — Pedido Alloyal sem nome é recusado

- **Status:** Aceito
- **Data:** 2026-09-23

## Contexto

Não existe compra "fantasma" no app: para comprar, o usuário precisa estar logado. Logo, todo
pedido deveria ter o nome do usuário.

O `user_name`, junto com o `number`, é chave do match com o pedido da afiliadora. Um pedido sem
nome não tem como ser conciliado.

## Decisão

- Um Pedido Alloyal sem `user_name` é **recusado**: não entra no Backbone.
- A recusa é **registrada**, nunca silenciosa.

## Consequências

- Técnica: [ADR-0005](../adr/0005-pedido-recusado-e-registrado.md).
- A diferença para o legado não é descartar ou não: é o descarte ficar visível.
