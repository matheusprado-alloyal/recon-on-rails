# BDR-0013 — O operador confirma o import do Lojista Alloyal

- **Status:** Aceito
- **Data:** 2026-09-25

## Contexto

O arquivo de remessa é importado do lado do Lojista Alloyal, fora do Backbone. Quem sabe se o
import deu certo é o Lojista Alloyal, que avisa o operador. Sem esse registro, um ruído de
comunicação entre o operador do Backbone e o operador do Lojista Alloyal não tem como ser
resolvido.

## Decisão

- Depois do aviso do Lojista Alloyal, o operador confirma: **"importado até a data X"**.
- Cada confirmação fica registrada, com quem confirmou e quando.
- Um status que não está coberto por uma confirmação **volta na próxima remessa**, sem virar um
  status novo.
- A confirmação de import é o limite do rollback de vínculo pelo analista
  ([BDR-0011](0011-vinculo-de-pedidos-confirmado-pelo-analista.md)).

## Consequências

- Técnica: [ADR-0016](../adr/0016-curated-append-only-e-view.md).
- O Backbone não sabe se uma remessa gerada foi **entregue**, só se foi gerada e se foi
  confirmada.
