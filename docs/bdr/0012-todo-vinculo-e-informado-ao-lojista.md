# BDR-0012 — Todo vínculo é informado ao Lojista Alloyal, como pending ou canceled

- **Status:** Aceito
- **Data:** 2026-09-25

## Contexto

Do lado da Magalu, o `billed` sempre nasce true. Ele pode continuar true ou ir para false e ficar
em false (cancelamento). Do nosso lado, a primeira leitura pode já vir em false, porque o true
aconteceu antes de a ingestão ler. O Lojista Alloyal precisa saber de todo pedido: o que tem
impacto financeiro e o que só carrega dados.

## Decisão

- **Todo vínculo ativo vai para o Lojista Alloyal.** `billed=true` gera `pending` e
  `billed=false` gera `canceled`.
- **Transições permitidas por vínculo:** nenhuma → pending, nenhuma → canceled, pending →
  canceled.
- **Urgência:**
  - um canceled de um vínculo que já foi informado como pending é **urgente**, porque tem impacto
    financeiro;
  - um canceled sem pending antes **não é urgente**, porque o impacto é só nos dados.
- **Contrato do Lojista Alloyal:** `external_id`, `order_number`, `order_amount` e
  `transaction_status` ([BDR-0009](0009-conciliacao-por-afiliadora-app-alloyal-pivo.md)). O
  `order_amount` é o valor da compra na afiliadora (na Magalu, `total`), não a comissão.
- **Canal:** hoje é o **arquivo de remessa** (CSV), gerado sob demanda pelo front. Quando existir
  envio por API, o arquivo de remessa continua como redundância.
- Os status `available` e `approved` ficam para depois.

## Consequências

- Técnica: [ADR-0016](../adr/0016-curated-append-only-e-view.md).
- A CLI para gerar a remessa fica para depois do front.
