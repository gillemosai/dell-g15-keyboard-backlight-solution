<div align="center">

# ⌨️ dell-g15-keyboard-linux

**A luz do teclado do seu Dell G15 apagou no Linux? Este projeto acende de volta — e deixa você escolher a cor com um clique.**

[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue.svg)](LICENSE)
[![Plataforma](https://img.shields.io/badge/plataforma-Linux-FCC624?logo=linux&logoColor=black)](#-compatibilidade)
[![Dell G15](https://img.shields.io/badge/Dell-G15-007DB8?logo=dell&logoColor=white)](#-compatibilidade)
[![Bash](https://img.shields.io/badge/Bash-4%2B-4EAA25?logo=gnubash&logoColor=white)](install.sh)
[![Python](https://img.shields.io/badge/Python-3-3776AB?logo=python&logoColor=white)](#-créditos)
[![PRs bem-vindos](https://img.shields.io/badge/PRs-bem--vindos-brightgreen.svg)](#-como-contribuir)
[![Stars](https://img.shields.io/github/stars/gillemosai/dell-g15-keyboard-linux?style=social)](https://github.com/gillemosai/dell-g15-keyboard-linux/stargazers)
[![Último commit](https://img.shields.io/github/last-commit/gillemosai/dell-g15-keyboard-linux)](https://github.com/gillemosai/dell-g15-keyboard-linux/commits)
[![Site](https://img.shields.io/badge/site-gillemosai.com-6C3BFF)](https://gillemosai.com)

[Instalação](#-instalação) · [Como usar](#-como-usar) · [Compatibilidade](#-compatibilidade) · [Problemas](#-solução-de-problemas) · [English](#-english)

</div>

---

## 🤔 O problema

Muitos Dell G15 vêm com teclado RGB controlado por um chip da Alienware (`187c:0550`). No Windows, quem cuida dele é o Alienware Command Center. No Linux não existe nada equivalente instalado por padrão — então o teclado fica apagado, a tecla **Fn + F10** não resolve e a luz pode sumir de novo depois de suspender o notebook.

## ✨ O que este projeto faz

Um instalador que **identifica sozinho** o seu notebook, o sistema e o tipo de luz do teclado, e configura tudo:

- 🔍 **Detecta** o modelo, a distribuição Linux, o gerenciador de pacotes e o controlador de luz
- 🎨 **Atalho "Cor do Teclado"** no menu: abre uma janela com 10 cores prontas + seletor de qualquer cor
- 💾 **Lembra a última cor** e aplica automaticamente ao entrar no sistema
- 😴 **Reaplica a cor ao voltar da suspensão** — a causa mais comum do "apagou de novo"
- 🔐 **Sem senha a cada uso**: cria uma regra de permissão só para o controlador do teclado
- 🩺 **Diagnóstico** com um comando, para relatar problemas
- 🧹 **Desinstalador** que remove tudo o que foi criado

## 🚀 Instalação

Abra o terminal e rode:

```bash
git clone https://github.com/gillemosai/dell-g15-keyboard-linux
cd dell-g15-keyboard-linux
bash install.sh
```

> Rode **sem** `sudo`. O instalador pede a senha só nos passos que precisam.

O instalador mostra o que encontrou e o que vai fazer antes de começar. Exemplo de saída:

```
==> Identificando o notebook
    ✔ Dell Inc. Dell G15 5511
==> Identificando o sistema
    ✔ Zorin OS 17 · kernel 6.8.0 · GNOME
    ✔ Gerenciador de pacotes: apt
==> Procurando o controlador de luz do teclado
    ✔ Teclado RGB com controlador Alienware 187c:0550 (suportado)
```

## 🎨 Como usar

**Pelo menu:** procure **Cor do Teclado**, escolha a cor e clique em OK.

**Pelo terminal:**

| Comando | O que faz |
|---|---|
| `g15-teclado` | Abre a janela de cores |
| `g15-teclado --cor 0x00AAFF` | Aplica uma cor (formato `0xRRGGBB`) |
| `g15-teclado --auto` | Reaplica a última cor |
| `g15-teclado --desligar` | Apaga a luz |
| `g15-teclado --diagnostico` | Mostra informações para relatar problemas |

Cores prontas: azul, azul claro, ciano, roxo, rosa, vermelho, laranja, amarelo, verde, branco e "desligar luz".

> **Observação:** o controlador deixa a luz com metade do brilho quando o notebook está na bateria e pisca em vermelho com bateria baixa. É o comportamento padrão dele.

## 💻 Compatibilidade

| Modelo / controlador | Situação |
|---|---|
| Dell G15 **5511** — RGB `187c:0550` | ✅ Testado (Zorin OS) |
| Outros G15 com RGB `187c:0550` (ex.: 5525) | 🟡 Deve funcionar — usa o mesmo controlador. Conte como foi! |
| G15 com luz **branca** (`dell::kbd_backlight`, sem RGB) | 🟡 Suportado: liga/desliga no brilho máximo |
| G15 **5530** e mais novos — `187c:0551` | ❌ Ainda não suportado (outro protocolo). Alternativa: AWCC (`awcc-git` no AUR) |

**Distribuições:** Ubuntu, Zorin OS, Linux Mint, Pop!_OS, Debian (apt) · Fedora (dnf) · Arch, Manjaro (pacman) · openSUSE (zypper).

**Ambientes gráficos:** GNOME/Zorin (janela via `zenity`) · KDE Plasma (janela via `kdialog`) · sem interface gráfica (menu no terminal).

> A placa de vídeo (NVIDIA, AMD ou Intel) **não interfere** na luz do teclado. O instalador mostra qual é a sua só para ajudar no diagnóstico.

Não sabe qual controlador você tem? Rode `lsusb | grep 187c`.

## 🩺 Solução de problemas

<details>
<summary><b>O teclado não acendeu depois da instalação</b></summary>

Reinicie o computador (para a regra de permissão valer) e abra **Cor do Teclado**. Se ainda não funcionar, rode `g15-teclado --diagnostico` e [abra uma issue](https://github.com/gillemosai/dell-g15-keyboard-linux/issues/new?template=relatar-problema.md) com o resultado.
</details>

<details>
<summary><b>O atalho da Área de Trabalho não abre</b></summary>

Clique com o botão direito no ícone e escolha **Permitir execução** (ou **Confiar e executar**). Isso só é necessário na primeira vez.
</details>

<details>
<summary><b>Pede senha toda vez que troco a cor</b></summary>

A regra de permissão ainda não foi carregada. Reinicie o computador. Se persistir, confira se o arquivo `/etc/udev/rules.d/60-g15-teclado.rules` existe.
</details>

<details>
<summary><b>Aparece "Este projeto é para o Dell G15"</b></summary>

O instalador não reconheceu o modelo. Se o seu notebook tem o controlador `187c:0550` (confira com `lsusb`), rode `bash install.sh --forcar`.
</details>

## 🧹 Desinstalar

```bash
bash uninstall.sh
```

## 🤝 Como contribuir

Toda ajuda é bem-vinda, principalmente **relatos de outros modelos**:

1. Instale e teste no seu G15
2. Rode `g15-teclado --diagnostico`
3. [Abra uma issue](https://github.com/gillemosai/dell-g15-keyboard-linux/issues) dizendo se funcionou ou não

Pull requests com suporte a novos modelos, distribuições ou traduções também são bem-vindos.

## 🙏 Créditos

A comunicação com o chip do teclado é feita pelo [**G15kblight-cli**](https://github.com/Vescrity/G15kblight-cli), fork do [**Dell-G-Series-Controller**](https://github.com/cemkaya-mpi/Dell-G-Series-Controller) de cemkaya-mpi, baseado no trabalho da comunidade em [trackmastersteve/alienfx#41](https://github.com/trackmastersteve/alienfx/issues/41). Esse controlador é baixado durante a instalação e mantém a licença GPL-3.0 original.

Este projeto adiciona a detecção automática, o instalador multi-distro, o seletor de cores, a persistência após suspensão e o desinstalador.

## 🌎 English

**Dell G15 keyboard backlight not working on Linux?** This project auto-detects your model, distro and backlight controller, installs everything needed and adds a **"Keyboard Color"** app with a color picker. It remembers your color, re-applies it on login and after suspend, and works without asking for your password each time.

```bash
git clone https://github.com/gillemosai/dell-g15-keyboard-linux
cd dell-g15-keyboard-linux
bash install.sh
```

Tested on the G15 5511 (`187c:0550`). Other `187c:0550` models should work; `187c:0551` (G15 5530+) is not supported yet. Reports and PRs are welcome — the interface is in Portuguese, translations are a great first contribution.

## ⚠️ Aviso

Projeto independente, sem vínculo com a Dell ou a Alienware. Use por sua conta e risco — ele só altera a luz do teclado e pode ser removido a qualquer momento com o `uninstall.sh`.

---

<div align="center">

### Feito por Gil Lemos

Eu traduzo tecnologia e inteligência artificial em soluções práticas — automações, apps e ferramentas para quem quer usar tecnologia sem complicação.

**Conheça meus outros projetos ou fale comigo sobre o seu:**

[![gillemosai.com](https://img.shields.io/badge/🌐_gillemosai.com-Conheça_meus_projetos-6C3BFF?style=for-the-badge)](https://gillemosai.com)

Se este projeto te ajudou, deixe uma ⭐ — isso ajuda outras pessoas com o mesmo problema a encontrá-lo.

</div>
