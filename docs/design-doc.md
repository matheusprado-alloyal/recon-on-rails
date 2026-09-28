# Alloyal Backbone — Design Doc

> **Status: LEGADO E VIVO.**
> Este documento é legado (nasceu do design doc "Bastidor") e vivo (é atualizado a cada decisão).
> Ele **só será aprovado a partir do estado real do sistema**: uma seção só vale quando o código,
> o banco e a operação confirmam o que ela diz. O que ainda não foi confirmado está marcado como
> **hipótese** ou listado em [Questões em aberto](#9-questões-em-aberto). A [seção 8](#8-o-que-mudou-em-relação-ao-design-doc-legado-bastidor)
> é o lugar onde uma afirmação do legado é confirmada ou descartada, à medida que aparece.

- **Última atualização:** 2026-09-26
- **Decisões técnicas:** [`adr/`](adr/README.md) · **Decisões de negócio:** [`bdr/`](bdr/README.md)
  · **Glossário:** [`CONTEXT.md`](../CONTEXT.md)

---

## 1. O que é

O Alloyal Backbone é a base de dados e processos que reúne os pedidos do **App Alloyal** e os
pedidos das afiliadoras (a primeira é a **Magalu**) para a conciliação de cashback. Cada setor
da operação tem o seu repositório; este é o do Cashback
([BDR-0002](bdr/0002-escopo-inicial-cashback.md)).

O nome anterior, "Bastidor", foi abandonado ([BDR-0001](bdr/0001-nome-alloyal-backbone.md)).

## 2. Escopo atual

| Setor | Situação |
|---|---|
| **Cashback** | Em construção. Ingestão e conciliação desenhadas; a implementação começa pelo M0 ([seção 7](#7-próximos-passos)). |
| Suporte | Depois. |
| Infraestrutura | Amadurecendo. |
| Deployment | Fora do escopo por enquanto. |

Princípios: KISS, YAGNI, um processo e um passo por vez. O legado é hipótese a confirmar, não
verdade ([BDR-0003](bdr/0003-legado-e-referencia-nao-verdade.md)).

## 3. Arquitetura

Três eixos independentes ([ADR-0001](adr/0001-monorepo-monolito-modular-por-pacote.md)):

| Eixo | Decisão |
|---|---|
| Repositório | Um por setor; este é o do Cashback: a aplicação Rails e o front em TypeScript |
| Código | Monólito modular por contexto (namespaces `Ingestion` e `Reconciliation`) |
| Execução | Múltiplas unidades de implantação: jobs (`rake`), servidor HTTP, front |

Estrutura planejada:

```
recon-on-rails/
├── app/
│   ├── contracts/
│   │   ├── ingestion/          # AlloyalOrderContract, MagaluOrderContract
│   │   └── reconciliation/     # linha do Lojista Alloyal
│   ├── controllers/            # entrypoints HTTP para o front (M6)
│   ├── models/
│   │   ├── ingestion/          # AlloyalRawOrder, MagaluRawOrder, MagaluOrdersWatermark, MagaluSession
│   │   └── reconciliation/     # tabelas refined, curated e de controle da conciliação
│   └── services/
│       ├── ingestion/
│       │   ├── alloyal/        # ingestão dos pedidos do App Alloyal
│       │   └── magalu/         # sessão (Selenium remoto) e pedidos (watermark, paginação, anti-bot)
│       └── reconciliation/
│           └── magalu/         # candidates, links, remittance, anomalies
├── config/database.yml          # banco do Cashback (a origem do App Alloyal fica fora, via pg)
├── db/
│   ├── migrate/
│   └── structure.sql
├── lib/tasks/                  # jobs: ingestion:alloyal, ingestion:magalu_session, ingestion:magalu_orders
├── spec/                       # espelha app/
├── docs/                       # este documento, adr/, bdr/, agents/
├── CONTEXT.md                  # glossário do domínio
└── docker-compose.yaml         # Postgres 17 de desenvolvimento
```

- Um Postgres só; cada tabela tem um contexto dono
  ([ADR-0002](adr/0002-banco-unico-tabelas-com-dono.md)).
- A conciliação é organizada em camadas, com um módulo por afiliadora
  ([ADR-0018](adr/0018-reconciliation-em-camadas-por-afiliadora.md)).

## 4. Fontes externas

| Fonte | Acesso | Situação |
|---|---|---|
| Banco do App Alloyal (tabela `orders`) | Somente leitura, `ALLOYAL_SOURCE_DB_URL`, gem `pg` direto | A ingerir |
| API de pedidos da Magalu (`/v1/showcase/orders`, `magazinevoce.com.br`) | Cookie `sessionid` da conta de afiliado | A ingerir, incremental por marca d'água |

## 5. Modelo de dados

Schema `public`: o banco é só do Cashback ([ADR-0014](adr/0014-camadas-medallion-no-nome-da-tabela.md)).

**`alloyal_raw_orders`** — o Pedido do App Alloyal, imutável
([ADR-0003](adr/0003-ingestao-bruta-imutavel.md), [BDR-0004](bdr/0004-pedido-alloyal-e-imutavel.md))

| Coluna | Tipo | Regra |
|---|---|---|
| `id` | `BIGINT` PK | id da Alloyal, nunca gerado pelo banco |
| `number` | `VARCHAR(100)` | `NOT NULL`, `UNIQUE`: identificador do pedido |
| `organization_name` | `VARCHAR(255)` | `NOT NULL`: a afiliadora ([ADR-0019](adr/0019-campos-exigidos-pela-conciliacao-not-null.md)) |
| `user_name` | `VARCHAR(255)` | `NOT NULL`: chave do match, junto com o `number` ([BDR-0005](bdr/0005-pedido-alloyal-sem-nome-e-recusado.md)) |
| `business_name` | `VARCHAR(255)` | promovido da fonte |
| `discount_type`, `cashback_type` | `VARCHAR(50)` | promovidos da fonte |
| `discount_value`, `cashback_value` | `NUMERIC(10,2)` | promovidos da fonte |
| `created_at` | `TIMESTAMPTZ` | assumido UTC ([ADR-0004](adr/0004-contrato-da-fonte-na-fronteira.md)) |
| `raw_payload` | `JSONB` | a linha original inteira |
| `ingested_at` | `TIMESTAMPTZ` | `now()` na gravação |

**`magalu_raw_orders`** — o Pedido Magalu, parcialmente mutável
([ADR-0012](adr/0012-ingestao-magalu-por-watermark.md), [BDR-0008](bdr/0008-reingerir-90-dias-por-faturamento-tardio.md))

| Coluna | Tipo | Regra |
|---|---|---|
| `ml_order_id` | `VARCHAR(100)` PK | identificador do pedido na Magalu |
| `id` | `BIGINT` | id do registro na API da Magalu |
| `ml_customer_name` | `VARCHAR(255)` | `NOT NULL`: nome do cliente |
| `billed` | `BOOLEAN` | `NOT NULL`; **muda depois de gravado** (cancelamento) |
| `total` | `NUMERIC(12,2)` | `NOT NULL`: o `order_amount` do Lojista Alloyal ([ADR-0019](adr/0019-campos-exigidos-pela-conciliacao-not-null.md)) |
| `commission` | `NUMERIC(12,2)` | muda junto com `billed` |
| `created_at` | `TIMESTAMPTZ` | assumido BRT sem fuso (premissa, [Questão em aberto](#9-questões-em-aberto)) |
| `raw_payload` | `JSONB` | a linha original inteira |
| `ingested_at`, `updated_at` | `TIMESTAMPTZ` | `updated_at` só é gravado quando `billed`/`commission` mudam |

**`magalu_orders_watermark`** — singleton, até quando a ingestão de pedidos está em dia
([ADR-0012](adr/0012-ingestao-magalu-por-watermark.md))

| Coluna | Tipo | Regra |
|---|---|---|
| `id` | `INTEGER` PK | sempre `1`, `CHECK (id = 1)` |
| `last_success_at` | `TIMESTAMPTZ` | início do último job que terminou com sucesso |

**`magalu_session`** — singleton da sessão Magalu
([ADR-0006](adr/0006-sessao-magalu-singleton-sob-demanda.md))

| Coluna | Tipo | Regra |
|---|---|---|
| `id` | `INTEGER` PK | sempre `1`, `CHECK (id = 1)` |
| `session_id` | `TEXT` | o cookie `sessionid` |
| `user_agent` | `TEXT` | o user-agent do Chrome usado no login ([ADR-0007](adr/0007-user-agent-gravado-com-a-sessao.md)) |
| `expires_at` | `TIMESTAMPTZ` | o `Expires` do cookie |
| `captured_at` | `TIMESTAMPTZ` | o momento do login |

As tabelas da conciliação estão no [ADR-0014](adr/0014-camadas-medallion-no-nome-da-tabela.md).

## 6. Fluxos da ingestão (desenhados)

### 6.1 Ingestão do App Alloyal

```
banco do App Alloyal (orders, Magalu, via pg) → AlloyalOrderContract → recusados (log) → alloyal_raw_orders
```

1. Lê todos os pedidos com `organization_name = 'Magalu'`, com a gem `pg`, direto; todo valor chega como texto ([BDR-0006](bdr/0006-ingerir-todos-os-pedidos-magalu.md)).
2. Valida cada linha pelo contrato; `created_at` sem fuso recebe UTC.
3. Contrato inválido (sem `user_name`, sem `organization_name` ou com payload só de campos promovidos) é registrado no log e fica de fora; o fluxo segue ([ADR-0005](adr/0005-pedido-recusado-e-registrado.md)).
4. Grava com `insert_all(..., unique_by: :number)` (`ON CONFLICT (number) DO NOTHING`).

Execução: `bin/rails ingestion:alloyal`.

### 6.2 Sessão Magalu (sob demanda)

```
scraper → get_credentials → API Magalu
                              ├─ 200: segue
                              └─ 401: renew_credentials → uma nova tentativa
```

- Selenium remoto contra o container `selenium/standalone-chrome` (Chrome real, tag fixa), fora da
  imagem da aplicação; **headless** em produção, com tela em dev (noVNC); perfil persistente no
  volume do container; direto a `id.magalu.com` com o e-mail na URL, sem aquecer a home; login em
  laço que reage à tela; uma nova tentativa depois de 30 s, nunca depois de captcha
  ([ADR-0008](adr/0008-navegador-ferrum-chrome-perfil-persistente.md)).
- User-agent derivado do próprio Chrome e gravado com a sessão; troca de versão do Chrome gera
  alerta de atualização da imagem ([ADR-0007](adr/0007-user-agent-gravado-com-a-sessao.md)).
- Captcha, quando aparece, é resolvido por uma pessoa ([BDR-0007](bdr/0007-sessao-magalu-sem-job.md)).
- Validade observada da sessão: 48 horas a partir do login (declarada pelo servidor).

Execução: `bin/rails ingestion:magalu_session` (ou `"ingestion:magalu_session[force]"` para renovar).

### 6.3 Ingestão dos pedidos Magalu

```
get_credentials → fetch_page(query) ──┬─ 200 JSON: contrato → save_orders
                                        ├─ 401: renew_credentials → tenta 1x de novo
                                        └─ 200 com corpo de captcha: BlockedByAntiBotError
                      │
                      └─ meta.next ainda existe e não cruzou a janela de 90 dias? próxima página
                                        │
                                        └─ fim da paginação → save_watermark(started_at)
```

1. `get_credentials` traz a sessão guardada (ou renova).
2. Pagina do pedido mais novo para o mais antigo (`order_by=-created_at`), parando quando
   encontra um pedido anterior a `watermark - 90 dias`
   ([ADR-0012](adr/0012-ingestao-magalu-por-watermark.md), [BDR-0008](bdr/0008-reingerir-90-dias-por-faturamento-tardio.md)).
3. Cada pedido é validado pelo contrato (`MagaluOrderContract`); um pedido recusado é descartado
   e logado, sem travar a página.
4. `save_orders` só grava quando `billed`/`commission` mudam de fato (`IS DISTINCT FROM`).
5. Um 401 renova a sessão e tenta de novo; um 200 com página de captcha vira
   `BlockedByAntiBotError` ([ADR-0013](adr/0013-anti-bot-pelo-corpo-da-resposta.md)).
6. O watermark só avança depois que a paginação inteira termina com sucesso.

Execução: `bin/rails ingestion:magalu_orders`.

## 7. Próximos passos

### 7.1 Conciliação Magalu (desenhada)

```
magalu_raw_orders ─┐
                   ├─ candidatos (máquina) ─→ vínculo (analista) ─→ status informado ─→ remessa (CSV) ─→ Lojista Alloyal
alloyal_raw_orders ┘      refined                 refined              curated                              │
                                                                                                             ↓
                                                            confirmação de import (operador) ←─ aviso do Lojista Alloyal
```

- **Regras:** [BDR-0009](bdr/0009-conciliacao-por-afiliadora-app-alloyal-pivo.md) a
  [BDR-0014](bdr/0014-billed-que-volta-para-true-e-anomalia.md).
- **Técnica:** [ADR-0014](adr/0014-camadas-medallion-no-nome-da-tabela.md) a
  [ADR-0019](adr/0019-campos-exigidos-pela-conciliacao-not-null.md).

### 7.2 Roadmap

| Marco | Entregável |
|---|---|
| M0 — Ingestão | Aplicação Rails, tabelas raw e de controle, as três ingestões com testes |
| M1 — Boilerplate da conciliação | Tabelas refined, curated e de controle migradas, com a view, e testes rodando |
| M2 — Candidatos | Job gera candidatos reais, com nota do nome e modelo semântico |
| M3 — Vínculo | Confirmar, criar manual e devolver, com os locks provados por teste |
| M4 — Status e remessa | CSV do contrato gerado a partir de vínculos reais; confirmação de import |
| M5 — Anomalias | billed false → true gravado sem duplicata e avisado no Slack |
| M6 — API e front | O analista e o operador fazem tudo pelo front (TypeScript), até baixar a remessa |

Depois: implantação em Docker (aplicação numa imagem sem navegador; o Chrome é o serviço
`chrome` do mesmo compose, com o perfil em volume,
[ADR-0008](adr/0008-navegador-ferrum-chrome-perfil-persistente.md)).

## 8. O que mudou em relação ao design doc legado ("Bastidor")

| Legado | Estado real |
|---|---|
| Nome "Bastidor" | Alloyal Backbone |
| Pastas `shared/`, `cashback/`, `suporte/` | Uma aplicação Rails com namespaces por contexto (`Ingestion`, `Reconciliation`) |
| Schemas `raw_afiliadas`, `cashback`, `suporte` | Um repositório e um banco por setor; as tabelas ficam no `public` ([ADR-0001](adr/0001-monorepo-monolito-modular-por-pacote.md), [ADR-0014](adr/0014-camadas-medallion-no-nome-da-tabela.md)) |
| Fase 0 (Pareto de 30K tickets, sessão gravada com o analista) | **Não revalidada.** Fica fora deste documento até ser confirmada pela operação |
| Fase 1 (match em dois estágios, modo sombra, aprovação via CLI) | **Parcialmente confirmada pela operação:** nota do nome + modelo semântico, janela de 12 h/72 h ([BDR-0010](bdr/0010-candidatos-magalu-janela-nome-modelo.md)). A aprovação é pelo front, não pela CLI ([BDR-0012](bdr/0012-todo-vinculo-e-informado-ao-lojista.md)). Modo sombra não revalidado |
| `ml_order_id` normalizado removendo não-dígitos antes de cruzar | **Não revalidado.** O `ml_order_id` é gravado como veio, sem normalização — só entra se a conciliação provar que precisa |
| `billed` muda com o tempo (cancelamentos) | **Confirmado**: `magalu_raw_orders` grava só a mudança de `billed`/`commission` ([ADR-0012](adr/0012-ingestao-magalu-por-watermark.md)) |
| Navegador disfarçado, perfil persistente, Chrome real, headless, user-agent fixo | **Confirmado** no legado (patchright) como a receita que passa pelo anti-bot; no Backbone, o user-agent vem do Chrome e o navegador é Selenium remoto ([ADR-0007](adr/0007-user-agent-gravado-com-a-sessao.md), [ADR-0008](adr/0008-navegador-ferrum-chrome-perfil-persistente.md)) |

## 9. Questões em aberto

| Questão | Onde impacta |
|---|---|
| A receita de login ([ADR-0008](adr/0008-navegador-ferrum-chrome-perfil-persistente.md)) passa pelo anti-bot com o Selenium (chromedriver), em headless? | `Ingestion::Magalu::Session` |
| Qual biblioteca calcula a nota de similaridade do nome, e o limite de 90 vale nela? Calibrar com pares reais | [BDR-0010](bdr/0010-candidatos-magalu-janela-nome-modelo.md) |
| Qual modelo semântico escolhe entre os 3 candidatos abaixo de 90, e onde ele roda? | [BDR-0010](bdr/0010-candidatos-magalu-janela-nome-modelo.md) |
| O `created_at` do App Alloyal é mesmo UTC? (a coluna é `timestamp without time zone`: o fuso não vem junto) | [ADR-0004](adr/0004-contrato-da-fonte-na-fronteira.md) |
| O `created_at` da Magalu vem em BRT sem fuso, como o legado afirma? | [ADR-0004](adr/0004-contrato-da-fonte-na-fronteira.md) |
| O `ml_order_id` da Magalu tem formato estável? (o legado removia não-dígitos antes de cruzar) | Chave de `magalu_raw_orders`, conciliação |
| Perfil ainda logado faz o site pular a tela de login? | `Ingestion::Magalu::Session` |
| Como o front em TypeScript entra no chatbot do suporte | [ADR-0018](adr/0018-reconciliation-em-camadas-por-afiliadora.md) |
| Status `available` e `approved`, e o envio por API ao Lojista Alloyal | [BDR-0012](bdr/0012-todo-vinculo-e-informado-ao-lojista.md) |
| O usuário do `ALLOYAL_SOURCE_DB_URL` só tem permissão de leitura? O código não impõe isso | [ADR-0002](adr/0002-banco-unico-tabelas-com-dono.md) |
