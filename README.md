# Sistema Bancário DIO + Flutter

Projeto educacional baseado no desafio de fundamentos de Python da **Trilha Python DIO** no contexto de estudos do bootcamp NTT DATA. A versão de terminal foi preservada e ganhou uma interface Flutter para demonstração visual.

## Funcionalidades

- Depósitos com valores positivos;
- saques limitados a R$ 500,00;
- máximo de três saques por execução;
- validação de saldo e valores pelo backend Python;
- extrato com todas as movimentações;
- interface responsiva em Material 3.

## Arquitetura

```text
Flutter Web
    ↓ HTTP/JSON
API local Python
    ↓
Regras bancárias em memória
```

O Flutter funciona apenas como interface. As regras de saldo, limite e quantidade de saques estão em `backend/banking.py` e também são usadas pela CLI.

## Como executar

Requisitos: Python 3, Flutter 3 e Microsoft Edge ou Google Chrome.

Na raiz do projeto, execute:

```powershell
.\start --local
```

O comando inicia a API em `http://127.0.0.1:8000`, aguarda o endpoint `/health`, abre o frontend no navegador e encerra o backend ao finalizar o Flutter.

Para executar somente a versão de terminal:

```powershell
python main.py
```

## API local

```text
GET  /health
GET  /state
POST /deposit
POST /withdraw
GET  /statement
POST /reset
```

Os dados ficam somente em memória. Reiniciar a aplicação também reinicia o saldo, a quantidade de saques e o extrato.

## Tecnologias

- Python 3 e biblioteca padrão;
- Flutter e Dart;
- pacote Dart `http`.
