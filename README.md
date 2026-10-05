# 📈 Bolsa Fácil

> Um aplicativo completo em Flutter para acompanhar o mercado de ações brasileiro, gerenciar seu portfólio de investimentos e visualizar o histórico de ativos usando dados em tempo real da [brapi.dev](https://brapi.dev/).

---

## 🚀 Funcionalidades

- 🔍 **Busca de Ativos:** Lista de ações com preço, variação percentual e busca por _ticker_ (código da ação).
- 📊 **Detalhes e Gráficos:** Visualização aprofundada da empresa, histórico de preços e gráfico interativo com múltiplos períodos (1D, 5D, 1M, 6M, 1A, 5A).
- 🔐 **Autenticação:** Cadastro e login com senha hasheada (SHA-256 + salt) e sessão persistida via token Bearer.
- ⭐ **Favoritos:** Marque ações de interesse para acompanhamento rápido.
- 💼 **Carteira Simulada:**
  - Compra simulada com cálculo automático de preço médio.
  - Acompanhamento de valor atual e lucro/prejuízo por ação.
  - Remoção de posições individuais.
- 👤 **Múltiplos Usuários:** Cada conta tem seus próprios favoritos e carteira isolados.

---

## 🛠️ Tecnologias Utilizadas

| Camada    | Tecnologia                        | Descrição                                         |
| --------- | --------------------------------- | ------------------------------------------------- |
| Frontend  | [Flutter](https://flutter.dev/)   | UI multiplataforma (Web, Android, Windows)        |
| Estado    | `ChangeNotifier` (nativo)         | Gerenciamento de estado via `AppState`             |
| Gráficos  | `fl_chart`                        | Renderização dos gráficos de histórico             |
| HTTP      | `http` (Dart)                     | Comunicação entre frontend e backend               |
| Sessão    | `shared_preferences`              | Armazena o token de autenticação no dispositivo    |
| Backend   | Dart puro (`HttpServer`)          | Servidor REST rodando na porta `8080`              |
| Banco     | `sqflite_common_ffi` (SQLite)     | Banco de dados no lado do servidor                 |
| Segurança | `crypto` (SHA-256)                | Hash de senhas com salt aleatório                  |
| API       | [brapi.dev](https://brapi.dev/)   | Dados financeiros do mercado brasileiro            |

---

## 🏗️ Arquitetura

O projeto segue uma arquitetura **cliente-servidor**. O frontend Flutter **não** possui banco de dados próprio — toda a persistência de dados (usuários, carteira, favoritos) é feita pelo backend em Dart via requisições HTTP.

```
┌─────────────────────────┐         ┌──────────────────────────────┐
│      Flutter App         │  HTTP   │   Backend Dart (porta 8080)  │
│                         │────────▶│                              │
│  • HomeScreen           │         │  /auth/*    → Autenticação   │
│  • StockDetailsScreen   │         │  /data/*    → CRUD Dados     │
│  • PortfolioScreen      │◀────────│  /api/*     → Proxy Brapi    │
│  • FavoritesScreen      │         │                              │
│  • AuthScreen           │         │  SQLite: .data/bolsa_facil.db│
└─────────────────────────┘         └──────────────────────────────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │   brapi.dev API   │
                                    └──────────────────┘
```

---

## 📂 Estrutura do Projeto

```
bolsa_facil/
├── lib/
│   ├── main.dart                    # Ponto de entrada do app
│   ├── theme.dart                   # Tema e cores do Material Design
│   ├── database/
│   │   └── app_database.dart        # Banco SQLite local (sessão offline)
│   ├── models/
│   │   ├── stock.dart               # Modelo de ação (ticker, preço, variação)
│   │   ├── portfolio_item.dart      # Modelo de posição na carteira
│   │   └── user_account.dart        # Modelo de conta do usuário
│   ├── screens/
│   │   ├── app_shell.dart           # Shell com navegação inferior (BottomNav)
│   │   ├── auth_screen.dart         # Tela de login e cadastro
│   │   ├── home_screen.dart         # Lista de ações com busca
│   │   ├── stock_details_screen.dart # Detalhes + gráfico + compra simulada
│   │   ├── portfolio_screen.dart    # Carteira do usuário
│   │   ├── favorites_screen.dart    # Ações favoritadas
│   │   └── account_screen.dart      # Informações da conta e logout
│   ├── services/
│   │   ├── api_service.dart         # Cliente HTTP para o backend (auth, dados)
│   │   └── brapi_service.dart       # Cliente HTTP para cotações via proxy
│   ├── state/
│   │   └── app_state.dart           # Estado global (ChangeNotifier)
│   └── widgets/
│       └── stock_tile.dart          # Widget reutilizável de ação na lista
├── tool/
│   └── brapi_proxy.dart             # Backend completo (servidor + proxy + banco)
├── run_web.ps1                      # Script PowerShell para rodar tudo junto
├── .env.example                     # Exemplo de variáveis de ambiente
├── pubspec.yaml                     # Dependências do projeto
└── README.md
```

---

## 🔌 API do Backend — Referência de Endpoints

O backend roda em `http://localhost:8080` e expõe as seguintes rotas:

### Autenticação

| Método | Rota             | Body (JSON)                                  | Resposta                                      |
| ------ | ---------------- | -------------------------------------------- | --------------------------------------------- |
| `POST` | `/auth/register` | `{ "name", "email", "password" }`            | `201` `{ "token", "user": { id, name, email } }` |
| `POST` | `/auth/login`    | `{ "email", "password" }`                    | `200` `{ "token", "user": { id, name, email } }` |
| `POST` | `/auth/logout`   | —                                            | `200` `{ "ok": true }`                        |
| `GET`  | `/auth/me`       | —                                            | `200` `{ "user": { id, name, email } }`       |

> Todas as rotas abaixo exigem o header `Authorization: Bearer <token>`.

### Dados do Usuário

| Método   | Rota               | Body (JSON)                                      | Resposta                           |
| -------- | ------------------ | ------------------------------------------------ | ---------------------------------- |
| `GET`    | `/data/positions`  | —                                                | `{ "positions": [...] }`           |
| `POST`   | `/data/positions`  | `{ "symbol", "quantity", "averagePrice" }`       | `{ "ok": true }`                   |
| `DELETE` | `/data/positions`  | Query: `?symbol=PETR4`                           | `{ "ok": true }`                   |
| `GET`    | `/data/favorites`  | —                                                | `{ "favorites": ["PETR4", ...] }`  |
| `POST`   | `/data/favorites`  | `{ "symbol", "favorite": true/false }`           | `{ "ok": true }`                   |

### Proxy da Brapi

| Método | Rota      | Descrição                                                   |
| ------ | --------- | ----------------------------------------------------------- |
| `GET`  | `/api/*`  | Repassa a requisição para `brapi.dev` com o token injetado  |

---

## 🗄️ Banco de Dados (SQLite)

O banco fica em `.data/bolsa_facil.db` na raiz do projeto (criado automaticamente pelo backend).

**Tabelas:**

| Tabela      | Descrição                        | Chave Primária         |
| ----------- | -------------------------------- | ---------------------- |
| `users`     | Contas de usuário                | `id` (autoincrement)   |
| `sessions`  | Sessões ativas (token Bearer)    | `token`                |
| `positions` | Posições na carteira             | `(user_id, symbol)`    |
| `favorites` | Ações favoritadas                | `(user_id, symbol)`    |

---

## 💻 Como Rodar o Projeto Localmente

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versão 3.24 ou superior)
- [Dart SDK](https://dart.dev/get-dart) (incluído no Flutter)
- Chave de API da [brapi.dev](https://brapi.dev/) (conta gratuita)

### Passo a Passo

1. **Clone o repositório:**

   ```bash
   git clone https://github.com/PramioIFC/BolsaFacil.git
   cd BolsaFacil
   ```

2. **Instale as dependências:**

   ```bash
   flutter pub get
   ```

3. **Configure o token da Brapi:**

   Crie um arquivo `.env` na raiz do projeto (copie o `.env.example`) e preencha seu token:

   ```env
   BRAPI_TOKEN=seu_token_aqui
   ```

   > O token é usado **apenas pelo backend** para autenticar nas requisições à brapi.dev.

4. **Inicie o Backend:**

   ```bash
   dart run tool/brapi_proxy.dart
   ```

   O servidor ficará ativo em `http://localhost:8080`. Ele precisa estar rodando para o app funcionar.

5. **Inicie o App Flutter** (em outro terminal):

   ```bash
   # Web
   flutter run -d chrome

   # Android (com dispositivo/emulador conectado)
   flutter run

   # Windows
   flutter run -d windows
   ```

6. **Atalho (Windows):** Para iniciar backend e app juntos:

   ```powershell
   .\run_web.ps1
   ```

---

## 🌐 Configuração de Rede

| Plataforma | URL padrão do backend           | Observação                              |
| ---------- | ------------------------------- | --------------------------------------- |
| Web        | `http://localhost:8080`         | Acesso direto via loopback              |
| Android    | `http://192.168.3.103:8080`     | IP local da máquina na rede Wi-Fi       |
| Windows    | `http://192.168.3.103:8080`     | IP local da máquina na rede             |

> **Produção:** Para publicar o app, faça deploy do `brapi_proxy.dart` em um VPS com Dart instalado e configure a URL do backend via `--dart-define=BRAPI_BASE_URL=https://seu-servidor.com`.

---

## 📄 Licença

Este projeto é de uso acadêmico, desenvolvido no [IFC — Instituto Federal Catarinense](https://ifc.edu.br/).

---

**Desenvolvido com Flutter 💙**
