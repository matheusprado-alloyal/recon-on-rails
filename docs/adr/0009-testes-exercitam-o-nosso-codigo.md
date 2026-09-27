# ADR-0009 — Testes exercitam o nosso código, contra um Postgres real

- **Status:** Aceito
- **Data:** 2026-09-23

## Contexto

Um teste que escreve o próprio `INSERT ... ON CONFLICT` prova que o Postgres funciona, não que
a ingestão funciona.

## Decisão

- Framework: **RSpec** (`rspec-rails`, `bundle exec rspec`), com os testes em `spec/`
  espelhando `app/`. Escolhido no lugar do Minitest padrão do Rails pelos mocks embutidos
  (`allow`/`expect`) e pela saída legível como lista de regras (`--format documentation`).
- Um teste chama o **método de produção** (ex.: `save_raw_orders`), e não uma cópia do SQL.
- Um bom teste **falha quando a regra some**.
- Os testes rodam contra um **Postgres de verdade**: o banco de teste do Rails, separado do banco
  de desenvolvimento. Cada teste roda dentro de uma transação que o Rails desfaz no final
  (`use_transactional_fixtures`, no `spec/rails_helper.rb`), então nenhum dado de teste sobra.
- Como o banco de teste é separado, a sessão Magalu real, guardada no banco de desenvolvimento,
  nunca é tocada pelos testes.
- Cada teste carrega só os campos necessários para provar **uma** regra, com valores tirados
  de dado real.
- O nome do teste é a regra que ele protege, em português (ex.:
  `it "pedido sem user_name é recusado"`).

## Consequências

- Rodar os testes exige o Postgres de pé e o banco de teste preparado
  (`bin/rails db:test:prepare`).
- Ver [ADR-0011](0011-seam-de-teste-por-substituicao-de-funcao.md) para como os sistemas
  externos que não são o nosso Postgres (navegador, API da Magalu, banco de origem da Alloyal)
  entram nos testes.
