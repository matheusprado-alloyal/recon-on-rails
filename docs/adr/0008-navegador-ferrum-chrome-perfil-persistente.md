# ADR-0008 — Navegador: Selenium remoto, Chrome real em container próprio, perfil persistente

- **Status:** Aceito
- **Data:** 2026-09-24 (reescrito em 2026-09-28: Selenium remoto no lugar do Ferrum local)
- **Decisão de negócio relacionada:** [BDR-0007](../bdr/0007-sessao-magalu-sem-job.md)

## Contexto

O login da Magalu é protegido por anti-bot (PerimeterX). Automação sem disfarce é bloqueada.
A operação considera indispensáveis, por experiência com o legado: navegador disfarçado e perfil
persistente. O legado (`recon_alloyal`) passa sozinho, sem captcha, com o **patchright** (um
Playwright que remove os sinais de automação) e o Chrome real, headless, com UA forçado.

Pôr o Chrome na imagem da aplicação deixa a imagem pesada e faz todo deploy (mesmo sem relação
com o navegador) pagar o build do browser. Separar a ingestão em vários serviços nossos, por outro
lado, multiplica os deploys.

## Decisão

- Gem **`selenium-webdriver`**, em modo **remoto** (`Selenium::WebDriver.for :remote`), contra o
  container oficial **`selenium/standalone-chrome`** (Chrome real, não Chromium), no mesmo
  `docker-compose` da aplicação. A aplicação o encontra por `SELENIUM_URL`. A imagem da aplicação
  **não tem navegador**, e o navegador pode ser usado por outros serviços.
- **Tag fixa** da imagem (`docker/chrome/Dockerfile`), nunca `latest`. O Dockerfile só existe para
  criar a pasta do perfil com o dono `seluser` (um volume nomeado herda o dono da pasta da imagem).
  O build é de uma camada, cacheado, e não toca a imagem da aplicação.
- **Headless** em produção, pela constante `Ingestion::Magalu::Session::HEADLESS`. Em dev, troca-se
  para `false` e acompanha-se o login pelo noVNC do container (`http://localhost:7900`).
- **User-agent** derivado do próprio Chrome ([ADR-0007](0007-user-agent-gravado-com-a-sessao.md)).
- **Opções do Chrome**, a união do que o ADR e o legado usavam, mais o que o Selenium precisa para
  esconder o chromedriver:
  - `--no-sandbox`, `--disable-setuid-sandbox`, `--disable-dev-shm-usage`,
    `--disable-blink-features=AutomationControlled`, `--window-size=1366,768`;
  - `--user-agent=<ADR-0007>` e `--user-data-dir=/home/seluser/browser-profile`;
  - `excludeSwitches: ["enable-automation"]` e `useAutomationExtension: false`.
- **Perfil persistente** no volume `browser_profile`, dentro do container do navegador.
- **`hostname` fixo** no compose: a trava do perfil (`SingletonLock`) é `<hostname>-<pid>`; com o
  mesmo hostname e o processo morto, o próprio Chrome reassume o perfil depois de um crash. Nenhum
  script de limpeza.
- **`SE_NODE_MAX_SESSIONS: 1`**: uma sessão de navegador por vez.
- **Fluxo:** direto ao SSO (`id.magalu.com`, com o e-mail na URL), **sem aquecer a home**. O login
  roda num laço de até 12 passos que reage à tela que aparece. Se falhar, uma nova tentativa depois
  de 30 s, e só uma; nunca depois de captcha nem de credencial ausente.
- **Comportamento humano:** pausas sorteadas e digitação letra por letra com intervalo sorteado.
- **Seletores do legado**, do mais estável ao mais frágil: `input[type='email'],
  input[name='email'], input[name='login'], #login-input`; `input[type='password'],
  input[name='password'], #password-input`; botão `submit` ou com o texto `Continuar`/`Entrar`,
  senão `Enter`.
- **Falhas com motivo**: credencial ausente, captcha, campo de e-mail/senha não encontrado, SSO não
  concluído, `sessionid` não extraído. Toda mensagem cita a versão do Chrome.

## Alternativas avaliadas e descartadas

### Ferrum + Chrome num estágio do Dockerfile da aplicação (desenho anterior)
- **Prós:** CDP puro, sem chromedriver (o mesmo princípio do patchright).
- **Por que não:** a imagem da aplicação carrega o navegador e todo deploy o rebuilda.

### Ferrum remoto por CDP (Chrome com `--remote-debugging-port` em container próprio)
- **Prós:** mantém o CDP sem chromedriver.
- **Por que não:** exige manter um container nosso (entrypoint, exposição da porta de debug, sem
  noVNC pronto). Continua sendo o **plano B** se o chromedriver for detectado: muda só o corpo de
  `login_and_capture`.

### Híbrido (Selenium Grid cria a sessão, Ferrum pluga no `se:cdp`)
- **Por que não:** soma a complexidade das duas bibliotecas.

### Navegador sob demanda (a ingestão sobe e derruba o container)
- **Prós:** nenhuma memória parada entre logins (~48 h).
- **Por que não:** a aplicação precisaria controlar o Docker; o container fica sempre de pé.

### Gem de stealth nativa em Ruby
- **Por que não:** não há uma mantida (`undetected-chromedriver` e `selenium-stealth` são Python).
  O disfarce fica nas opções acima.

### Aquecer a home antes do SSO
- **Por que não:** o legado fazia; a operação o considera desnecessário. Menos tráfego, menos
  superfície para o anti-bot.

### Limpar `Singleton*` do perfil ao subir o container (lição do legado)
- **Por que não:** o `hostname` fixo resolve a mesma causa sem script.

## Consequências

- **O perfil é um segredo:** guarda a sessão logada da conta de afiliado. Vive só no volume do
  container do navegador, nunca no repositório.
- Um perfil marcado pelo anti-bot contamina as tentativas seguintes. Depois de um bloqueio, o
  volume `browser_profile` deve ser apagado antes de tentar de novo.
- Logins forçados em sequência atraem captcha. A sessão dura cerca de 48 h
  ([ADR-0006](0006-sessao-magalu-singleton-sob-demanda.md)), então login só quando necessário.
- O chromedriver deixa sinais que o patchright escondia. A receita precisa ser validada num login
  real: primeiro em dev, com tela; depois em produção, headless. Se o headless for bloqueado e o
  com tela passar, produção roda com `HEADLESS = false` no Xvfb do próprio container.
- Com um segundo consumidor do navegador, o login pode esperar na fila do Grid; subir
  `SE_NODE_MAX_SESSIONS` quando isso acontecer.
