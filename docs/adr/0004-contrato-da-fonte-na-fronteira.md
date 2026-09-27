# ADR-0004 — O contrato da fonte mora na fronteira; a ingestão não conhece regra de negócio

- **Status:** Aceito
- **Data:** 2026-09-23

## Contexto

Existem dois tipos de regra que chegam junto com o dado:

- **Regra de contrato:** como a fonte fala (formato, tipos, fuso do horário).
- **Regra de negócio:** o que a operação faz com o dado.

O legado misturava as duas, por exemplo convertendo UTC para BRT (−3h fixo) já na leitura.

## Decisão

- A classe de contrato de cada fonte é a **fronteira** com o Backbone: um `ActiveModel` com
  atributos tipados (`ActiveModel::Attributes`) e validações. Tudo o que diz "como a fonte
  fala" mora nela. Para a Alloyal, é o `Ingestion::AlloyalOrderContract`
  (`app/contracts/ingestion/alloyal_order_contract.rb`); para a Magalu, o
  `Ingestion::MagaluOrderContract`.
- A ingestão aplica só regra de contrato. Regra de negócio fica fora dela.
- **`created_at` da Alloyal:** chega sem fuso e é **assumido como UTC**. O contrato só declara o
  fuso, sem somar nem subtrair horas. Um valor que já venha com fuso é mantido.
- **`created_at` da Magalu:** chega sem fuso e é **assumido como BRT** (`America/Sao_Paulo`).
- A conversão para outro fuso acontece na **leitura**, onde a operação precisa dela.
- **Dinheiro é `BigDecimal`**, nunca `Float`. Na origem do App Alloyal as colunas de dinheiro
  são `numeric(10,2)`: o próprio Postgres garante que só chega número, então o contrato não
  trata valor inválido.
- **O `raw_payload` precisa trazer mais que os campos promovidos.** Um pedido real traz
  dezenas de campos; um payload só com os promovidos é sinal de dado forjado e é recusado.
- Os campos promovidos são os `attribute` do contrato. O `from_row` recorta esses campos da
  linha da origem e guarda a linha inteira no `raw_payload`.

## Consequências

- As premissas de fuso **ainda não foram confirmadas na origem**. O comentário do contrato
  registra isso, e um teste falha se a regra sumir.
- Confirmado na origem: `orders.created_at` é `timestamp without time zone`. Isso prova que o
  fuso não vem junto, não que o horário é UTC.
- Cada fonte tem o seu próprio contrato de fuso.
