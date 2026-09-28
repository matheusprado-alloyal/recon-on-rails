# Spec Delta

## Purpose

Garantir que a coleta de pedidos Magalu tenha uma sessão de afiliado válida (`sessionid` +
user-agent), fazendo login num navegador remoto só quando estritamente necessário, para não
irritar o anti-bot.

## ADDED Requirements

### Requirement: Sessão guardada é reusada sem abrir navegador
O sistema SHALL devolver a sessão guardada (o par `sessionid` + user-agent) sem abrir navegador
enquanto ela existir e não tiver vencido. O sistema SHALL fazer login quando não houver sessão
guardada ou quando a validade dela já tiver passado.

#### Scenario: Sessão válida guardada
- **WHEN** existe uma sessão guardada cuja validade ainda não passou
- **THEN** o sistema devolve o `sessionid` e o user-agent guardados
- **AND** nenhum login é feito

#### Scenario: Nenhuma sessão guardada
- **WHEN** não existe sessão guardada
- **THEN** o sistema faz login, guarda a sessão capturada e a devolve

#### Scenario: Sessão guardada vencida
- **WHEN** a sessão guardada tem validade no passado
- **THEN** o sistema faz login, grava a nova sessão por cima da antiga e a devolve

### Requirement: Renovação forçada
O sistema SHALL oferecer uma renovação que faz login mesmo com uma sessão válida guardada (para
quando a API responder que a sessão foi recusada), gravando o resultado por cima da sessão
anterior.

#### Scenario: Renovar com sessão válida guardada
- **WHEN** a renovação é pedida e existe uma sessão válida guardada
- **THEN** o sistema faz login e substitui a sessão guardada pela nova

### Requirement: No máximo uma sessão guardada
O sistema SHALL guardar no máximo uma sessão Magalu. Gravar uma sessão nova SHALL substituir a
anterior, nunca acumular.

#### Scenario: Duas capturas seguidas
- **WHEN** duas sessões são capturadas uma depois da outra
- **THEN** existe exatamente uma sessão guardada, a mais recente

### Requirement: O que uma sessão guarda
Cada sessão guardada SHALL conter o `sessionid`, o user-agent usado no login, a validade declarada
pelo servidor para o cookie `sessionid` e o momento do login.

#### Scenario: Sessão capturada é gravada completa
- **WHEN** um login captura um `sessionid` com validade declarada
- **THEN** a sessão guardada tem o `sessionid`, o user-agent do login, a validade do cookie e o
  momento do login

### Requirement: User-agent vem do navegador do login
O user-agent SHALL ser derivado do próprio navegador que faz o login, sem configuração externa, e
SHALL NOT anunciar modo headless. O mesmo user-agent SHALL ser forçado no navegador durante o
login e gravado com a sessão.

#### Scenario: Navegador headless
- **WHEN** o navegador do login se apresenta naturalmente como `HeadlessChrome/153.0.0.0`
- **THEN** o user-agent forçado e gravado se apresenta como `Chrome/153.0.0.0`, com o resto igual

### Requirement: Alerta de atualização do navegador
Quando a versão principal do Chrome do login atual for diferente da versão principal do
user-agent da sessão guardada, o sistema SHALL registrar um alerta de atualização da imagem do
navegador, com as duas versões, e SHALL seguir com o login normalmente.

#### Scenario: Imagem do navegador atualizada
- **WHEN** a sessão guardada foi capturada com Chrome 153 e o login atual roda em Chrome 154
- **THEN** o sistema registra um alerta citando 153 e 154
- **AND** a nova sessão é gravada normalmente

#### Scenario: Mesma versão
- **WHEN** a sessão guardada e o login atual usam a mesma versão principal do Chrome
- **THEN** nenhum alerta de atualização é registrado

### Requirement: Fluxo de login
O login SHALL ir direto à tela de SSO da Magalu com o e-mail da conta na URL, sem visitar a home
antes. O login SHALL reagir à tela que aparece (e-mail, senha, redirecionamento), digitar letra por
letra com intervalo sorteado e terminar quando o navegador voltar ao Magazine Você fora da tela de
login.

#### Scenario: Login concluído
- **WHEN** o SSO aceita e-mail e senha e redireciona ao Magazine Você fora da tela de login
- **THEN** o sistema captura o cookie `sessionid` do domínio `magazinevoce.com.br` e a validade dele

### Requirement: Falhas de login classificadas
Uma falha de login SHALL ser reportada com um motivo específico, registrado no log de erro:
credencial ausente, captcha, campo de e-mail não encontrado, campo de senha não encontrado, SSO não
concluído, ou `sessionid` não extraído (cookie ausente ou sem validade). Nenhuma falha SHALL
devolver uma sessão vazia em silêncio.

#### Scenario: Senha não configurada
- **WHEN** a senha da conta Magalu não está configurada
- **THEN** o login falha com o motivo credencial ausente
- **AND** nenhum navegador é aberto

#### Scenario: Captcha durante o login
- **WHEN** a página do SSO contém `<title>Captcha` ou `perfdrive`
- **THEN** o login falha com o motivo captcha
- **AND** a mensagem cita a versão do Chrome usada no login

#### Scenario: SSO conclui sem sessionid
- **WHEN** o SSO redireciona ao Magazine Você mas não há cookie `sessionid` com validade
- **THEN** o login falha com o motivo `sessionid` não extraído

### Requirement: Uma nova tentativa, e só uma
Depois de uma falha de login, o sistema SHALL tentar uma única vez de novo, 30 segundos depois. O
sistema SHALL NOT tentar de novo depois de captcha nem de credencial ausente.

#### Scenario: Primeira tentativa falha, segunda passa
- **WHEN** o primeiro login falha com SSO não concluído e o segundo captura a sessão
- **THEN** o sistema espera 30 segundos entre os dois e devolve a sessão do segundo

#### Scenario: Duas falhas seguidas
- **WHEN** as duas tentativas falham
- **THEN** o sistema reporta a falha da segunda e não faz uma terceira

#### Scenario: Captcha não é tentado de novo
- **WHEN** o primeiro login falha com captcha
- **THEN** o sistema reporta o captcha sem nova tentativa

### Requirement: Navegador fora da aplicação
O login SHALL usar um navegador remoto, alcançado por um endereço configurado, e não um navegador
instalado na imagem da aplicação. O navegador SHALL ser liberado ao fim de cada tentativa de login,
com sucesso ou falha.

#### Scenario: Falha no meio do login
- **WHEN** o login levanta um erro depois de abrir o navegador
- **THEN** a sessão do navegador remoto é encerrada antes de o erro seguir
