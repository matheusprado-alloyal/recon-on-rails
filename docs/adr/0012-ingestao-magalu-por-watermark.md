# ADR-0012 — Ingestão Magalu incremental por marca d'água, parada na janela de 90 dias

- **Status:** Aceito
- **Data:** 2026-09-24
- **Decisão de negócio relacionada:** [BDR-0008](../bdr/0008-reingerir-90-dias-por-faturamento-tardio.md)

## Contexto

A API de pedidos da Magalu (`/v1/showcase/orders`) devolve páginas do pedido mais novo para o
mais antigo, com paginação por `meta.next`. Sem um ponto de parada, cada execução releria todo o
histórico.

## Decisão

- `magalu_orders_watermark` — tabela singleton (`CHECK id = 1`, como
  [ADR-0006](0006-sessao-magalu-singleton-sob-demanda.md)) guarda `last_success_at`: o início do
  último job que terminou com sucesso.
- `ingest_orders` pagina do mais novo para o mais antigo e para quando encontra um pedido
  anterior a `last_success_at - 90 dias` (a janela do BDR-0008), mesmo que `meta.next` ainda
  aponte para mais páginas.
- O watermark só é gravado (`save_watermark`) **depois** que a paginação inteira termina — uma
  falha no meio não avança a marca, e a próxima execução relê a mesma janela.
- `save_orders` só grava a diferença, com SQL escrito à mão (a condição `WHERE` do
  `DO UPDATE` não cabe no `upsert_all`): `ON CONFLICT (ml_order_id) DO UPDATE ... WHERE (billed,
  commission) IS DISTINCT FROM (EXCLUDED.billed, EXCLUDED.commission)` — um pedido que não mudou
  não gera escrita nem avança `updated_at`.

## Consequências

- Sem watermark (primeira execução), a ingestão lê o histórico inteiro.
- Uma falha de rede a meio da paginação é segura: a marca não avançou, o próximo job cobre a
  mesma janela de novo.
- O custo de cada execução é proporcional a ~90 dias de pedidos, não ao histórico inteiro.
