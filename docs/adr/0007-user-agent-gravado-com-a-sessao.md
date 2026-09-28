# ADR-0007 — O user-agent do login vem do próprio Chrome e é gravado junto com a sessão

- **Status:** Aceito
- **Data:** 2026-09-24 (reescrito em 2026-09-28: sem `MAGALU_UA` no `.env`)

## Contexto

O login acontece num navegador, mas o scraper chama a API por HTTP, só com o `sessionid`.
Se as duas pontas se apresentarem com user-agents diferentes, a Magalu vê a mesma sessão
vindo de "dois computadores". O legado registra isso como causa de sessão invalidada.

Um user-agent fixo no `.env` precisa ser atualizado à mão toda vez que o Chrome muda de versão, e
esquecer isso é justamente o erro que se quer evitar. Além disso, o Chrome headless se anuncia como
`HeadlessChrome`, o que o anti-bot enxerga.

## Decisão

- O user-agent sai do **próprio Chrome do login**: uma sessão-sonda (sem perfil, numa página em
  branco, sem falar com a Magalu) lê o `navigator.userAgent`, troca `HeadlessChrome` por `Chrome` e
  fecha. A sessão de login abre com esse valor forçado (`--user-agent`).
- O mesmo valor é gravado na coluna `magalu_session.user_agent`, junto com o `sessionid`.
- As duas funções públicas da sessão devolvem `Ingestion::Magalu::Credentials`, um
  `Data.define(:session_id, :user_agent)`. O scraper usa sempre os dois juntos.
- **Alerta de atualização da imagem:** ao gravar uma sessão nova, se a versão principal do Chrome
  for diferente da versão da sessão anterior, um `Rails.logger.warn` cita as duas. Não bloqueia.

## Alternativas avaliadas e descartadas

- **`MAGALU_UA` no `.env`** (desenho anterior): sincronia manual com a versão do Chrome.
- **Trocar o UA depois de abrir, por CDP (`Network.setUserAgentOverride`):** o driver remoto do
  Selenium não tem `execute_cdp`; o `devtools` exige a gem `selenium-devtools`, amarrada à versão
  do CDP.
- **Ler a versão do `/status` do Selenium Grid:** depende de detalhe da configuração do
  docker-selenium.
- **Bloquear o login quando a versão muda:** a hipótese de trabalho é que um salto pequeno
  (152 → 153) não provoca captcha; um salto grande (140 → 150), sim. Por isso é alerta, e o erro de
  captcha cita a versão do Chrome.

## Consequências

- Login e scraper se apresentam sempre com o mesmo user-agent, sem configuração.
- Trocar a tag da imagem do navegador troca o user-agent no próximo login, com alerta no log.
- Cada login abre o Chrome duas vezes (sonda e login): alguns segundos a mais, a cada ~48 h.
- Valor observado num login real: `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36
  (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36` (sem `HeadlessChrome`).
