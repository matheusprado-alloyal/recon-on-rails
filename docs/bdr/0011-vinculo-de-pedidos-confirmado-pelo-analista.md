# BDR-0011 — Vínculo de pedidos: confirmado pelo analista, devolvível até o import

- **Status:** Aceito
- **Data:** 2026-09-25

## Contexto

O **vínculo de pedidos** é o par entre um pedido do App Alloyal e um pedido de uma afiliadora,
confirmado pelo analista. Ele substitui o termo "perfil unificado": a mesma pessoa compra várias
vezes, e cada compra gera um par diferente. O nome do cliente é a evidência para achar o par,
não a identidade dele.

## Decisão

- O vínculo **nasce quando o analista confirma**. Antes disso, só existem candidatos.
- Um pedido do App Alloyal e um pedido da afiliadora têm, **cada um, no máximo um vínculo
  ativo**. O Lojista Alloyal aceitaria um par duplicado, então a garantia é nossa.
- **Vínculo manual:** quando o cliente traz uma nota fiscal, o analista cria o vínculo de um par
  específico, fora dos candidatos. O vínculo manual ignora janela e nota, mas respeita o escopo
  por `organization_name` e a exclusividade. Ele guarda só a origem `manual`.
- **Devolver para candidatos:** se o analista aprovou por engano, ele desfaz o vínculo enquanto o
  import ainda não foi confirmado ([BDR-0013](0013-operador-confirma-import-do-lojista.md)). O
  rollback é do vínculo, não do status. O pedido volta para a busca, e o par devolvido não é
  sugerido de novo.
- Se o vínculo já saiu numa remessa, o front avisa antes de devolver, para o analista confirmar
  que a remessa não foi entregue.
- **Desfazer um vínculo já importado** é uma situação atípica. O sistema não oferece essa ação:
  a operação avalia o caso e corrige por SQL.
- Nenhum vínculo é apagado. O devolvido continua gravado, como prova do engano.

## Consequências

- Técnica: [ADR-0015](../adr/0015-exclusividade-por-constraint.md) e
  [ADR-0016](../adr/0016-curated-append-only-e-view.md).
