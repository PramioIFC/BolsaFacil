# Handoff para o Codex — Bolsa Fácil

Você está continuando um trabalho feito **sem SDK Dart/Flutter disponível**. Tudo foi escrito e conferido só estaticamente. **Sua primeira tarefa é compilar, rodar e corrigir.** Não adicione funcionalidades antes de `flutter analyze` e `flutter test` ficarem verdes.

## Contexto

Aplicativo Flutter (Dart 3) para acompanhar ações da B3 via [brapi.dev](https://brapi.dev/), com favoritos e carteira simulada. SQLite local, cotações da brapi, proxy Dart (`tool/brapi_proxy.dart`) para a Web. Leia, nesta ordem: `TECHNICAL_DOCS.md` (arquitetura atual), `MELHORIAS.md` (o que mudou e o status de cada item).

Restrições do projeto: **manter Flutter, brapi e SQLite**. Idioma da UI e das mensagens: português do Brasil.

## Onde parei

Implementei as etapas 1–4 e 7 e partes de 5 e 6 (ver `MELHORIAS.md`). O que **não** foi feito:

1. Dividir o `AppState` em `AuthState`/`MarketState`/`PortfolioState` com `provider` (adiado de propósito).
2. Tema escuro (as cores estão fixas em `lib/theme.dart` e nas telas).
3. Alertas de preço-alvo (notificações locais).
4. Ordenação/filtro nas listas.
5. Telas com outros dados da brapi (dividendos, câmbio, inflação).
6. Limite de tentativas de login; PBKDF2 fora da thread da UI ou Argon2id.
7. Validar o formato real de `/api/quote/list` (autocomplete) e avaliar `/api/v2/tickers`.

## Primeiros passos (obrigatórios, nesta ordem)

```bash
flutter pub get
dart run sqflite_common_ffi_web:setup     # regenera web/sqlite3.wasm e web/sqflite_sw.js na versão certa
flutter analyze
flutter test
flutter build web --release --dart-define=BRAPI_BASE_URL=http://localhost:8080/api
```

Corrija os erros que aparecerem. Para cada teste vermelho, decida com cuidado se o bug está no **código** ou no **teste** (os testes também nunca rodaram) e prefira corrigir o código quando o teste expressa uma regra de negócio documentada em `TECHNICAL_DOCS.md`.

## Pontos de maior risco (verifique primeiro)

| # | Onde | Por que desconfiar |
|---|---|---|
| 1 | `pubspec.yaml` / `pubspec.lock` | `sqflite_common_ffi_web ^1.1.3` e `intl` foram adicionados sem `pub get`; o lock está desatualizado. Pode haver conflito de versão com `sqlite3` |
| 2 | `lib/database/db_factory_web.dart` | Importa `package:sqflite/sqflite.dart` para atribuir `databaseFactory`. Se o build Web reclamar, trocar por `sqflite_common/sqflite.dart` ou atribuir via a API do pacote ffi_web |
| 3 | `lib/database/db_factory.dart` | Import condicional `if (dart.library.io)`; confirmar que a Web escolhe `db_factory_web.dart` |
| 4 | `web/sqlite3.wasm`, `web/sqflite_sw.js` | Podem ser de outra versão do pacote; regenerar com o comando de setup |
| 5 | `lib/services/brapi_service.dart` → `searchTickers` | Assume `stocks[]` com `stock`/`symbol` e `name`; **não validado** na API. Teste com um token real |
| 6 | `lib/database/app_database.dart` | Migração v1→v2 (`_seedTransactionsFromPositions`), `OpenDatabaseOptions(singleInstance: false)` em memória e `isUniqueConstraintError()` |
| 7 | `lib/state/app_state.dart` → `refresh` | `_refreshing ??= _doRefresh(force).whenComplete(...)`: conferir que não deixa o estado preso se houver exceção |
| 8 | Windows | `sqflite_common_ffi` precisa do `sqlite3` disponível; testar `flutter run -d windows` |
| 9 | Lints | O projeto usa `flutter_lints` + `prefer_single_quotes`. Há código antigo com `withOpacity` (deprecado nas versões novas) |
| 10 | `tool/brapi_proxy.dart` | Rode e teste com `curl` (ver abaixo) |

Teste manual do proxy (com `.env` preenchido):

```bash
dart run tool/brapi_proxy.dart &
curl -s localhost:8080/health                              # {"ok":true}
curl -s localhost:8080/api/quote/PETR4 | head -c 200       # JSON da brapi
curl -s -o /dev/null -w "%{http_code}\n" localhost:8080/api/qualquer   # 404
curl -s -o /dev/null -w "%{http_code}\n" -X POST localhost:8080/api/quote/PETR4  # 405
curl -s -o /dev/null -w "%{http_code}\n" -H "Origin: https://evil.example" localhost:8080/api/quote/PETR4  # 403
```

## Verificação manual no app (depois dos testes)

1. Web: `dart run tool/brapi_proxy.dart` + `flutter run -d chrome --web-port 3000`. Criar conta, favoritar, comprar, vender, **recarregar a página** (os dados devem persistir via Wasm/IndexedDB).
2. Tentar criar conta com e-mail já usado → deve recusar, sem alterar a conta original.
3. Derrubar o proxy e puxar para atualizar → Home deve mostrar dados do cache com aviso, não tela vazia.
4. Conta → exportar, apagar uma posição, importar → deve restaurar.
5. Android/Windows: `flutter run --dart-define-from-file=config/dart_defines.json`.

## Regras para continuar

- Rode `flutter analyze` e `flutter test` a cada mudança; não deixe vermelho.
- Não reintroduza `kIsWeb` no `AppState`; diferenças de plataforma ficam em `db_factory*.dart` e `BrapiService`.
- Não envie o token ao navegador; não commite `.env` nem `config/dart_defines.json`.
- Mudou o schema? Suba `AppDatabase.schemaVersion`, escreva `onUpgrade` e um teste de migração (veja o de v1→v2).
- Atualize `TECHNICAL_DOCS.md` e `MELHORIAS.md` quando algo mudar.
- Commits pequenos, mensagens em português.

## Ordem sugerida do que fazer depois que tudo estiver verde

1. Validar `/api/quote/list` e ajustar `searchTickers` + teste.
2. Mover o PBKDF2 para fora da thread da UI (ou Argon2id) e limitar tentativas de login.
3. Dividir o `AppState` (item 1 da lista "não feito"), mantendo os testes passando.
4. Tema escuro, ordenação/filtro, alertas de preço.
