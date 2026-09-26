# ADR-0014 — Schema por setor e camadas medallion no nome da tabela

- **Status:** Aceito
- **Data:** 2026-09-25
- **Decisão de negócio relacionada:** [BDR-0009](../bdr/0009-conciliacao-por-afiliadora-app-alloyal-pivo.md)

## Contexto

O Backbone atende quatro setores ([BDR-0002](../bdr/0002-escopo-inicial-cashback.md)) e a
conciliação tem camadas de dado. Um schema que repete o nome do banco, ou que junta camada e
pacote no mesmo nome, não escala.

## Decisão

- **Banco:** `backbone`. **Schema:** o do setor. O primeiro é o `cashback`, criado na primeira
  migration (`create_schema :cashback`).
- **Camadas medallion**, com nomes que dizem o que aconteceu com o dado:

  | Medallion | Nome | Fala a língua de | Conteúdo |
  |---|---|---|---|
  | bronze | `raw` | da fonte | como o dado chegou |
  | silver | `refined` | nossa | cruzado e decidido por nós |
  | gold | `curated` | do consumidor | pronto para o Lojista Alloyal, com os nomes do contrato |

- **Nome da tabela:** `<afiliadora>_<camada>_<entidade>`. O nome diz o que é cada linha.
- O App Alloyal é o pivô: só tem `raw` (`alloyal_raw_orders`).
- Tabelas de controle (`magalu_session`, `magalu_orders_watermark`, `magalu_anomalies`) guardam
  estado de operação e não recebem camada.

| Tabela | Camada | Cada linha é |
|---|---|---|
| `alloyal_raw_orders` | raw | um pedido do App Alloyal |
| `magalu_raw_orders` | raw | um Pedido Magalu |
| `magalu_refined_candidates` | refined | um candidato |
| `magalu_refined_orders` | refined | um vínculo de pedidos |
| `magalu_curated_statuses` | curated | um status incluído numa remessa |
| `magalu_curated_orders` | curated | view: o estado atual de cada pedido |
| `magalu_curated_imports` | curated | uma confirmação de import |

## Consequências

- Todo model declara o nome completo: `self.table_name = 'cashback.<tabela>'`.
- Todo índice tem `name:` explícito na migration. Um nome gerado automaticamente carrega o nome
  da tabela e muda se a tabela mudar de lugar.
