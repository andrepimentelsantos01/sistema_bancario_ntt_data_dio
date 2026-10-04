import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from backend.banking import BankingSystem


banco = BankingSystem()


class BankingHandler(BaseHTTPRequestHandler):
    def _enviar_json(self, dados, status=200):
        corpo = json.dumps(dados, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(corpo)

    def _ler_json(self):
        tamanho = int(self.headers.get("Content-Length", "0"))
        if tamanho <= 0:
            return {}
        return json.loads(self.rfile.read(tamanho).decode("utf-8"))

    def do_OPTIONS(self):
        self._enviar_json({}, status=204)

    def do_GET(self):
        if self.path == "/health":
            self._enviar_json({"status": "ok"})
        elif self.path == "/state":
            self._enviar_json(banco.obter_estado())
        elif self.path == "/statement":
            self._enviar_json(banco.obter_extrato())
        else:
            self._enviar_json({"mensagem": "Endpoint não encontrado."}, status=404)

    def do_POST(self):
        try:
            dados = self._ler_json()
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError):
            self._enviar_json({"sucesso": False, "mensagem": "JSON inválido."}, status=400)
            return

        if self.path == "/deposit":
            sucesso, mensagem = banco.depositar(dados.get("valor"))
        elif self.path == "/withdraw":
            sucesso, mensagem = banco.sacar(dados.get("valor"))
        elif self.path == "/reset":
            banco.resetar()
            sucesso, mensagem = True, "Conta reiniciada com sucesso!"
        else:
            self._enviar_json({"mensagem": "Endpoint não encontrado."}, status=404)
            return

        self._enviar_json(
            {
                "sucesso": sucesso,
                "mensagem": mensagem,
                "estado": banco.obter_estado(),
            },
            status=200 if sucesso else 400,
        )

    def log_message(self, formato, *args):
        print(f"{self.client_address[0]} - {formato % args}")


def main():
    parser = argparse.ArgumentParser(description="API local do sistema bancário")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    argumentos = parser.parse_args()

    servidor = ThreadingHTTPServer((argumentos.host, argumentos.port), BankingHandler)
    print(f"API disponível em http://{argumentos.host}:{argumentos.port}", flush=True)

    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        servidor.server_close()


if __name__ == "__main__":
    main()
