# ADR-0002 — Um Postgres, cada tabela com um contexto dono

- **Status:** Aceito
- **Data:** 2026-09-23

## Contexto

O banco é uma unidade compartilhada de infraestrutura (um Postgres, uma conexão, um
histórico de migrations). A dúvida era se isso tornava os models também compartilhados.

## Decisão

- **Compartilhado:** a conexão (`config/database.yml`, lida das variáveis `POSTGRES_*`) e o
  `ApplicationRecord`. Não conhecem negócio.
- **A origem do App Alloyal não é uma conexão do Rails.** Ela é aberta direto com a gem `pg`,
  a partir do `ALLOYAL_SOURCE_DB_URL`, e não aparece no `config/database.yml`. Motivos: menos
  maquinaria entre o código e a origem; os testes do Rails exigem uma conexão de escrita em todo
  banco declarado, e a origem é somente leitura; e a `pg` entrega todo valor como texto, o que
  faz do contrato o único lugar onde o dado da origem ganha tipo
  ([ADR-0004](0004-contrato-da-fonte-na-fronteira.md)).
- **Com dono:** cada tabela tem um model ActiveRecord no namespace do contexto que escreve nela.
  As tabelas da ingestão ficam em `app/models/ingestion/`, no schema `public`
  ([ADR-0014](0014-camadas-medallion-no-nome-da-tabela.md)). O model não declara o nome da
  tabela: o Rails deriva `alloyal_raw_orders` de `Ingestion::AlloyalRawOrder`.
- **O schema do banco é versionado em `db/structure.sql`**, e não em `db/schema.rb`. O
  `schema.rb` não representa views, e a conciliação usa uma
  ([ADR-0016](0016-curated-append-only-e-view.md)).
- **Migrations são escritas, não inferidas.** `bin/rails generate migration NomeDaMudanca`
  cria o arquivo com o timestamp; o conteúdo (`up`/`down` ou `change`) é escrito à mão e lido
  antes do `bin/rails db:migrate`.

## Consequências

- Toda migration aplicada atualiza o `db/structure.sql`. O diff dele no commit mostra
  exatamente o que mudou no banco.
- Um comando que o ActiveRecord não expressa (como uma view) entra na
  migration com `execute`, com o inverso escrito no `down`.
- O código não impõe somente leitura na origem. Isso depende das permissões do usuário do
  `ALLOYAL_SOURCE_DB_URL` (questão em aberto no design-doc).
