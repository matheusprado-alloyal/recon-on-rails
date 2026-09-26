# ADR-0008 — Navegador: Ferrum + Chrome real, headless, perfil persistente

- **Status:** Aceito
- **Data:** 2026-09-24
- **Decisão de negócio relacionada:** [BDR-0007](../bdr/0007-sessao-magalu-sem-job.md)

## Contexto

O login da Magalu é protegido por anti-bot (PerimeterX). Automação sem disfarce é bloqueada.
A operação considera indispensáveis, por experiência com o legado: navegador disfarçado,
perfil persistente e aquecer a home antes do login. O legado tem uma receita que passa sozinha,
sem captcha, e é essa receita que o Backbone segue.

## Decisão

- Biblioteca **Ferrum** (controle do Chrome pelo protocolo CDP), com o **Chrome real** instalado
  na máquina que roda a ingestão, e não o Chromium.
- **Headless**, com o user-agent forçado pelo `MAGALU_UA`
  ([ADR-0007](0007-user-agent-gravado-com-a-sessao.md)).
- Flags do Chrome: `--no-sandbox`, `--disable-setuid-sandbox`, `--disable-dev-shm-usage` e
  `--disable-blink-features=AutomationControlled`.
- **Perfil persistente** em `.browser_profile/` na raiz do repositório, passado como
  `user-data-dir`.
- **Fluxo:** abrir a home, depois ir direto a `id.magalu.com` com o e-mail na URL. O login roda
  num laço que reage à tela que aparece. Se falhar, uma nova tentativa depois de 30 s, e só
  uma.
- **Comportamento humano:** pausas sorteadas e digitação letra por letra com intervalo sorteado.
- Campos encontrados **pelo tipo** (`input[type='email']`, `input[type='password']`), e não pelo
  rótulo visível.

## Consequências

- **`.browser_profile/` é um segredo:** guarda a sessão logada da conta de afiliado. Precisa
  estar no `.gitignore` e nunca pode ser commitado.
- Um perfil marcado pelo anti-bot contamina as tentativas seguintes. Depois de um bloqueio, a
  pasta deve ser apagada antes de tentar de novo.
- Logins forçados em sequência atraem captcha. A sessão dura cerca de 48 h
  ([ADR-0006](0006-sessao-magalu-singleton-sob-demanda.md)), então login só quando necessário.
- **Para o servidor:** o Chrome entra num estágio do Dockerfile, só na imagem do processo de
  ingestão; o perfil vive num volume; ao subir, apagar `SingletonLock`, `SingletonCookie` e
  `SingletonSocket` do perfil (lição do legado).
