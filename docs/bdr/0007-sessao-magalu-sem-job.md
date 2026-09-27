# BDR-0007 — Sessão Magalu: login humano, sob demanda, sem job, para não irritar o anti-bot

- **Status:** Aceito
- **Data:** 2026-09-23 (navegador revisto em 2026-09-24)

## Contexto

Sem o `sessionid` da Magalu não existe coleta de pedidos. A captura dele é uma tarefa
secundária ("side quest"): só é chamada quando o scraper precisa. O login da Magalu tem
anti-bot, então precisa ser feito como uma pessoa faria: abrir o navegador, digitar, esperar,
clicar.

- URL de login: `https://www.magazinevoce.com.br/login/conta`
- Credenciais no `.env`: `MAGALU_EMAIL` e `MAGALU_SENHA`

## Decisão

- **Sem job agendado.** A sessão só é renovada quando se prova necessária (não existe, venceu,
  ou a API respondeu 401). O objetivo é **não irritar o anti-bot**: o único contato com o login
  é o estritamente necessário.
- A sessão fica numa **linha do Postgres** do Cashback, porque o processo
  só existe por causa da coleta de pedidos da Magalu (`magalu_raw_orders`).
- São **indispensáveis**, pela experiência da operação com o legado: navegador disfarçado,
  perfil de navegador persistente e aquecer a home antes do login.
- O navegador roda no servidor, instalado junto com o processo de ingestão, e não na máquina
  de uma pessoa.
- Quando aparecer um captcha, **uma pessoa resolve**.

## Consequências

- Técnicas: [ADR-0006](../adr/0006-sessao-magalu-singleton-sob-demanda.md),
  [ADR-0007](../adr/0007-user-agent-gravado-com-a-sessao.md),
  [ADR-0008](../adr/0008-navegador-ferrum-chrome-perfil-persistente.md).
- A receita do legado ([ADR-0008](../adr/0008-navegador-ferrum-chrome-perfil-persistente.md)) passa
  sem captcha; a pessoa só entra se o captcha aparecer.
