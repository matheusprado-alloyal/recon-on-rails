# ADR-0005 — Pedido recusado pelo contrato é registrado no log, e o fluxo segue

- **Status:** Aceito
- **Data:** 2026-09-23
- **Decisão de negócio relacionada:** [BDR-0005](../bdr/0005-pedido-alloyal-sem-nome-e-recusado.md)

## Contexto

O legado descartava pedidos sem nome, porque o match dele era por nome. O descarte era
silencioso: dado sumia sem ninguém ver.

O nome continua sendo chave do match ([BDR-0005](../bdr/0005-pedido-alloyal-sem-nome-e-recusado.md)),
então um pedido sem ele não pode entrar. O que muda em relação ao legado é que o descarte é
decidido e visível.

## Decisão

- O contrato da fonte recusa o pedido que não traz o que a conciliação exige: sem `user_name`,
  sem `organization_name` ([ADR-0019](0019-campos-exigidos-pela-conciliacao-not-null.md)) ou com
  um `raw_payload` só com os campos promovidos
  ([ADR-0004](0004-contrato-da-fonte-na-fronteira.md)).
- Um contrato recusado **não é gravado** e gera um `Rails.logger.error` com o `number` e os
  motivos:

```
Pedido Alloyal recusado: number=... (motivos)
```

- A ingestão segue para o próximo pedido: uma recusa nunca interrompe a execução.
- A separação mora num método próprio (`reject_invalid`), testado isoladamente: o inválido vai
  para o log e fica de fora; o válido segue, sem log.

## Consequências

- Um pedido recusado não entra na `alloyal_raw_orders`, então nunca vira candidato. Fica só o
  log.
- `user_name` e `organization_name` são `NOT NULL` no banco.
- O mesmo princípio vale para a Magalu: um pedido sem `total` é recusado e registrado
  ([ADR-0019](0019-campos-exigidos-pela-conciliacao-not-null.md)).
