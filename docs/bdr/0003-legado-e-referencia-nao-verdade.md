# BDR-0003 — O legado é referência a questionar, não fonte de verdade

- **Status:** Aceito
- **Data:** 2026-09-23

## Contexto

Existem dois legados: o design doc "Bastidor" e o sistema Recon Alloyal V3
(`Alloyal-Platform/recon_alloyal`). Parte do que eles dizem é verdade e parte não é.

## Decisão

- Tudo é nomeado e documentado **a partir da realidade** (dado real, operação real). Nada é
  inventado.
- O legado é lido como **hipótese**: cada regra dele é trazida como pergunta e só vira regra
  depois de confirmada pela operação.

## Exemplos já aplicados

| O legado dizia | A realidade |
|---|---|
| A tabela `orders` da Alloyal guarda cliques/LCs (`BancoLC`) | É o **Pedido do lado da Alloyal**, com id `number` ([BDR-0004](0004-pedido-alloyal-e-imutavel.md)) |
| Pedido sem `user_name` é descartado | É erro a registrar, nunca descarte ([BDR-0005](0005-todo-pedido-alloyal-tem-nome.md)) |
| Converter UTC para BRT na ingestão | A ingestão não conhece regra de negócio ([ADR-0004](../adr/0004-contrato-da-fonte-na-fronteira.md)) |
| Gestão de sessão em ~710 linhas | Duas funções públicas bastam hoje, sem lock, cooldown nem alertas ([ADR-0006](../adr/0006-sessao-magalu-singleton-sob-demanda.md)) |
