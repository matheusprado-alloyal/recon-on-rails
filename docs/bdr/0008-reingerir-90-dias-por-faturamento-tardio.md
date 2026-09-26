# BDR-0008 — Reingestão dos últimos 90 dias, por causa do faturamento tardio

- **Status:** Aceito
- **Data:** 2026-09-24 (registro retroativo — a decisão já estava implementada)

## Contexto

O Pedido Magalu não é totalmente imutável: `billed` (faturado) e a comissão mudam depois que o
pedido já apareceu na API, por cancelamento ou faturamento tardio. Uma ingestão que só lesse
pedidos novos, a partir de uma marca d'água, nunca veria essas mudanças de novo.

## Decisão

A cada execução, a ingestão relê os pedidos dos **últimos 90 dias antes do último sucesso**, não
só os pedidos novos. A marca d'água só avança quando o job inteiro termina com sucesso.

## Consequências

- Uma mudança de `billed`/comissão até 90 dias depois de o pedido aparecer é capturada na
  próxima execução.
- Uma mudança depois de 90 dias não é capturada automaticamente.
- Cada execução relê ~90 dias de pedidos, não só os novos — mais chamadas à API do que uma
  ingestão puramente incremental.
