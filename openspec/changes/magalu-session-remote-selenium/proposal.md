# Proposal

## Why

A captura da sessão Magalu (`sessionid`) ainda não existe no Backbone, e o desenho atual (ADR-0008)
põe o Chrome num estágio do Dockerfile da aplicação. Isso deixa a imagem pesada e faz qualquer
deploy (feature ou fix sem relação com o navegador) pagar o build do browser. Separar o navegador
num container próprio, baixado e não buildado, resolve isso sem criar mais um serviço nosso para
deployar, e deixa o navegador disponível para outros consumidores.

Esta change porta para Ruby a captura de sessão do legado Python (`recon_alloyal`,
`magalu_session_manager.py`), já no desenho novo.

## What Changes

- Nova captura de sessão Magalu: sessão guardada é reusada sem abrir navegador; login só quando não
  há sessão, quando ela venceu, ou quando a renovação é forçada.
- O login roda num **Chrome remoto** (Selenium standalone, imagem oficial com tag fixa) no mesmo
  `docker-compose`, e não na imagem da aplicação. A aplicação o encontra por `SELENIUM_URL`.
- **BREAKING (docs/env):** `MAGALU_UA` sai do `.env`. O user-agent passa a ser derivado do próprio
  Chrome do container, forçado no login e gravado junto com o `sessionid` no singleton.
- Troca de versão do Chrome (tag da imagem) entre a sessão gravada e o login atual gera um **alerta
  de atualização de imagem** no log, sem bloquear.
- Fluxo de login do legado, **sem aquecer a home**: SSO direto com o e-mail na URL, laço que reage à
  tela, digitação letra por letra, erros granulares (credencial ausente, captcha, campo não
  encontrado, `sessionid` não extraído, SSO não concluído). Uma nova tentativa depois de 30 s, nunca
  depois de captcha ou credencial ausente.
- Disfarce: flags do ADR-0008 + do legado + opções do Selenium que escondem a automação.
- Compose: `chrome` passa a usar `selenium/standalone-chrome:<tag fixa>` direto (sai
  `docker/chrome/Dockerfile`), com `hostname` fixo para o Chrome reassumir o perfil depois de crash.
- Docs reescritos no lugar: ADR-0006 (ajuste), ADR-0007, ADR-0008 (com alternativas avaliadas e
  descartadas), BDR-0007, design-doc e CLAUDE.md.
- `RUNBOOK_MAGALU_SESSION.md` na raiz, temporário, com os comandos que o operador roda (nenhum
  comando é executado nesta change: só código e testes para review).

## Capabilities

### New Capabilities
- `magalu-session`: capturar, guardar e renovar sob demanda a sessão Magalu (`sessionid` +
  user-agent) por login num navegador remoto, com classificação das falhas de login.

### Modified Capabilities
<!-- Nenhuma: não há specs existentes em openspec/specs/. -->

## Impact

- **Código novo:** migração `magalu_session`, model `Ingestion::MagaluSession`,
  `Ingestion::Magalu::Credentials`, `Ingestion::Magalu::Session`, task `ingestion:magalu_session`,
  specs em `spec/services/ingestion/magalu/`.
- **Dependência:** gem `selenium-webdriver` (grupo default). Ferrum não entra.
- **Infra:** `docker-compose.yaml` (serviço `chrome`), remoção de `docker/chrome/Dockerfile`.
- **Env:** entra `SELENIUM_URL`; sai `MAGALU_UA`. Continuam `MAGALU_EMAIL` e `MAGALU_SENHA`.
- **Docs:** ADR-0006, ADR-0007, ADR-0008, BDR-0007, `docs/design-doc.md`, `CLAUDE.md`.
- **Fora:** ingestão de pedidos Magalu (`Orders`, `fetch_page`, watermark), job agendado, lock,
  cooldown, backoff, watchdog, alertas externos (Slack).
