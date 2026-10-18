#!/usr/bin/env python3
"""
g15-teclado para Windows — acende e escolhe a cor do teclado RGB do Dell G15
(controlador Alienware 187c:0550), sem precisar do Alienware Command Center.

Usa o mesmo protocolo do projeto Linux (baseado em Dell-G-Series-Controller /
G15kblight-cli, licença GPL-3.0). As cores ficam gravadas na memória do próprio
teclado, então não precisa deixar nada rodando em segundo plano.

Uso:
    python g15_teclado_windows.py                 -> abre a janela de cores
    python g15_teclado_windows.py --cor 0x00AAFF  -> aplica uma cor (0xRRGGBB)
    python g15_teclado_windows.py --acender       -> branco
    python g15_teclado_windows.py --desligar      -> apaga a luz
    python g15_teclado_windows.py --diagnostico   -> testa os métodos de comunicação
    python g15_teclado_windows.py --metodo 2 --acender  -> força um método (1 a 4)
    python g15_teclado_windows.py --simular --cor 0xFF0000  -> só mostra os pacotes
"""
import argparse
import sys
import time

VID = 0x187C
PIDS = (0x0550, 0x0551)

# Comandos principais
ELC_QUERY, USER_ANIMATION, POWER_ANIMATION = 0x20, 0x21, 0x22
START_SERIES, ADD_ACTION, DIMMING = 0x23, 0x24, 0x26
# Subcomandos
GET_VERSION = 0x00
START_NEW, FINISH_SAVE, REMOVE, SET_DEFAULT = 0x01, 0x02, 0x04, 0x06
# Efeitos e ids de animação
COLOR = 0x00
AC_SLEEP, AC_CHARGED, AC_CHARGING, DC_SLEEP, DC_ON, DC_LOW = 0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60

DURATION_MAX = 0xFFFF
DURATION_BATTERY_LOW = 0xFF
TEMPO_MIN = 0x01
ZONES = [0, 1, 2, 3]
REPORT_LEN = 33

# Métodos de comunicação (o Windows pode exigir um diferente do Linux)
METODOS = {
    1: "relatório sem número (byte 0x00 na frente) + leitura pela fila de entrada",
    2: "relatório sem número (0x00) + get_input_report",
    3: "feature report sem número (0x00)",
    4: "formato antigo: 0x03 como número do relatório + leitura",
}


