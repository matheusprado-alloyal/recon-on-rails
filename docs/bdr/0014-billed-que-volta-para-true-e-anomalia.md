# BDR-0014 — billed que volta de false para true é anomalia

- **Status:** Aceito
- **Data:** 2026-09-25

## Contexto

Do lado da Magalu, um pedido cancelado não volta a ser faturado
([BDR-0012](0012-todo-vinculo-e-informado-ao-lojista.md)). Se isso aparecer, algo saiu do padrão,
e o Lojista Alloyal pode ter recebido um canceled que não vale mais.

## Decisão

- Um `billed` que volta de false para true é uma **anomalia**.
- O sistema **registra e avisa** (Slack e front). **Um humano decide** o que fazer.
- O sistema **nunca** manda um pending sozinho depois de um canceled.

## Consequências

- Técnica: [ADR-0017](../adr/0017-anomalias-em-tabela-de-controle.md).
