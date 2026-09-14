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

3. No Windows, inicie proxy e aplicativo com um único comando:

```powershell
.\run_web.ps1
```

Alternativamente, abra dois terminais. No primeiro, inicie o proxy local que
mantém o token fora do navegador:

```bash
dart run tool/brapi_proxy.dart
```

4. No segundo terminal, execute o aplicativo:

```bash
flutter pub get
flutter run -d chrome
```

O arquivo `.env` está no `.gitignore` e não deve ser enviado ao repositório. O
`.env.example` documenta a variável necessária sem guardar a credencial real.

O Flutter Web usa `http://localhost:8080/api` por padrão. Em produção, publique
o proxy em um servidor e informe seu endereço com
`--dart-define=BRAPI_BASE_URL=https://seu-servidor.com/api`.

Para Android/Windows, também é possível usar diretamente:

```bash
flutter run --dart-define=BRAPI_TOKEN=seu_token
```
