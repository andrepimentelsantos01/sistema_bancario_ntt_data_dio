from backend.banking import BankingSystem


MENU = """

[d] Depositar
[s] Sacar
[e] Extrato
[q] Sair

=> """

def ler_valor(mensagem):
    """Lê um valor numérico sem encerrar o programa em caso de entrada inválida."""
    try:
        return float(input(mensagem))
    except ValueError:
        return None


def main():
    banco = BankingSystem()

    while True:
        opcao = input(MENU).lower()

        if opcao == "d":
            valor = ler_valor("Informe o valor do depósito: ")
            _, mensagem = banco.depositar(valor)
            print(mensagem)

        elif opcao == "s":
            valor = ler_valor("Informe o valor do saque: ")
            _, mensagem = banco.sacar(valor)
            print(mensagem)

        elif opcao == "e":
            print("\n================ EXTRATO ================")
            movimentacoes = banco.obter_extrato()

            if not movimentacoes:
                print("Não foram realizadas movimentações.")
            else:
                for movimentacao in movimentacoes:
                    tipo = "Depósito" if movimentacao["tipo"] == "deposito" else "Saque"
                    print(f'{tipo}: R$ {movimentacao["valor"]:.2f}')

                print()

            print(f"Saldo: R$ {banco.saldo:.2f}")
            print("==========================================")

        elif opcao == "q":
            print("Obrigado por utilizar o sistema bancário!")
            break

        else:
            print("Operação inválida, por favor selecione novamente a operação desejada.")


if __name__ == "__main__":
    main()
