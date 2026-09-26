# ADR-0002 — Um Postgres, cada tabela com um contexto dono

- **Status:** Aceito
- **Data:** 2026-09-23

## Contexto

O banco é uma unidade compartilhada de infraestrutura (um Postgres, uma conexão, um
histórico de migrations). A dúvida era se isso tornava os models também compartilhados.

## Decisão

- **Compartilhado:** a conexão (`config/database.yml`, lida das variáveis `POSTGRES_*`) e o
  `ApplicationRecord`. Não conhecem negócio.
- **Com dono:** cada tabela tem um model ActiveRecord no namespace do contexto que escreve nela.
  As tabelas da ingestão ficam em `app/models/ingestion/`, no schema `cashback`
  ([ADR-0014](0014-schema-por-setor-e-camadas-medallion.md)). O model declara o nome completo
  da tabela: `self.table_name = 'cashback.alloyal_raw_orders'`.
- **O schema do banco é versionado em `db/structure.sql`**, e não em `db/schema.rb`. O
  `schema.rb` não representa views nem tabelas fora do schema `public`, e o Backbone usa os dois.
- **Migrations são escritas, não inferidas.** `bin/rails generate migration NomeDaMudanca`
  cria o arquivo com o timestamp; o conteúdo (`up`/`down` ou `change`) é escrito à mão e lido
  antes do `bin/rails db:migrate`.

## Consequências

- Toda migration aplicada atualiza o `db/structure.sql`. O diff dele no commit mostra
  exatamente o que mudou no banco.
- Um comando que o ActiveRecord não expressa (view, `ALTER TABLE ... SET SCHEMA`) entra na
  migration com `execute`, com o inverso escrito no `down`.
