# ADR — Architecture Decision Records

Decisões **técnicas** do Alloyal Backbone: como o sistema é construído.
As decisões de **negócio** (o que a operação decidiu) ficam em [`../bdr/`](../bdr/).

Cada ADR registra uma decisão tomada a partir do estado real do sistema. Uma decisão que
mudar ganha um ADR novo, que marca o antigo como `Substituído por ADR-XXXX`.

| ADR | Título | Status |
|---|---|---|
| [0001](0001-monorepo-monolito-modular-por-pacote.md) | Um repositório por setor, monólito modular por contexto, múltiplas unidades de implantação | Aceito |
| [0002](0002-banco-unico-tabelas-com-dono.md) | Um Postgres, cada tabela com um contexto dono | Aceito |
| [0003](0003-ingestao-bruta-imutavel.md) | Ingestão bruta e imutável, com o id da fonte | Aceito |
| [0004](0004-contrato-da-fonte-na-fronteira.md) | O contrato da fonte mora na fronteira; a ingestão não conhece regra de negócio | Aceito |
| [0005](0005-pedido-recusado-e-registrado.md) | Pedido recusado pelo contrato é registrado no log, e o fluxo segue | Aceito |
| [0006](0006-sessao-magalu-singleton-sob-demanda.md) | Sessão Magalu: singleton no Postgres, renovada sob demanda | Aceito |
| [0007](0007-user-agent-gravado-com-a-sessao.md) | O user-agent do login vem do próprio Chrome e é gravado junto com a sessão | Aceito |
| [0008](0008-navegador-ferrum-chrome-perfil-persistente.md) | Navegador: Selenium remoto, Chrome real em container próprio, perfil persistente | Aceito |
| [0009](0009-testes-exercitam-o-nosso-codigo.md) | Testes exercitam o nosso código, contra um Postgres real | Aceito |
| [0010](0010-conventional-commits.md) | Conventional Commits, um commit por intenção | Aceito |
| [0011](0011-seam-de-teste-por-substituicao-de-funcao.md) | Seam de teste por substituição de método, não injeção de dependência | Aceito |
| [0012](0012-ingestao-magalu-por-watermark.md) | Ingestão Magalu incremental por marca d'água, parada na janela de 90 dias | Aceito |
| [0013](0013-anti-bot-pelo-corpo-da-resposta.md) | Bloqueio anti-bot detectado pelo corpo da resposta, não só pelo status HTTP | Aceito |
| [0014](0014-camadas-medallion-no-nome-da-tabela.md) | Camadas medallion no nome da tabela | Aceito |
| [0015](0015-exclusividade-por-constraint.md) | Exclusividade garantida por constraint no banco, não por código | Aceito |
| [0016](0016-curated-append-only-e-view.md) | Curated append-only, com o estado atual calculado por view | Aceito |
| [0017](0017-anomalias-em-tabela-de-controle.md) | Anomalias em tabela de controle, detectadas na conciliação | Aceito |
| [0018](0018-reconciliation-em-camadas-por-afiliadora.md) | Conciliação em camadas, com módulos por afiliadora | Aceito |
| [0019](0019-campos-exigidos-pela-conciliacao-not-null.md) | `total` e `organization_name` são NOT NULL | Aceito |
