# ADR-0013 — Bloqueio anti-bot detectado pelo corpo da resposta, não só pelo status HTTP

- **Status:** Aceito
- **Data:** 2026-09-24
- **Decisão técnica relacionada:** [ADR-0008](0008-navegador-ferrum-chrome-perfil-persistente.md)
  (o anti-bot, PerimeterX, já é conhecido do login)

## Contexto

`fetch_page` (`Ingestion::Magalu::Orders`) pode receber um HTTP 200 que não é o
JSON esperado: é a página de desafio do anti-bot. Tratar isso como uma resposta válida faria a
ingestão interpretar `payload['objects']` de uma página HTML como se fosse a lista de pedidos.

## Decisão

- Um 401 vira `Ingestion::Magalu::SessionRejectedError` — problema de sessão, com solução (renovar).
- Um 200 cujo corpo contém `'<title>Captcha'` ou `'perfdrive'` vira `Ingestion::Magalu::BlockedByAntiBotError` —
  problema sem solução automática, distinto de sessão recusada.
- A checagem do corpo acontece **sempre**, mesmo em 200, antes de tentar `JSON.parse`.

## Consequências

- Um bloqueio anti-bot não é confundido com "página vazia de pedidos".
- A detecção depende de strings literais da página atual de captcha da Magalu; se a página
  mudar, a detecção para de funcionar silenciosamente (o teste em
  `test/services/ingestion/magalu/orders_test.rb` fixa essas strings, então uma mudança aparece como
  teste quebrado, não como bug em produção sem aviso).
