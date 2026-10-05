# Melhorias aplicadas (branch `melhorias`)

Legenda: ✅ implementado (não executado) · 🟡 parcial · ⬜ não feito.

> **Nada abaixo foi compilado ou testado.** O ambiente em que isto foi escrito não tinha SDK Dart/Flutter. O código passou por verificação de **sintaxe** (parser tree-sitter, 0 erros nos 24 arquivos `.dart`) e conferência estática de imports. Rode `docs/HANDOFF_CODEX.md` → "Primeiros passos" antes de confiar em qualquer item.

## 1. Corrigir o que estava quebrado ou arriscado

| Item | Estado | Onde |
|---|---|---|
| Registro sobrescrevia conta existente | ✅ agora recusa com `AuthException` | `AppDatabase.register` |
| `AppDatabase` injetável (fábrica + nome) e testes consertados | ✅ | `app_database.dart`, `test/` |
| Hash de senha: SHA-256 simples → PBKDF2-HMAC-SHA256 (60k iterações), com migração dos hashes antigos no login | ✅ | `app_database.dart` |
| Proxy: loopback, só `GET /api/quote/*`, allowlist de parâmetros, CORS restrito, rate limit por IP, sem `/auth` e `/data` | ✅ | `tool/brapi_proxy.dart` |
| Falhas silenciosas na Web (`ApiService` sem checar status) | ✅ eliminado: `ApiService` foi removido (item 2) | — |
| Favorito sem rollback | ✅ rollback + SnackBar | `AppState.toggleFavorite`, `AppShell` |
| Token da brapi na query string (nativo) | ✅ agora só no header `Authorization` | `BrapiService` |

## 2. Unificar a persistência

| Item | Estado | Onde |
|---|---|---|
| Web com SQLite em Wasm (`sqflite_common_ffi_web`) e o mesmo `AppDatabase` em todas as plataformas | ✅ | `lib/database/db_factory*.dart`, `main.dart` |
| Remoção de `ApiService`, rotas `/auth` e `/data` do proxy, `kIsWeb` do `AppState`, `shared_preferences` | ✅ | — |
| Windows/Linux/macOS: inicialização FFI | ✅ | `db_factory_io.dart` |

## 3. Usar melhor a brapi

| Item | Estado | Onde |
|---|---|---|
| Cache de cotações no SQLite com TTL (5 min) e dado antigo como fallback | ✅ | `QuoteRepository`, tabela `quotes_cache` |
| Consultas em paralelo (3) e backoff em HTTP 429 | ✅ | `BrapiService.fetchQuotes/fetchQuote` |
| Distinguir 429 / 401 / 404 / rede | ✅ `QuoteFailure` | `brapi_service.dart` |
| Avisar quando um ticker falha e mostrar "atualizado às…" | ✅ | `home_screen.dart` |
| Autocomplete de tickers | 🟡 implementado sobre `/api/quote/list?search=`; formato de resposta **não validado** na API real | `searchTickers`, `home_screen.dart` |
| Novas telas com dividendos/câmbio/inflação | ⬜ | — |

## 4. Modelo de dados

| Item | Estado | Onde |
|---|---|---|
| Migrations (`onUpgrade` v1 → v2) | ✅ | `AppDatabase._open` |
| Tabela `transactions` (compra/venda/ajuste, taxas); posição derivada; lucro realizado | ✅ | `trade.dart`, `AppDatabase` |
| Tela: vender, histórico por ativo, resultado realizado | ✅ | `portfolio_screen.dart` |
| Índices | ✅ só em `transactions`; `positions`/`favorites` já são cobertas pela PK composta | — |
| Exportar/importar JSON | ✅ via área de transferência (sem dependência nova) | Conta |

## 5. Arquitetura

| Item | Estado |
|---|---|
| Repositório de cotações entre estado e fonte | ✅ `QuoteRepository` |
| Tela de detalhes passa pelo `AppState` | ✅ `loadQuote` |
| Dividir `AppState` em `AuthState`/`MarketState`/`PortfolioState` + `provider` | ⬜ adiado de propósito: refatoração ampla, arriscada sem compilador |

## 6. Produto e experiência

| Item | Estado |
|---|---|
| Formatação pt-BR com `intl` | ✅ `lib/utils/format.dart` |
| Gráfico de alocação (pizza) e rentabilidade (% por ativo) | ✅ |
| Tema escuro | ⬜ (cores fixas no código; exige refatorar o tema) |
| Alertas de preço-alvo | ⬜ |
| Ordenação/filtro nas listas | ⬜ |

## 7. Qualidade contínua

| Item | Estado |
|---|---|
| CI (analyze + test + build web) | ✅ `.github/workflows/ci.yml` |
| Testes novos (trade, stock, banco, brapi, repositório, estado) | ✅ escritos, ⬜ não executados |
| `--dart-define-from-file` | ✅ `config/dart_defines.example.json` |
| Limpeza de arquivos sem uso (`sqlite3.wasm`/`sqflite_sw.js` agora são usados) | ✅ |

## Mudanças de comportamento que o usuário percebe

- Contas criadas **no proxy** pela versão antiga da Web **não migram**: a Web agora guarda tudo no navegador. É preciso recriar a conta (ou usar backup, se houver).
- "Remover" uma posição agora também apaga o histórico de operações dela.
- Editar uma posição manualmente registra um `ajuste` no histórico.
- Pull-to-refresh ignora o cache; abrir o app/logar usa o cache de até 5 min.
