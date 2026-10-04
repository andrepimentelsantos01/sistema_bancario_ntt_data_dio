from math import isfinite


class BankingSystem:
    """Mantém em memória o estado e as regras do desafio bancário."""

    LIMITE_SAQUE = 500.0
    LIMITE_SAQUES = 3

    def __init__(self):
        self.resetar()

    @staticmethod
    def _valor_valido(valor):
        return (
            isinstance(valor, (int, float))
            and not isinstance(valor, bool)
            and isfinite(valor)
            and valor > 0
        )

    def depositar(self, valor):
        if not self._valor_valido(valor):
            return False, "Operação falhou! O valor informado é inválido."

        valor = float(valor)
        self.saldo += valor
        self._movimentacoes.append({"tipo": "deposito", "valor": valor})
        return True, "Depósito realizado com sucesso!"

    def sacar(self, valor):
        if not self._valor_valido(valor):
            return False, "Operação falhou! O valor informado é inválido."
        if valor > self.saldo:
            return False, "Operação falhou! Você não tem saldo suficiente."
        if valor > self.LIMITE_SAQUE:
            return False, "Operação falhou! O valor do saque excede o limite."
        if self.numero_saques >= self.LIMITE_SAQUES:
            return False, "Operação falhou! Número máximo de saques excedido."

        valor = float(valor)
        self.saldo -= valor
        self.numero_saques += 1
        self._movimentacoes.append({"tipo": "saque", "valor": valor})
        return True, "Saque realizado com sucesso!"

    def obter_estado(self):
        return {
            "saldo": self.saldo,
            "limite_saque": self.LIMITE_SAQUE,
            "numero_saques": self.numero_saques,
            "limite_saques": self.LIMITE_SAQUES,
        }

    def obter_extrato(self):
        return [movimentacao.copy() for movimentacao in self._movimentacoes]

    def resetar(self):
        self.saldo = 0.0
        self.numero_saques = 0
        self._movimentacoes = []
