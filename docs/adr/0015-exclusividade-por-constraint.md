# ADR-0015 — Exclusividade garantida por constraint no banco, não por código

- **Status:** Aceito
- **Data:** 2026-09-25
- **Decisão de negócio relacionada:** [BDR-0011](../bdr/0011-vinculo-de-pedidos-confirmado-pelo-analista.md)

## Contexto

Um pedido não pode estar em dois vínculos ativos, e um vínculo não pode ser informado duas vezes
com o mesmo status. Uma verificação no código ("consulta, depois grava") falha quando dois
analistas agem ao mesmo tempo.

## Decisão

| Garantia | Constraint |
|---|---|
| Um Pedido Magalu tem no máximo um vínculo ativo | índice único parcial em `magalu_refined_orders (ml_order_id)` onde o vínculo não foi devolvido |
| Um pedido do App Alloyal tem no máximo um vínculo ativo | índice único parcial em `magalu_refined_orders (number)` onde o vínculo não foi devolvido |
| Um vínculo é informado no máximo uma vez com cada status | único em `magalu_curated_statuses (vínculo, transaction_status)` |
| Uma anomalia aberta por vínculo e por tipo | índice único parcial em `magalu_anomalies (vínculo, tipo)` onde a anomalia não foi resolvida |

- O índice é **parcial** para que um vínculo devolvido não trave os seus pedidos para sempre.
- O lock dos status é **por vínculo**, não por `external_id`, porque a operação pode religar um
  pedido depois de corrigir por SQL.
- **Entre afiliadoras** não há constraint: a garantia vem por construção, porque cada afiliadora só
  enxerga os pedidos do App Alloyal com o seu `organization_name`.
- A violação de constraint (`ActiveRecord::RecordNotUnique`) vira um erro de domínio no
  service, com mensagem em português.
- No ActiveRecord, o índice parcial é declarado na migration com `add_index ..., unique: true,
  where: '...'`, sempre com `name:` explícito.

## Consequências

- Se dois analistas confirmarem o mesmo pedido ao mesmo tempo, o Postgres aceita um e recusa o
  outro. Não existe lock no código.
- Os testes de integração provam cada garantia contra o Postgres real
  ([ADR-0009](0009-testes-exercitam-o-nosso-codigo.md)).
