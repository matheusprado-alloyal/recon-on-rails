# Alloyal Backbone

Base de dados e processos que reúne os pedidos do App Alloyal e os pedidos das afiliadoras (a
primeira é a Magalu, magazinevoce.com.br) para a conciliação de cashback. Existe porque hoje ninguém sabe, de forma
confiável, se um pedido de cashback da Alloyal foi de fato faturado pela Magalu.

## Language

**App Alloyal (core)**:
O sistema da Alloyal onde a compra nasce. Fonte única, que não muda, contra a qual toda
afiliadora é comparada (o pivô da conciliação).
_Avoid_: Alloyal (a empresa tem vários microserviços; seja específico).

**Pedido do App Alloyal**:
Uma compra feita através do App Alloyal, identificada por `number` (no contrato do Lojista
Alloyal, `order_number`). Imutável: uma vez gravado, nunca é atualizado — só a chegada de um
pedido novo com o mesmo `number` é ignorada. O `organization_name` diz a afiliadora e nunca é
nulo nem muda.
_Avoid_: Pedido Alloyal, order, transação, venda.

**Afiliadora**:
O programa por onde a compra passa: Magalu, Shopee, Awin, Rakuten, CityAds etc. Cada uma tem as
suas próprias regras de vínculo e as suas próprias tabelas.
_Avoid_: Afiliada, loja, lojista.

**Pedido Magalu**:
O mesmo evento de compra, visto do lado da Magalu, identificado por `ml_order_id`. Parcialmente
mutável: `billed` e `commission` mudam depois que o pedido já existe (faturamento tardio,
cancelamento); os demais campos não.
_Avoid_: Magalu order, venda Magalu.

**Ingestão bruta**:
Trazer um pedido da fonte para o Postgres do backbone exatamente como ele chegou, guardando a
linha original inteira (`raw_payload`) ao lado dos campos promovidos. Não interpreta regra de
negócio — só valida o contrato da fonte.
_Avoid_: Import, sincronização, ETL.

**Campo promovido**:
Um campo do `raw_payload` que ganha uma coluna própria, tipada, porque outra parte do sistema
precisa dele diretamente (cruzamento, filtro, índice).
_Avoid_: Campo extraído, campo mapeado.

**Invariante**:
Uma regra que todo pedido deveria respeitar (ex.: todo Pedido do App Alloyal tem `user_name`). Quando
violada, é registrada como erro (`Rails.logger.error`) — nunca bloqueia a gravação nem descarta o
pedido.
_Avoid_: Validação, constraint (isso é o contrato da fonte; invariante é a regra de negócio por
cima dele).

**Contrato da fonte**:
O formato que uma fonte externa promete entregar (quais campos existem, o fuso do `created_at`,
o que é opcional). Mora na fronteira da ingestão — a classe de contrato (`*OrderContract`) é esse
contrato. A ingestão não sabe regra de negócio, só sabe o contrato.
_Avoid_: Schema (é o nome da classe; contrato é o conceito de negócio por trás dela).

**Sessão Magalu**:
O cookie `sessionid` de uma conta de afiliado logada na Magalu, sem o qual a API de pedidos não
responde. Singleton: existe no máximo uma sessão guardada por vez, renovada sob demanda — nunca
por agendamento.
_Avoid_: Token, credencial (a sessão é o par `sessionid` + `user_agent` juntos, nunca um sem o
outro).

**Marca d'água (watermark)**:
Até quando a ingestão de pedidos Magalu já está em dia. Avança só quando um job termina com
sucesso; por causa do faturamento tardio, o próximo job relê uma janela de 90 dias antes dela,
não só o que é estritamente novo.
_Avoid_: Cursor, checkpoint, offset.

**Bloqueio anti-bot**:
Quando a Magalu, em vez de responder com o pedido ou pela sessão, devolve uma página de desafio
(captcha) — às vezes com HTTP 200, não 401. Distinto de sessão recusada: sessão recusada tem
solução (renovar); bloqueio anti-bot não tem solução automática.
_Avoid_: Rate limit, erro de rede.

**Conciliação**:
O processo de ligar cada pedido de uma afiliadora a um Pedido do App Alloyal e informar o
resultado ao Lojista Alloyal. É o motivo de o backbone existir. Está desenhado (ADR-0014 a 0019,
BDR-0009 a 0014), mas ainda não implementado; hoje só a ingestão existe.
_Avoid_: Reconciliação (usado no código/pastas), match, cruzamento — mantenha "conciliação" no
texto corrido; `reconciliation` é só o nome do pacote em inglês.

**Candidato**:
Um par possível entre um Pedido do App Alloyal e um pedido de afiliadora, sugerido pela máquina
com nota e rótulo (autoaprovado, escolha do modelo). Não muda estado nenhum. Candidatos podem se
sobrepor.
_Avoid_: Match, sugestão aprovada.

**Vínculo de pedidos**:
O par entre um Pedido do App Alloyal e um pedido de afiliadora, confirmado pelo analista. Cada
pedido tem no máximo um vínculo ativo. Pode ser devolvido para candidatos até a confirmação de
import; depois disso, só a operação corrige, por SQL.
_Avoid_: Perfil unificado, match.

**Lojista Alloyal**:
O banco de dados externo que recebe o import curado. É externo porque o backbone não é dono
dele, mesmo sendo da Alloyal: todo terceiro é externo, mas nem todo externo é terceiro.
_Avoid_: Lojista (sozinho), cliente, parceiro.

**Status informado**:
Um `transaction_status` (`pending` ou `canceled`) de um vínculo, incluído numa remessa para o
Lojista Alloyal. Não depende do canal. Nunca é reescrito.
_Avoid_: Export.

**Arquivo de remessa**:
O CSV gerado sob demanda com os status informados ainda não confirmados. Continua como
redundância quando existir envio por API.
_Avoid_: Export CSV.

**Confirmação de import**:
O operador atesta que o Lojista Alloyal importou os status informados até uma data. Funciona
como uma marca d'água que só um humano avança.
_Avoid_: Retorno.

**Anomalia**:
Situação fora do padrão que o sistema registra e avisa para um humano decidir. Hoje o único tipo
é o `billed` que volta de false para true.
_Avoid_: Erro, alerta.

**Camada (raw, refined, curated)**:
Onde o dado mora conforme é refinado (medallion). `raw` fala a língua da fonte, `refined` a
nossa, `curated` a do consumidor (os nomes do contrato do Lojista Alloyal).
_Avoid_: bronze, silver, gold no código e nos nomes de tabela.

**Setor**:
Uma das quatro áreas da operação que o backbone atende (Cashback, Suporte, Infraestrutura,
Deployment). O Cashback é o primeiro a ser construído; os demais vêm depois.
_Avoid_: Squad, time, domínio (setor é organizacional, não um Bounded Context de código).

**Legado**:
O sistema anterior ("Bastidor") e seu design doc. É hipótese a confirmar contra o estado real
— nunca fonte de verdade. Uma afirmação do legado só entra neste projeto depois de confirmada
pelo código, pelo banco ou pela operação.
_Avoid_: Sistema antigo, versão anterior.