class Teclado:
    def __init__(self, simular=False, metodo=None, verbose=False):
        self.simular = simular
        self.verbose = verbose
        self.dev = None
        self.metodo = metodo
        if not simular:
            self._abrir()

    # ---------- baixo nível ----------
    def _abrir(self):
        try:
            import hid
        except ImportError:
            sys.exit("Falta a biblioteca. Rode:  python -m pip install hidapi")
        candidatos = [d for d in hid.enumerate(VID, 0) if d["product_id"] in PIDS]
        if not candidatos:
            sys.exit("Teclado RGB 187c:0550 não encontrado. Confira o Gerenciador de "
                     "Dispositivos > Dispositivos de Interface Humana.")
        ultimo_erro = None
        for info in candidatos:
            try:
                d = hid.device()
                d.open_path(info["path"])
                self.dev = d
                break
            except Exception as e:
                ultimo_erro = e
        if self.dev is None:
            sys.exit(f"Não consegui abrir o teclado ({ultimo_erro}). Feche o Alienware "
                     "Command Center (e encerre os serviços Alienware/AWCC) e tente de novo.")
        if self.metodo is None:
            self.metodo = self._detecta_metodo()

    @staticmethod
    def _monta(fragmento):
        dados = bytearray.fromhex("03" + fragmento)
        dados += bytearray(REPORT_LEN - len(dados))
        return bytes(dados)

    def _tenta(self, metodo, pacote):
        """Envia um pacote por um método e devolve (resposta, erro)."""
        d = self.dev
        sem_num = b"\x00" + pacote  # relatório sem número: 0x00 + 33 bytes
        try:
            if metodo == 1:
                n = d.write(sem_num)
                if n < 0:
                    return b"", f"write devolveu {n}: {d.error()}"
                time.sleep(0.02)
                resp = bytes(d.read(REPORT_LEN, 500))
            elif metodo == 2:
                n = d.write(sem_num)
                if n < 0:
                    return b"", f"write devolveu {n}: {d.error()}"
                time.sleep(0.02)
                resp = bytes(d.get_input_report(0, REPORT_LEN + 1))
            elif metodo == 3:
                n = d.send_feature_report(sem_num)
                if n < 0:
                    return b"", f"send_feature_report devolveu {n}: {d.error()}"
                time.sleep(0.02)
                resp = bytes(d.get_feature_report(0, REPORT_LEN + 1))
            elif metodo == 4:
                n = d.write(pacote)
                if n < 0:
                    return b"", f"write devolveu {n}: {d.error()}"
                time.sleep(0.02)
                resp = bytes(d.read(REPORT_LEN, 500))
            else:
                return b"", "método desconhecido"
        except Exception as e:
            return b"", f"{type(e).__name__}: {e}"
        if len(resp) == REPORT_LEN + 1 and resp[0] == 0:
            resp = resp[1:]  # tira o byte do número do relatório
        return resp, None

    def _detecta_metodo(self):
        consulta = self._monta(f"{ELC_QUERY:02x}{GET_VERSION:02x}")
        escolhido = None
        for m in (1, 2, 3, 4):
            resp, erro = self._tenta(m, consulta)
            ok = len(resp) > 3 and any(resp[1:])
            if self.verbose:
                print(f"[método {m}] {METODOS[m]}")
                print(f"    erro: {erro}")
                print(f"    resposta ({len(resp)} bytes): {resp.hex() if resp else '(vazia)'}")
                print(f"    {'RESPONDEU' if ok else 'sem resposta útil'}")
            if ok and escolhido is None:
                escolhido = m
                if not self.verbose:
                    break
        if escolhido is None:
            if self.verbose:
                print("Nenhum método recebeu resposta; vou usar o 1 mesmo assim.")
            else:
                print("Aviso: o teclado não respondeu a nenhum método. Vou tentar mesmo assim; "
                      "rode com --diagnostico e me mande o resultado.", file=sys.stderr)
            escolhido = 1
        return escolhido

    def _cmd(self, fragmento):
        pacote = self._monta(fragmento)
        if self.simular:
            print(pacote.hex())
            return b""
        resp, _ = self._tenta(self.metodo, pacote)
        time.sleep(0.01)
        return resp

    # ---------- comandos do controlador ----------
    @staticmethod
    def _tipo(anim):
        return USER_ANIMATION if (anim < 0x5B or anim > 0x60) else POWER_ANIMATION

    def _anim(self, sub, anim):
        return self._cmd(f"{self._tipo(anim):02x}{sub:04x}{anim:04x}")

    def dim(self, nivel):
        zonas = "".join(f"{z:02x}" for z in ZONES)
        self._cmd(f"{DIMMING:02x}{nivel:02x}{len(ZONES):04x}{zonas}")

    def _serie(self):
        zonas = "".join(f"{z:02x}" for z in ZONES)
        self._cmd(f"{START_SERIES:02x}01{len(ZONES):04x}{zonas}")

    def _acao(self, duracao, tempo, r, g, b):
        self._cmd(f"{ADD_ACTION:02x}{COLOR:02x}{duracao:04x}{tempo:04x}{r:02x}{g:02x}{b:02x}")

    def _grava(self, anim, passos):
        self._anim(REMOVE, anim)
        self._anim(START_NEW, anim)
        self._serie()
        for (duracao, tempo, r, g, b) in passos:
            self._acao(duracao, tempo, r, g, b)
        self._anim(FINISH_SAVE, anim)
        self._anim(SET_DEFAULT, anim)

    # ---------- ações de alto nível ----------
    def cor(self, r, g, b):
        self.dim(0)  # brilho máximo
        cheio = [(DURATION_MAX, TEMPO_MIN, r, g, b)]
        apagado = [(DURATION_MAX, TEMPO_MIN, 0, 0, 0)]
        meio = [(DURATION_MAX, TEMPO_MIN, r // 2, g // 2, b // 2)]
        self._grava(AC_SLEEP, apagado)
        self._grava(AC_CHARGED, cheio)
        self._grava(AC_CHARGING, cheio)
        self._grava(DC_SLEEP, apagado)
        self._grava(DC_ON, meio)  # metade do brilho na bateria (igual ao Linux)
        self._grava(DC_LOW, [(DURATION_BATTERY_LOW, TEMPO_MIN, 255, 0, 0),
                             (DURATION_BATTERY_LOW, TEMPO_MIN, 0, 0, 0)])

    def desligar(self):
        self.cor(0, 0, 0)

    def versao(self):
        if self.simular:
            return None
        resp = self._cmd(f"{ELC_QUERY:02x}{GET_VERSION:02x}")
        return tuple(resp[3:6]) if len(resp) >= 6 else None


def hex_cor(texto):
    v = int(texto, 16)
    return (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF


PRESETS = [
    ("Azul", 0x0000FF), ("Azul claro", 0x00AAFF), ("Ciano", 0x00FFFF),
    ("Roxo", 0x7733FF), ("Rosa", 0xFF2D95), ("Vermelho", 0xFF0000),
    ("Laranja", 0xFF7700), ("Amarelo", 0xFFDD00), ("Verde", 0x00FF44),
    ("Branco", 0xFFFFFF),
]


def janela(metodo=None):
    import tkinter as tk
    from tkinter import colorchooser, messagebox

    def aplica(valor):
        try:
            Teclado(metodo=metodo).cor((valor >> 16) & 255, (valor >> 8) & 255, valor & 255)
        except SystemExit as e:
            messagebox.showerror("Cor do Teclado", str(e))
        except Exception as e:
            messagebox.showerror("Cor do Teclado", f"{type(e).__name__}: {e}")

    raiz = tk.Tk()
    raiz.title("Cor do Teclado — Dell G15")
    raiz.resizable(False, False)
    tk.Label(raiz, text="Escolha a cor do teclado", font=("Segoe UI", 12, "bold")).grid(
        row=0, column=0, columnspan=5, padx=12, pady=(12, 6))
    for i, (nome, valor) in enumerate(PRESETS):
        cor_hex = f"#{valor:06x}"
        fg = "black" if valor in (0xFFFFFF, 0xFFDD00, 0x00FFFF, 0x00FF44) else "white"
        tk.Button(raiz, text=nome, bg=cor_hex, fg=fg, width=11, height=2,
                  command=lambda v=valor: aplica(v)).grid(
            row=1 + i // 5, column=i % 5, padx=4, pady=4)

    def outra():
        _, hx = colorchooser.askcolor(title="Qualquer cor")
        if hx:
            aplica(int(hx[1:], 16))

    tk.Button(raiz, text="Outra cor…", width=24, command=outra).grid(
        row=3, column=0, columnspan=3, pady=8)
    tk.Button(raiz, text="Desligar luz", width=24, command=lambda: aplica(0)).grid(
        row=3, column=2, columnspan=3, pady=8)
    raiz.mainloop()


def main():
    p = argparse.ArgumentParser(description="Cor do teclado do Dell G15 no Windows")
    p.add_argument("--cor", type=hex_cor, help="cor no formato 0xRRGGBB")
    p.add_argument("--acender", action="store_true", help="liga em branco")
    p.add_argument("--desligar", action="store_true", help="apaga a luz")
    p.add_argument("--diagnostico", action="store_true", help="testa os métodos de comunicação")
    p.add_argument("--metodo", type=int, choices=(1, 2, 3, 4), help="força um método de comunicação")
    p.add_argument("--simular", action="store_true", help="só imprime os pacotes, não envia")
    a = p.parse_args()

    if a.diagnostico:
        try:
            import hid
        except ImportError:
            sys.exit("Falta a biblioteca. Rode:  python -m pip install hidapi")
        achados = hid.enumerate(VID, 0)
        print("Dispositivos 187c encontrados:", len(achados))
        for d in achados:
            print(f"  pid={d['product_id']:04x} interface={d.get('interface_number')} "
                  f"uso={d.get('usage_page')}/{d.get('usage')}")
        if achados:
            try:
                d0 = hid.device()
                d0.open_path(achados[0]["path"])
                desc = bytes(d0.get_report_descriptor())
                print("Descritor HID:", desc.hex())
                d0.close()
            except Exception as e:
                print("Descritor HID indisponível:", type(e).__name__, e)
            t = Teclado(verbose=True)
            print("Método escolhido:", t.metodo, "-", METODOS[t.metodo])
            print("Versão do firmware:", t.versao())
        return

    if a.simular:
        t = Teclado(simular=True)
    elif a.cor or a.acender or a.desligar:
        t = Teclado(metodo=a.metodo)
    else:
        janela(a.metodo)
        return

    if a.desligar:
        t.desligar()
    elif a.acender:
        t.cor(255, 255, 255)
    elif a.cor:
        t.cor(*a.cor)
    print("Pronto.")


if __name__ == "__main__":
    main()
