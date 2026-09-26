# ADR-0018 — Conciliação em camadas, com módulos por afiliadora

- **Status:** Aceito
- **Data:** 2026-09-25
- **Decisão de negócio relacionada:** [BDR-0009](../bdr/0009-conciliacao-por-afiliadora-app-alloyal-pivo.md)

## Contexto

A ingestão tem um papel só: trazer o dado. A conciliação é onde nasce a regra de negócio. Ela
precisa de uma forma nomeada desde o início e vai ter mais de um entrypoint: job, front e,
depois, CLI.

## Decisão

- **Arquitetura em camadas**, no estilo do Rails:

  | Papel | Responsabilidade | No Rails |
  |---|---|---|
  | Entrypoint | recebe o estímulo e chama o service | controller (HTTP), tarefa `rake` (job, CLI) |
  | Service | a regra | classe em `app/services/` |
  | Model | a tabela e a persistência (padrão Active Record: entidade e repositório juntos) | `app/models/` |
  | Contrato | formato do que entra e do que sai (ex.: a linha do Lojista Alloyal) | `ActiveModel` em `app/contracts/` |

- **A dependência aponta para dentro:** entrypoint → service → model. Nunca o contrário.
- **Controller e tarefa `rake` não têm regra.** Eles só chamam o service.
- **Sem injeção de dependência.** Os testes usam substituição de método
  ([ADR-0011](0011-seam-de-teste-por-substituicao-de-funcao.md)).
- **Estrutura:**
  - models em `app/models/reconciliation/` (ex.: `Reconciliation::MagaluRefinedOrder`);
  - services em `app/services/reconciliation/magalu/`: `candidates.rb`, `links.rb`,
    `remittance.rb` e `anomalies.rb`;
  - contratos em `app/contracts/reconciliation/magalu/` (ex.: a linha do Lojista Alloyal);
  - jobs em `lib/tasks/`, rodando com `bin/rails <tarefa>`;
  - o front em TypeScript chama os controllers por HTTP.
- **Nada é compartilhado entre afiliadoras** antes de existir uma segunda afiliadora que precise.

## Consequências

- Vários entrypoints chamam o mesmo service, então a regra fica num lugar só.
- A camada HTTP é Rails; o front é TypeScript. A regra nunca é reescrita no front.
