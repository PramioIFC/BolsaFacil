# 📈 Bolsa Fácil

> Um aplicativo completo em Flutter para acompanhar o mercado de ações brasileiro, gerenciar seu portfólio de investimentos e visualizar o histórico de ativos usando dados em tempo real da [brapi.dev](https://brapi.dev/).

---

## 🚀 Funcionalidades (Features)

- 🔍 **Busca de Ativos:** Lista de ações com preço, variação percentual e busca por _ticker_ (código da ação).
- 📊 **Detalhes e Gráficos:** Visualização aprofundada da empresa, histórico de preços e gráfico interativo.
- 🔐 **Autenticação:** Cadastro e login com sessão persistida via backend próprio.
- 💼 **Gestão de Portfólio:**
  - Adição de ações aos favoritos.
  - Carteira simulada com cálculo de preço médio.
  - Acompanhamento de valor atual e lucro/prejuízo.
- 👤 **Múltiplos Usuários:** Favoritos e carteira separados e gerenciados por conta.

---

## 🛠️ Tecnologias Utilizadas & Arquitetura

Este projeto possui uma arquitetura dividida em Frontend (Flutter) e Backend/Proxy (Dart Puro):

**Frontend:**

- **Framework:** [Flutter](https://flutter.dev/) (Dart)
- **Gerenciamento de Estado:** Nativo (com injeção de dependências e `ChangeNotifier` via `app_state.dart`).
- **Gráficos:** `fl_chart` para renderização visual do histórico das ações.
- **Armazenamento de Sessão:** `shared_preferences` para armazenar o token de autenticação JWT no dispositivo/navegador.

**Backend (Local via `tool/brapi_proxy.dart`):**

- **Servidor:** Dart puro (`HttpServer`), rodando localmente (porta 8080).
- **Banco de Dados:** `sqflite_common_ffi` (SQLite) executado no lado do **servidor**. Os dados ficam salvos no arquivo `.data/bolsa_facil.db` na máquina onde o backend está rodando.
- **Funções do Backend:**
  1. Fornece endpoints completos de Autenticação (`/auth/register`, `/auth/login`, `/auth/me`).
  2. Fornece endpoints de Dados (`/data/positions`, `/data/favorites`) para salvar carteira e favoritos.
  3. Atua como **Proxy** (`/api/*`) repassando chamadas com o Token injetado para a API real da [Brapi](https://brapi.dev/) e resolvendo problemas de CORS em ambiente Web.

> **Importante:** O Frontend do aplicativo **não possui banco de dados local próprio** (como o SQLite embutido no celular ou no navegador via WebAssembly). Ele faz chamadas via HTTP (através do `ApiService`) para o backend em Dart, que centraliza toda a regra de banco de dados e repassa consultas financeiras para a Brapi.

---

## 📸 Screenshots

_(Adicione imagens do seu app aqui!)_

|          Tela Inicial          |            Detalhes da Ação            |                Portfólio                |
| :----------------------------: | :------------------------------------: | :-------------------------------------: |
| ![Home](caminho_para_home.png) | ![Detalhes](caminho_para_detalhes.png) | ![Carteira](caminho_para_portfolio.png) |

---

## 💻 Como Rodar o Projeto Localmente

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versão 3.24 ou superior) instalado.
- Chave de API da [brapi.dev](https://brapi.dev/) (crie uma conta gratuita).

### Passo a Passo

1. **Clone o repositório:**

   ```bash
   git clone https://github.com/seu-usuario/bolsa_facil.git
   cd bolsa_facil
   ```

2. **Instale as dependências:**

   ```bash
   flutter pub get
   ```

3. **Configure as Variáveis de Ambiente:**
   Crie um arquivo `.env` na raiz do projeto (use o `.env.example` como base) e adicione o seu token da Brapi. Esse token será lido exclusivamente pelo servidor local em Dart.

   ```env
   BRAPI_TOKEN=seu_token_aqui
   ```

4. **Inicie o Backend (Servidor/Proxy):**
   Abra um terminal e rode o backend. Ele é essencial para o app funcionar, pois cuida do banco de dados (SQLite) e gerencia a conexão com a Brapi:

   ```bash
   dart run tool/brapi_proxy.dart
   ```

   _(O servidor ficará rodando em `http://localhost:8080`)_

5. **Inicie o App Flutter:**
   Em um **segundo terminal**, rode o aplicativo. Para rodar na Web (onde o CORS será evitado graças ao proxy):

   ```bash
   flutter run -d chrome
   ```

   Para Windows/Android:

   ```bash
   flutter run
   ```

   **Dica para Windows:** Você pode iniciar tanto o proxy quanto o aplicativo simultaneamente usando o script incluso:

   ```powershell
   .\run_web.ps1
   ```

> **Nota de Produção:** Atualmente, o frontend aponta por padrão para `http://localhost:8080` para falar com o backend. Para publicar na Web, você deve colocar o arquivo `brapi_proxy.dart` em um VPS/Servidor rodando Dart e apontar o app para a URL dele em produção.

---

**Desenvolvido em Flutter.**
