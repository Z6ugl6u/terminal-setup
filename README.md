<div align="center">

# terminal-setup

**One-command terminal setup for Windows & WSL/Linux**

[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D4?logo=windows)](windows/setup.ps1)
[![WSL](https://img.shields.io/badge/WSL-Ubuntu%20%7C%20Debian%20%7C%20Kali%20%7C%20Arch-E95420?logo=linux&logoColor=white)](wsl/setup.sh)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-5391FE?logo=powershell&logoColor=white)](windows/setup.ps1)
[![License: Unlicense](https://img.shields.io/badge/License-Unlicense-blue)](LICENSE)

> Transforms a plain PowerShell/CMD/WSL terminal into a productive, beautiful environment —
> persistent history, smart completions, Powerline prompt, and modern CLI tools.
> No admin rights required.

</div>

---

## Quick Install

### Windows (PowerShell)
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm https://raw.githubusercontent.com/Z6ugl6u/terminal-setup/main/windows/setup.ps1 | iex
```

### WSL / Linux
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Z6ugl6u/terminal-setup/main/wsl/setup.sh)
```

---

## What Gets Installed

### Windows — `setup.ps1`

| Tool | Role | Shortcut |
|------|------|----------|
| [PSReadLine](https://github.com/PowerShell/PSReadLine) | Persistent history + ListView predictions | `↑↓` · `Ctrl+R` |
| [Oh My Posh](https://ohmyposh.dev/) | Colorful Powerline prompt | — |
| [McFly](https://github.com/cantino/mcfly) | AI-powered history search | `Ctrl+R` |
| [navi](https://github.com/denisidoro/navi) | Interactive cheatsheets | `Ctrl+G` |
| [tldr](https://github.com/dbrgn/tealdeer) | Simplified man pages | `tldr <cmd>` |
| [Clink](https://github.com/chrisant996/clink) | Persistent history for CMD | — |
| MesloLGS NF | Nerd Font (icons) | — |
| Windows Terminal | Auto-config (font + WSL home dir) | — |

### WSL / Linux — `setup.sh`

| Tool | Role | Shortcut |
|------|------|----------|
| [zsh](https://www.zsh.org/) + [Oh My Zsh](https://ohmyz.sh/) | Shell + framework | — |
| [Powerlevel10k](https://github.com/romkatv/powerlevel10k) | Colorful Powerline prompt | `p10k configure` |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Grey inline suggestions | `→` |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Command syntax coloring | — |
| [zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) | Prefix-based history | `↑↓` |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | `Ctrl+R` |
| [McFly](https://github.com/cantino/mcfly) | AI-powered history search | `Ctrl+R` |
| [navi](https://github.com/denisidoro/navi) | Interactive cheatsheets | `Ctrl+G` |
| [eza](https://github.com/eza-community/eza) | Modern `ls` with icons | `ll` · `lt` |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting | `cat` |
| [fd](https://github.com/sharkdp/fd) | Modern `find` | `fd` |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast `grep` replacement | `rg` |
| [tldr](https://github.com/dbrgn/tealdeer) | Simplified man pages | `tldr <cmd>` |
| htop · ncdu | Process monitor / disk analyzer | — |

---

## Keyboard Shortcuts

| Shortcut | Windows | WSL / Linux |
|----------|---------|-------------|
| `Ctrl+R` | History search | Fuzzy search (fzf / McFly) |
| `Ctrl+G` | navi cheatsheets | navi cheatsheets |
| `↑ / ↓` | Prefix history search (PSReadLine) | Prefix history search |
| `Double ESC` | — | Prepend `sudo` to current command |
| `Tab` | Smart completion | Smart completion |

---

## Compatibility

| Environment | Version | Status |
|-------------|---------|--------|
| Windows 10 / 11 | PowerShell 5.1+ | ✅ |
| Ubuntu (WSL / native) | 20.04 · 22.04 · 24.04 | ✅ |
| Debian (WSL / native) | 11 · 12 | ✅ |
| Kali Linux | Rolling | ✅ |
| Arch Linux | Rolling | ✅ |
| Fedora | 38+ | ✅ |
| x86_64 | — | ✅ |
| ARM64 (aarch64) | — | ✅ |

---

## Repository Structure

```
terminal-setup/
├── README.md
├── LICENSE
├── .gitignore
├── windows/
│   └── setup.ps1        # PowerShell, CMD, Windows Terminal, Oh My Posh
└── wsl/
    └── setup.sh         # zsh, Oh My Zsh, Powerlevel10k, modern CLI tools
```

---

## Credits

This project bundles configuration and automates the installation of these open-source tools:

- [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh)
- [romkatv/powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [JanDeDobbeleer/oh-my-posh](https://github.com/JanDeDobbeleer/oh-my-posh)
- [cantino/mcfly](https://github.com/cantino/mcfly)
- [denisidoro/navi](https://github.com/denisidoro/navi)
- [eza-community/eza](https://github.com/eza-community/eza)
- [sharkdp/bat](https://github.com/sharkdp/bat)
- [sharkdp/fd](https://github.com/sharkdp/fd)
- [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)
- [junegunn/fzf](https://github.com/junegunn/fzf)
- [chrisant996/clink](https://github.com/chrisant996/clink)
- [PowerShell/PSReadLine](https://github.com/PowerShell/PSReadLine)
- [zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [zsh-users/zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [zsh-users/zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search)

---

## License

This is free and unencumbered software released into the public domain.
Do whatever you want with it. See [LICENSE](LICENSE) for details.
