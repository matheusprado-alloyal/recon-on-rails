# BDR — Business Decision Records

Decisões de **negócio**: o que a operação decidiu, e por quê. Elas vêm de quem conhece a
operação, e não do código nem do legado. As decisões **técnicas** que elas motivam ficam em
[`../adr/`](../adr/).

| BDR | Título | Status |
|---|---|---|
| [0001](0001-nome-alloyal-backbone.md) | O sistema se chama Alloyal Backbone | Aceito |
| [0002](0002-escopo-inicial-cashback.md) | Um repositório por setor; este é o do Cashback | Aceito |
| [0003](0003-legado-e-referencia-nao-verdade.md) | O legado é referência a questionar, não fonte de verdade | Aceito |
| [0004](0004-pedido-alloyal-e-imutavel.md) | O Pedido do lado da Alloyal é identificado por `number` e é imutável | Aceito |
| [0005](0005-pedido-alloyal-sem-nome-e-recusado.md) | Pedido Alloyal sem nome é recusado | Aceito |
| [0006](0006-ingerir-todos-os-pedidos-magalu.md) | A ingestão traz todos os pedidos Magalu da Alloyal | Aceito |
| [0007](0007-sessao-magalu-sem-job.md) | Sessão Magalu: login humano, sob demanda, sem job, para não irritar o anti-bot | Aceito |
| [0008](0008-reingerir-90-dias-por-faturamento-tardio.md) | Reingestão dos últimos 90 dias, por causa do faturamento tardio | Aceito |
| [0009](0009-conciliacao-por-afiliadora-app-alloyal-pivo.md) | A conciliação é por afiliadora, com o App Alloyal como pivô | Aceito |
| [0010](0010-candidatos-magalu-janela-nome-modelo.md) | Candidatos Magalu: janela de tempo, nota do nome e modelo semântico | Aceito |
| [0011](0011-vinculo-de-pedidos-confirmado-pelo-analista.md) | Vínculo de pedidos: confirmado pelo analista, devolvível até o import | Aceito |
| [0012](0012-todo-vinculo-e-informado-ao-lojista.md) | Todo vínculo é informado ao Lojista Alloyal, como pending ou canceled | Aceito |
| [0013](0013-operador-confirma-import-do-lojista.md) | O operador confirma o import do Lojista Alloyal | Aceito |
| [0014](0014-billed-que-volta-para-true-e-anomalia.md) | billed que volta de false para true é anomalia | Aceito |
