# Bolsa Fácil

App Flutter para acompanhar ações brasileiras usando a [brapi.dev](https://brapi.dev/).

## Recursos

- Lista de ações com preço, variação e busca por ticker
- Detalhes da empresa e gráfico histórico
- Favoritos persistidos no dispositivo
- Carteira simulada com cálculo de posição e lucro/prejuízo

## Executar

1. Instale o Flutter (3.24 ou superior).
2. Abra o arquivo `.env` e adicione seu token:

```env
BRAPI_TOKEN=seu_token_aqui
```

3. Na pasta do projeto, execute:

```bash
flutter pub get
flutter run
```

O arquivo `.env` está no `.gitignore` e não deve ser enviado ao repositório. O
`.env.example` documenta a variável necessária sem guardar a credencial real.

> Em builds Web, variáveis incluídas no aplicativo podem ser vistas pelo usuário.
> Para manter um token realmente secreto, use um backend intermediário.
