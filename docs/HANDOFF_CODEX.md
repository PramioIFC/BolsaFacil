# Handoff para o Codex — Bolsa Fácil

## Contexto

Aplicativo Flutter (Dart 3) para acompanhar ações da B3 via [brapi.dev](https://brapi.dev/), com favoritos e carteira simulada (compra, venda, histórico, lucro realizado, backup JSON). SQLite local em todas as plataformas (nativo: arquivo; Web: Wasm no navegador). Proxy Dart (`tool/brapi_proxy.dart`) só para a Web.

**Restrições:** manter Flutter, brapi e SQLite. UI e mensagens em português do Brasil. Nunca commitar `.env` nem `config/dart_defines.json`. Sem `kIsWeb` no `AppState` (diferenças de plataforma ficam em `lib/database/db_factory*.dart` e `BrapiService`).

Leia, nesta ordem: `TECHNICAL_DOCS.md` (arquitetura atual), `MELHORIAS.md` (o que mudou).

## Estado atual (verificado pelo autor, no Windows)

| Verificação | Resultado |
|---|---|
| `flutter pub get` | ok (resolveu `sqflite_common_ffi_web 1.2.0`) |
| `dart run sqflite_common_ffi_web:setup` | ok |
| `flutter analyze` | **No issues found** |
| `flutter test` | **53 testes passando** |

## O que AINDA NÃO foi verificado (comece por aqui)

1. `flutter build web --release --dart-define=BRAPI_BASE_URL=http://localhost:8080/api` (confirma o import condicional e o Wasm).
2. **Persistência na Web:** criar conta, comprar, **recarregar a página (F5)** e confirmar que continua logado e com os dados (SQLite Wasm + IndexedDB).
3. **Autocomplete** (`BrapiService.searchTickers`): assume `GET /api/quote/list?search=` com resposta `{"stocks":[{"stock"|"symbol","name"}]}`. **Formato não validado** na API real; testar com token real e ajustar código + teste. Avaliar também `/api/v2/tickers`.
4. **Proxy:** rodar e testar com `curl`:
   ```bash
   dart run tool/brapi_proxy.dart &
   curl -s localhost:8080/health                                                      # {"ok":true}
   curl -s localhost:8080/api/quote/PETR4 | head -c 200                               # JSON da brapi
   curl -s -o /dev/null -w "%{http_code}\n" localhost:8080/api/qualquer               # 404
   curl -s -o /dev/null -w "%{http_code}\n" -X POST localhost:8080/api/quote/PETR4    # 405
   curl -s -o /dev/null -w "%{http_code}\n" -H "Origin: https://evil.example" localhost:8080/api/quote/PETR4  # 403
   ```
5. **Fluxos de UI** (não há teste de widget além do `AuthScreen`): venda e histórico na Carteira, pizza de alocação, banner de falha na Home, SnackBar de rollback de favorito, exportar/importar em Conta.
6. Android (`flutter run --dart-define-from-file=config/dart_defines.json`) e Windows (`flutter run -d windows`).
7. **Migração real:** abrir um banco v1 antigo (cópia) e confirmar que a v2 migra. Há teste automatizado, mas com banco sintético.

## Pendências de produto (não implementadas)

1. Dividir o `AppState` em `AuthState`/`MarketState`/`PortfolioState` com `provider` (adiado de propósito: toda notificação reconstrói todos os builders).
2. Tema escuro (cores fixas em `lib/theme.dart` e nas telas).
3. Alertas de preço-alvo (notificações locais).
4. Ordenação/filtro nas listas.
5. Telas com outros dados da brapi (dividendos, câmbio, inflação).
6. PBKDF2 em Dart puro (60.000 nativo / 20.000 Web, cedendo à UI a cada 1000): avaliar isolate (nativo) ou Argon2id; limitar tentativas de login.
7. Tela de detalhes: trocar o período do gráfico não atualiza `AppState.stocks`.
8. Testes de widget das telas novas.

## Regras para continuar

- Rode `flutter analyze` e `flutter test` a cada mudança; não deixe vermelho.
- Mudou o schema? Suba `AppDatabase.schemaVersion`, escreva `onUpgrade` e um teste de migração (modelo: o de v1→v2 em `test/app_database_test.dart`).
- O ambiente do autor é Windows (arquivos com CRLF): ao gerar patches, prefira editar arquivos direto a `git apply`.
- Atualize `TECHNICAL_DOCS.md` e `MELHORIAS.md` quando algo mudar.
- Commits pequenos, mensagens em português.

## Ordem sugerida

1. Itens 1 a 7 da seção "não verificado".
2. Pendência 6 (segurança do login) e 7 (detalhes).
3. Pendência 1 (dividir o `AppState`), mantendo os 53 testes verdes.
4. Pendências 2, 4, 3 e 5, nessa ordem.

## Prompt sugerido para colar no Codex

> Leia `AGENTS.md`, `docs/HANDOFF_CODEX.md`, `TECHNICAL_DOCS.md` e `MELHORIAS.md`. O projeto está com `flutter analyze` limpo e 53 testes passando. Execute primeiro a seção "O que AINDA NÃO foi verificado" do handoff, corrigindo o que falhar (com testes quando possível). Depois siga a "Ordem sugerida". Mantenha Flutter + brapi + SQLite, UI em português, e rode analyze e test a cada mudança.
