# BDR-0010 — Candidatos Magalu: janela de tempo, nota do nome e modelo semântico

- **Status:** Aceito
- **Data:** 2026-09-25

## Contexto

Não existe chave comum entre o pedido do App Alloyal e o Pedido Magalu. O identificador do App
Alloyal vai para a Magalu no link (`?xtra=`), mas a API de pedidos não o devolve. A operação liga
os dois lados pelo nome do cliente e pela proximidade do horário. O pedido do App Alloyal sempre
acontece antes (clique, depois compra).

## Decisão

- **Varredura:** qualquer Pedido Magalu sem vínculo ativo, com `billed` true ou false.
- **Escopo:** só entram pedidos do App Alloyal com `organization_name = 'Magalu'`.
- **Janela de candidatos:** o `created_at` do App Alloyal fica entre o `created_at` da Magalu
  menos 72 h e o próprio `created_at` da Magalu.
- **Autoaprovado:** nota de similaridade do nome (0 a 100) ≥ 90 **e** diferença de até 12 h.
- **Abaixo disso:** os 3 melhores candidatos dentro de 72 h vão para um modelo semântico, que
  escolhe um.
- "Autoaprovado" e "escolha do modelo" são **só rótulos** no candidato. Eles não mudam estado
  nenhum. Quem aprova de verdade é o analista ([BDR-0011](0011-vinculo-de-pedidos-confirmado-pelo-analista.md)).
- Um par que o analista já devolveu nunca volta a ser candidato.

## Consequências

- A comparação de horários depende dos fusos assumidos na ingestão: UTC no App Alloyal e BRT na
  Magalu ([ADR-0004](../adr/0004-contrato-da-fonte-na-fronteira.md)).
- Os candidatos podem se sobrepor: o mesmo Pedido Magalu pode aparecer para mais de um pedido do
  App Alloyal. A exclusividade só vale no vínculo.
- Fica em aberto qual modelo semântico usar e onde ele roda.
