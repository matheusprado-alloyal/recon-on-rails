# ADR-0011 — Seam de teste por substituição de método, não injeção de dependência

- **Status:** Aceito
- **Data:** 2026-09-24

## Contexto

A ingestão fala com três sistemas fora do nosso controle: o Postgres de origem da Alloyal
(`ALLOYAL_SOURCE_DB_URL`, somente leitura), o navegador de login da Magalu e a API HTTP de
pedidos da Magalu. O [ADR-0009](0009-testes-exercitam-o-nosso-codigo.md) já decidiu que o
Postgres do backbone é sempre real nos testes; faltava decidir o que fazer com esses outros
três.

## Decisão

- **Fonte Alloyal:** nenhum seam. O teste conecta de verdade e roda uma query trivial
  (`SELECT version();`) — só prova que o banco está de pé, não exercita regra de negócio.
- **Login Magalu (navegador):** o teste substitui, com `allow(...).to receive` do RSpec, o método que abre o
  navegador e captura a sessão (`login_and_capture` / `login_with_retry` em
  `Ingestion::Magalu::Session`). Esse método é a fronteira entre a decisão de renovar e o ato de
  abrir um navegador.
- **API de pedidos Magalu (HTTP):** `allow` em `fetch_page` (`Ingestion::Magalu::Orders`), pelo
  mesmo motivo.

Nenhuma assinatura de método de produção muda para viabilizar isso.

## Alternativas consideradas

### Injetar um cliente (HTTP, navegador) como parâmetro
- **Prós:** mais explícito sobre o que é substituível.
- **Contras:** muda a assinatura de métodos de produção só por causa do teste.
- **Por que não:** a substituição de método já prova o mesmo código de produção real
  (`ingest_orders`, `get_credentials`, `fetch_with_renewal`) sem essa mudança.

## Consequências

- O teste continua exercitando o código de produção real por cima do seam, só troca a chamada
  que sairia da nossa infraestrutura — consistente com o ADR-0009.
- Substituir um método pelo nome acopla o teste a esse nome; um refactor que o renomear quebra
  o teste de forma alta e óbvia, não em silêncio.
