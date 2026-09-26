# ADR-0017 — Anomalias em tabela de controle, detectadas na conciliação

- **Status:** Aceito
- **Data:** 2026-09-25
- **Decisão de negócio relacionada:** [BDR-0014](../bdr/0014-billed-que-volta-para-true-e-anomalia.md)

## Contexto

A raw sobrescreve o `billed` ([ADR-0012](0012-ingestao-magalu-por-watermark.md)), então o
histórico dele se perde. Um `Rails.logger.error` vai para um log que ninguém consulta, sem registro de
quem resolveu.

## Decisão

- **`magalu_anomalies`** é uma tabela de controle. Cada linha é uma anomalia: tipo, vínculo,
  quando foi detectada, quem resolveu e quando.
- **A detecção fica na conciliação**, comparando a curated com a raw. Se o último status informado
  é canceled e a raw diz `billed=true`, isso é uma anomalia. A ingestion não muda.
- Um false → true que acontece antes de qualquer status ser informado não é detectado. Esse caso
  não tem consequência nenhuma.
- A detecção roda a cada job, e o índice único parcial impede duplicata
  ([ADR-0015](0015-exclusividade-por-constraint.md)).
- O aviso vai pelo Slack e o front lê a tabela.

## Consequências

- Hoje existe um tipo de anomalia só. A coluna de tipo deixa espaço para outros tipos sem mudar a
  tabela.
