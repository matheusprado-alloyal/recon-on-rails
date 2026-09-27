# BDR-0009 — A conciliação é por afiliadora, com o App Alloyal como pivô

- **Status:** Aceito
- **Data:** 2026-09-25

## Contexto

A Alloyal é uma empresa com vários microserviços. O **App Alloyal** é o sistema onde a compra
nasce. Cada compra passa por uma **afiliadora** (Magalu, Shopee, Awin, Rakuten, CityAds etc.),
e cada afiliadora tem as suas próprias regras para ligar o pedido dela ao pedido do App Alloyal.
O resultado da conciliação vai para o **Lojista Alloyal**, um banco de dados externo que recebe
o import curado.

## Decisão

- O **App Alloyal (core)** é a fonte única e o pivô. Ele é comparado contra cada afiliadora e não
  se repete por afiliadora.
- **Cada afiliadora tem regras de vínculo próprias.** A Magalu é a primeira.
- Um pedido do App Alloyal pertence a uma afiliadora pelo `organization_name`. Na Magalu, o valor
  é `Magalu`. O `organization_name` nunca muda e nunca é nulo.
- O **Lojista Alloyal** é externo porque o Backbone não é dono dele, mesmo sendo da Alloyal.
  Todo terceiro é externo, mas nem todo externo é terceiro.
- No contrato do Lojista Alloyal:
  - `external_id` é o id do pedido na afiliadora (na Magalu, `ml_order_id`);
  - `order_number` é sempre o `number` do App Alloyal.

  Isso é uma tradução para o Lojista Alloyal e não tem relação com a raw. Na raw, o campo continua
  com o nome da fonte.

## Consequências

- Técnica: [ADR-0014](../adr/0014-camadas-medallion-no-nome-da-tabela.md) e
  [ADR-0018](../adr/0018-reconciliation-em-camadas-por-afiliadora.md).
- Uma nova afiliadora ganha as suas regras e as suas tabelas; nada é compartilhado antes disso.
