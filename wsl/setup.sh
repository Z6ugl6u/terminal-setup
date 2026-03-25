#!/usr/bin/env bash
# =============================================================================
#  Terminal Setup for WSL / Linux
#  Compatible : Ubuntu 20.04+, Debian 11+, Kali Linux, Arch Linux, Fedora
#  Architecture : x86_64, aarch64 (ARM64)
# =============================================================================

# ─── Couleurs ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; WHITE='\033[0;37m'; NC='\033[0m'

INSTALLED=(); CONFIGURED=(); SKIPPED=(); FAILED=()

step()   { echo -e "\n${CYAN}=== $1 ===${NC}"; }
ok()     { echo -e "  ${GREEN}[+]${NC} $1";          CONFIGURED+=("$1"); }
skip()   { echo -e "  ${YELLOW}[~]${NC} $1";         SKIPPED+=("$1"); }
fail()   { echo -e "  ${RED}[!]${NC} $1";            FAILED+=("$1"); }
info()   { echo -e "  ${WHITE}[*]${NC} $1"; }
inst()   { echo -e "  ${GREEN}[+]${NC} $1 installe"; INSTALLED+=("$1"); }
cmd_ok() { command -v "$1" &>/dev/null; }

# ─── Detection distro ─────────────────────────────────────────────────────────
detect_distro() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${ID:-unknown}"
    elif cmd_ok lsb_release; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

# ─── Detection architecture ───────────────────────────────────────────────────
detect_arch() {
    case "$(uname -m)" in
        x86_64)          echo "x86_64" ;;
        aarch64|arm64)   echo "aarch64" ;;
        armv7l)          echo "armv7" ;;
        *)               echo "x86_64" ;;
    esac
}

# ─── Detection WSL ────────────────────────────────────────────────────────────
detect_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null
}

# ─── Gestionnaire de paquets ──────────────────────────────────────────────────
PKG_MANAGER=""
PKG_INSTALL=""
PKG_CHECK=""

setup_pkg_manager() {
    if cmd_ok apt-get; then
        PKG_MANAGER="apt"
        PKG_INSTALL="sudo apt-get install -y -qq"
        PKG_CHECK="dpkg -s"
    elif cmd_ok pacman; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="sudo pacman -S --noconfirm --needed"
        PKG_CHECK="pacman -Q"
    elif cmd_ok dnf; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="sudo dnf install -y -q"
        PKG_CHECK="rpm -q"
    elif cmd_ok yum; then
        PKG_MANAGER="yum"
        PKG_INSTALL="sudo yum install -y -q"
        PKG_CHECK="rpm -q"
    else
        fail "Aucun gestionnaire de paquets reconnu (apt/pacman/dnf/yum)"
        exit 1
    fi
}

# Noms des paquets selon le gestionnaire
pkg_name() {
    local tool="$1"
    case "$PKG_MANAGER" in
        apt)
            case "$tool" in
                bat)     echo "bat" ;;
                fd)      echo "fd-find" ;;
                rg)      echo "ripgrep" ;;
                *)       echo "$tool" ;;
            esac ;;
        pacman)
            case "$tool" in
                bat)     echo "bat" ;;
                fd)      echo "fd" ;;
                rg)      echo "ripgrep" ;;
                fzf)     echo "fzf" ;;
                htop)    echo "htop" ;;
                ncdu)    echo "ncdu" ;;
                *)       echo "$tool" ;;
            esac ;;
        dnf|yum)
            case "$tool" in
                bat)     echo "bat" ;;
                fd)      echo "fd-find" ;;
                rg)      echo "ripgrep" ;;
                *)       echo "$tool" ;;
            esac ;;
    esac
}

pkg_install() {
    local tool="$1"
    local pkg
    pkg=$(pkg_name "$tool")
    if $PKG_CHECK "$pkg" &>/dev/null 2>&1; then
        skip "$pkg deja installe"
        return 0
    fi
    info "Installation de $pkg..."
    if $PKG_INSTALL "$pkg" 2>/dev/null; then
        inst "$pkg"
        return 0
    else
        fail "$pkg"
        return 1
    fi
}

# ─── Installation binaire depuis GitHub releases ──────────────────────────────
install_binary_from_github() {
    local name="$1" repo="$2" url="$3" dest="${4:-$HOME/.local/bin/$name}"
    info "Installation $name depuis GitHub..."
    if curl -Lo "/tmp/${name}_dl" "$url" 2>/dev/null; then
        # Detecter si c'est une archive ou un binaire direct
        if file "/tmp/${name}_dl" 2>/dev/null | grep -q "gzip\|tar\|zip"; then
            mkdir -p "/tmp/${name}_extract"
            tar xzf "/tmp/${name}_dl" -C "/tmp/${name}_extract" 2>/dev/null || \
                unzip -q "/tmp/${name}_dl" -d "/tmp/${name}_extract" 2>/dev/null
            find "/tmp/${name}_extract" -name "$name" -type f -exec cp {} "$dest" \; 2>/dev/null
            rm -rf "/tmp/${name}_extract"
        else
            cp "/tmp/${name}_dl" "$dest"
        fi
        rm -f "/tmp/${name}_dl"
        chmod +x "$dest" 2>/dev/null
        if cmd_ok "$name"; then
            inst "$name"
            return 0
        fi
    fi
    fail "$name (telechargement echoue : $repo)"
    return 1
}

# ─── Variables globales ───────────────────────────────────────────────────────
DISTRO=$(detect_distro)
ARCH=$(detect_arch)
IS_WSL=false
detect_wsl && IS_WSL=true

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

echo -e "\n${MAGENTA}  Terminal Setup for WSL / Linux${NC}"
echo -e "  Distro : ${WHITE}$DISTRO${NC} | Arch : ${WHITE}$ARCH${NC} | WSL : ${WHITE}$IS_WSL${NC}\n"

# ─── 0. Gestionnaire de paquets ───────────────────────────────────────────────
step "0. Detection gestionnaire de paquets"
setup_pkg_manager
ok "Gestionnaire : $PKG_MANAGER"

# ─── 1. Mise a jour ───────────────────────────────────────────────────────────
step "1. Mise a jour"
case "$PKG_MANAGER" in
    apt)    sudo apt-get update -qq 2>/dev/null && ok "apt mis a jour" || fail "apt update" ;;
    pacman) sudo pacman -Sy --noconfirm 2>/dev/null && ok "pacman mis a jour" || fail "pacman -Sy" ;;
    dnf)    sudo dnf check-update -q 2>/dev/null; ok "dnf verifie" ;;
    yum)    ok "yum (skip update)" ;;
esac

# ─── 2. Dependances de base ───────────────────────────────────────────────────
step "2. Dependances de base"
for pkg in git curl wget unzip; do
    pkg_install "$pkg"
done

# ─── 3. Locale (evite les warnings) ──────────────────────────────────────────
step "3. Locale en_US.UTF-8"
if locale -a 2>/dev/null | grep -q "en_US.utf8"; then
    skip "locale en_US.UTF-8 deja presente"
elif [ "$PKG_MANAGER" = "apt" ]; then
    sudo locale-gen en_US.UTF-8 2>/dev/null && ok "locale en_US.UTF-8 generee" || fail "locale-gen"
    echo 'LANG=en_US.UTF-8' | sudo tee /etc/default/locale > /dev/null 2>&1
else
    skip "locale (configuration manuelle si necessaire)"
fi

# ─── 4. Zsh ───────────────────────────────────────────────────────────────────
step "4. Zsh - Shell principal"
pkg_install zsh

ZSH_BIN=$(command -v zsh 2>/dev/null)
if [ -n "$ZSH_BIN" ] && [ "$SHELL" != "$ZSH_BIN" ]; then
    info "Changement du shell par defaut vers zsh..."
    if chsh -s "$ZSH_BIN" "$USER" 2>/dev/null; then
        ok "Shell par defaut = zsh"
    else
        fail "chsh echoue - lancez manuellement : chsh -s \$(which zsh)"
    fi
else
    skip "zsh deja shell par defaut"
fi

# ─── 5. Oh My Zsh ─────────────────────────────────────────────────────────────
step "5. Oh My Zsh"
if [ -d "$HOME/.oh-my-zsh" ]; then
    skip "Oh My Zsh deja installe"
else
    info "Installation Oh My Zsh (mode non-interactif)..."
    if RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" 2>/dev/null; then
        inst "Oh My Zsh"
    else
        fail "Oh My Zsh (verifiez votre connexion internet)"
    fi
fi

# ─── 6. Powerlevel10k ─────────────────────────────────────────────────────────
step "6. Powerlevel10k - Prompt Powerline"
P10K_DIR="$ZSH_CUSTOM/themes/powerlevel10k"
if [ -d "$P10K_DIR" ]; then
    skip "Powerlevel10k deja installe"
else
    if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" 2>/dev/null; then
        inst "Powerlevel10k"
    else
        fail "Powerlevel10k"
    fi
fi

# ─── 7. Plugins zsh ───────────────────────────────────────────────────────────
step "7. Plugins zsh"

clone_plugin() {
    local name="$1" url="$2"
    local dir="$ZSH_CUSTOM/plugins/$name"
    if [ -d "$dir" ]; then
        skip "$name deja installe"
    elif git clone --depth=1 "$url" "$dir" 2>/dev/null; then
        inst "$name"
    else
        fail "$name"
    fi
}

clone_plugin "zsh-autosuggestions"          "https://github.com/zsh-users/zsh-autosuggestions"
clone_plugin "zsh-syntax-highlighting"      "https://github.com/zsh-users/zsh-syntax-highlighting"
clone_plugin "zsh-history-substring-search" "https://github.com/zsh-users/zsh-history-substring-search"

# ─── 8. fzf ───────────────────────────────────────────────────────────────────
step "8. fzf - Fuzzy search (Ctrl+R)"
if cmd_ok fzf; then
    skip "fzf deja installe"
elif ! pkg_install fzf; then
    # Fallback : installer via git
    if [ ! -d "$HOME/.fzf" ]; then
        git clone --depth=1 https://github.com/junegunn/fzf.git "$HOME/.fzf" 2>/dev/null
        "$HOME/.fzf/install" --all --no-bash --no-fish 2>/dev/null && inst "fzf (git)" || fail "fzf"
    fi
fi

# ─── 9. McFly ─────────────────────────────────────────────────────────────────
step "9. McFly - Historique contextuel intelligent"
if cmd_ok mcfly; then
    skip "McFly deja installe"
else
    info "Installation McFly..."
    if curl -LSfs https://raw.githubusercontent.com/cantino/mcfly/master/ci/install.sh 2>/dev/null \
        | sudo sh -s -- --git cantino/mcfly 2>/dev/null; then
        inst "McFly"
    else
        # Fallback : binaire pre-compile
        MCFLY_VER=$(curl -s https://api.github.com/repos/cantino/mcfly/releases/latest 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4)
        if [ -n "$MCFLY_VER" ]; then
            case "$ARCH" in
                x86_64)  MCFLY_ARCH="x86_64-unknown-linux-musl" ;;
                aarch64) MCFLY_ARCH="aarch64-unknown-linux-musl" ;;
                *)       MCFLY_ARCH="x86_64-unknown-linux-musl" ;;
            esac
            install_binary_from_github "mcfly" "cantino/mcfly" \
                "https://github.com/cantino/mcfly/releases/download/${MCFLY_VER}/mcfly-${MCFLY_VER}-${MCFLY_ARCH}.tar.gz" \
                "$LOCAL_BIN/mcfly"
        else
            fail "McFly - https://github.com/cantino/mcfly"
        fi
    fi
fi

# ─── 10. Outils modernes CLI ──────────────────────────────────────────────────
step "10. Outils CLI modernes"

# eza - ls moderne avec icones
if cmd_ok eza; then
    skip "eza deja installe"
else
    if ! pkg_install eza 2>/dev/null; then
        # Fallback : binaire pre-compile
        EZA_VER=$(curl -s https://api.github.com/repos/eza-community/eza/releases/latest 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4)
        if [ -n "$EZA_VER" ]; then
            case "$ARCH" in
                x86_64)  EZA_ARCH="x86_64-unknown-linux-musl" ;;
                aarch64) EZA_ARCH="aarch64-unknown-linux-gnu" ;;
                *)       EZA_ARCH="x86_64-unknown-linux-musl" ;;
            esac
            install_binary_from_github "eza" "eza-community/eza" \
                "https://github.com/eza-community/eza/releases/download/${EZA_VER}/eza_${EZA_ARCH}.tar.gz" \
                "$LOCAL_BIN/eza"
        else
            fail "eza"
        fi
    fi
fi

# bat - cat avec coloration syntaxique
pkg_install bat
# Sur Ubuntu/Debian, bat s'appelle batcat
if cmd_ok batcat && ! cmd_ok bat; then
    ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat" 2>/dev/null
    info "Symlink bat -> batcat cree dans $LOCAL_BIN"
fi

# fd - find moderne
pkg_install fd
# Sur Ubuntu/Debian, fd s'appelle fdfind
if cmd_ok fdfind && ! cmd_ok fd; then
    ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd" 2>/dev/null
    info "Symlink fd -> fdfind cree dans $LOCAL_BIN"
fi

pkg_install rg    # ripgrep
pkg_install htop
pkg_install ncdu

# tldr
if cmd_ok tldr; then
    skip "tldr deja installe"
elif ! pkg_install tldr 2>/dev/null; then
    if cmd_ok npm; then
        npm install -g tldr 2>/dev/null && inst "tldr (npm)" || fail "tldr"
    else
        fail "tldr (installez npm ou tldr manuellement)"
    fi
fi

# navi - cheatsheets interactives
if cmd_ok navi; then
    skip "navi deja installe"
else
    info "Installation navi..."
    NAVI_VER=$(curl -s https://api.github.com/repos/denisidoro/navi/releases/latest 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4)
    if [ -n "$NAVI_VER" ]; then
        case "$ARCH" in
            x86_64)  NAVI_ARCH="x86_64-unknown-linux-musl" ;;
            aarch64) NAVI_ARCH="aarch64-unknown-linux-musl" ;;
            *)       NAVI_ARCH="x86_64-unknown-linux-musl" ;;
        esac
        # Le nom du fichier release navi inclut la version : navi-v2.x.x-ARCH.tar.gz
        NAVI_URL="https://github.com/denisidoro/navi/releases/download/${NAVI_VER}/navi-${NAVI_VER}-${NAVI_ARCH}.tar.gz"
        install_binary_from_github "navi" "denisidoro/navi" "$NAVI_URL" "$LOCAL_BIN/navi"
    else
        fail "navi (API GitHub inaccessible)"
    fi
fi

# ─── 11. Configuration .zshrc ─────────────────────────────────────────────────
step "11. Configuration ~/.zshrc"

[ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$HOME/.zshrc.bak" && info "Backup : ~/.zshrc.bak"

# Construire la condition VCS selon l'environnement
if $IS_WSL; then
    VCS_DISABLED="typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='/mnt/*'"
else
    VCS_DISABLED="# VCS actif sur tous les chemins (pas de WSL)"
fi

cat > "$HOME/.zshrc" << ZSHRC
# Instant prompt Powerlevel10k - DOIT ETRE EN PREMIER
if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%%):-\%n}.zsh" ]]; then
  source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%%):-\%n}.zsh"
fi

# =============================================================================
#  ~/.zshrc - github.com/YOUR_USERNAME/terminal-setup
# =============================================================================

export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins (zsh-syntax-highlighting DOIT etre en dernier)
plugins=(
    git
    sudo
    z
    fzf
    zsh-autosuggestions
    zsh-history-substring-search
    zsh-syntax-highlighting
)

source \$ZSH/oh-my-zsh.sh 2>/dev/null

# ── Historique ────────────────────────────────────────────────────────────────
HISTFILE="\$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_FIND_NO_DUPS
setopt SHARE_HISTORY INC_APPEND_HISTORY EXTENDED_HISTORY

# ── Clavier ───────────────────────────────────────────────────────────────────
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ]   && source /usr/share/doc/fzf/examples/completion.zsh
# fzf installe via git
[ -f "\$HOME/.fzf.zsh" ] && source "\$HOME/.fzf.zsh"

# ── McFly ─────────────────────────────────────────────────────────────────────
if command -v mcfly &>/dev/null; then
    export MCFLY_FUZZY=2
    export MCFLY_RESULTS=50
    export MCFLY_INTERFACE_VIEW=BOTTOM
    eval "\$(mcfly init zsh)"
fi

# ── navi (Ctrl+G = cheatsheets) ───────────────────────────────────────────────
command -v navi &>/dev/null && eval "\$(navi widget zsh)"

# ── PATH ──────────────────────────────────────────────────────────────────────
export PATH="\$HOME/.local/bin:\$PATH"

# ── Aliases eza (icones sur Linux natif, simple sur /mnt/ WSL) ────────────────
if command -v eza &>/dev/null; then
    _ls() {
        if [[ "\$PWD" == /mnt/* ]]; then eza --group-directories-first "\$@"
        else eza --icons --group-directories-first "\$@"; fi
    }
    _ll() {
        if [[ "\$PWD" == /mnt/* ]]; then eza -lah --group-directories-first "\$@"
        else eza -lah --icons --group-directories-first --git "\$@"; fi
    }
    alias ls='_ls'
    alias ll='_ll'
    alias la='eza -a --icons'
    alias lt='eza --tree --icons --level=2'
else
    alias ll='ls -lah --color=auto'
    alias la='ls -a --color=auto'
fi

# ── Aliases cat (bat) ─────────────────────────────────────────────────────────
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
elif command -v batcat &>/dev/null; then
    alias cat='batcat --paging=never'
fi

# ── Aliases navigation ────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias cls='clear'
alias h='history'
alias reload='source ~/.zshrc'

# ── Aliases git ───────────────────────────────────────────────────────────────
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --all --decorate'
alias gd='git diff'
alias gco='git checkout'

# ── Aliases systeme ───────────────────────────────────────────────────────────
alias ports='ss -tlnp'
alias myip='curl -s --max-time 5 ifconfig.me'
alias df='df -h'
alias free='free -h'
alias top='htop'
alias dps='docker ps'
alias dpsa='docker ps -a'

# ── Fonctions ─────────────────────────────────────────────────────────────────
mkcd()  { mkdir -p "\$@" && cd "\$_"; }
hgrep() { history | grep "\$@"; }
extract() {
    [ -f "\$1" ] || { echo "'\$1' non trouve"; return 1; }
    case "\$1" in
        *.tar.gz|*.tgz) tar xzf "\$1" ;;
        *.tar.bz2)       tar xjf "\$1" ;;
        *.tar.xz)        tar xJf "\$1" ;;
        *.zip)           unzip "\$1" ;;
        *.gz)            gunzip "\$1" ;;
        *.7z)            7z x "\$1" ;;
        *.rar)           unrar x "\$1" ;;
        *)               echo "Format non supporte : \$1" ;;
    esac
}
myinfo() {
    echo "Host  : \$(hostname)"
    echo "Local : \$(ip a 2>/dev/null | grep 'inet ' | grep -v '127.0.0' | awk '{print \$2}' | head -1)"
    echo "Pub   : \$(curl -s --max-time 5 ifconfig.me 2>/dev/null)"
}

# ── Variables d'environnement ─────────────────────────────────────────────────
export EDITOR='nano'
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border"
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=down:3:wrap"

command -v bat    &>/dev/null && export MANPAGER="sh -c 'col -bx | bat -l man -p'"
command -v batcat &>/dev/null && ! command -v bat &>/dev/null && \
    export MANPAGER="sh -c 'col -bx | batcat -l man -p'"

# ── Powerlevel10k ─────────────────────────────────────────────────────────────
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
ZSHRC

ok "~/.zshrc configure"

# ─── 12. Config Powerlevel10k ─────────────────────────────────────────────────
step "12. Powerlevel10k - Configuration (classic powerline + ❯)"

cat > "$HOME/.p10k.zsh" << 'P10K'
# ~/.p10k.zsh - Powerlevel10k config
# Regenerez avec : p10k configure

typeset -g POWERLEVEL9K_MODE=nerdfont-v3
typeset -g POWERLEVEL9K_ICON_PADDING=moderate

# Segments gauche : infos sur la ligne 1, ❯ sur la ligne 2
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs newline prompt_char)

# Segments droite : status + numero commande + duree + heure
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status history command_execution_time time)

# Separateurs Powerline (fleches remplies)
typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR='\uE0B0'
typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR='\uE0B1'
typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR='\uE0B2'
typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR='\uE0B3'
typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL='\uE0B0'
typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL='\uE0B2'

# context (user@hostname) - violet
typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_BACKGROUND=55
typeset -g POWERLEVEL9K_CONTEXT_DEFAULT_FOREGROUND=231
typeset -g POWERLEVEL9K_CONTEXT_ROOT_BACKGROUND=196
typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND=231
typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%n@%m'
typeset -g POWERLEVEL9K_ALWAYS_SHOW_CONTEXT=true

# dir (dossier) - bleu
typeset -g POWERLEVEL9K_DIR_BACKGROUND=31
typeset -g POWERLEVEL9K_DIR_FOREGROUND=231
typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=153
typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true
typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique

# vcs (git) - vert/orange/rouge selon etat
typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=28
typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=231
typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=178
typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=232
typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=39
typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=232
typeset -g POWERLEVEL9K_VCS_CONFLICTED_BACKGROUND=196
typeset -g POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND=231
# Desactiver git check sur /mnt/ (WSL Windows filesystem = lent)
typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='/mnt/*'

# status (✔ succes / ✘ erreur)
typeset -g POWERLEVEL9K_STATUS_OK=true
typeset -g POWERLEVEL9K_STATUS_OK_BACKGROUND=28
typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND=231
typeset -g POWERLEVEL9K_STATUS_OK_VISUAL_IDENTIFIER_EXPANSION='✔'
typeset -g POWERLEVEL9K_STATUS_ERROR=true
typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND=196
typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=231
typeset -g POWERLEVEL9K_STATUS_ERROR_VISUAL_IDENTIFIER_EXPANSION='✘'

# history (numero de commande)
typeset -g POWERLEVEL9K_HISTORY_BACKGROUND=238
typeset -g POWERLEVEL9K_HISTORY_FOREGROUND=231

# command_execution_time (affiche si > 1s)
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=1
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND=236
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=248
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='d h m s'

# time (heure)
typeset -g POWERLEVEL9K_TIME_BACKGROUND=240
typeset -g POWERLEVEL9K_TIME_FOREGROUND=231
typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'
typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=true

# prompt_char (❯ vert / rouge sur nouvelle ligne)
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_FOREGROUND=76
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_FOREGROUND=196
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_CONTENT_EXPANSION='❯'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_CONTENT_EXPANSION='❯'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VICMD_CONTENT_EXPANSION='❮'
typeset -g POWERLEVEL9K_PROMPT_CHAR_BACKGROUND=
typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=

# Options generales
typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose
typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off
P10K

ok "~/.p10k.zsh configure"

# ─── 13. Cheatsheets navi ─────────────────────────────────────────────────────
step "13. navi - Cheatsheets personnalisees"

NAVI_DIR="$HOME/.local/share/navi/cheats/personal"
mkdir -p "$NAVI_DIR"

cat > "$NAVI_DIR/custom.cheat" << 'CHEATS'
% reseau, linux

# Toutes les interfaces reseau
ip a

# Connexions actives TCP
ss -tlnp

# Connexions actives UDP
ss -ulnp

# Tester la connectivite
ping -c 4 <host>

# Traceroute
traceroute <host>

# Resoudre un nom DNS
dig <host>

# Capture de trafic
sudo tcpdump -i <interface> -n -w /tmp/capture.pcap

% reseau, nmap

# Scan rapide
nmap -T4 -F <target>

# Scan SYN tous les ports
nmap -sS -p- <target>

# Detection version + OS
nmap -sV -O <target>

# Scripts NSE + versions
nmap -sC -sV <target>

# Ping sweep
nmap -sn <cidr>

# Export tous les formats
nmap -sC -sV -oA <output> <target>

% pentest, linux

# Binaires SUID
find / -perm -4000 -type f 2>/dev/null

# Capabilities
getcap -r / 2>/dev/null

# Droits sudo
sudo -l

# Services actifs
systemctl list-units --type=service --state=running

# Cron
crontab -l; ls /etc/cron* 2>/dev/null

# Infos systeme
uname -a && id && whoami

% git

# Cloner un depot
git clone <url>

# Log compact en graphe
git log --oneline --graph --all

# Annuler le dernier commit
git reset --soft HEAD~1

# Chercher dans l historique
git log -S "<string>" --all

% docker

# Shell interactif
docker run -it --rm <image> /bin/bash

# Conteneur en arriere-plan
docker run -d -p <host_port>:<container_port> <image>

# Shell dans conteneur existant
docker exec -it <container> /bin/bash

# Nettoyage complet
docker system prune -af
CHEATS

ok "Cheatsheets navi : $NAVI_DIR/custom.cheat"

# ─── 14. .zshenv ──────────────────────────────────────────────────────────────
step "14. ~/.zshenv - Variables globales"

cat > "$HOME/.zshenv" << 'ZSHENV'
export PATH="$HOME/.local/bin:$PATH"
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'
ZSHENV

ok "~/.zshenv configure"

# ─── Resume ───────────────────────────────────────────────────────────────────
echo -e "\n${MAGENTA}============================================================${NC}"
echo -e "${MAGENTA}  RESUME FINAL${NC}"
echo -e "${MAGENTA}============================================================${NC}"

[ ${#INSTALLED[@]}  -gt 0 ] && echo -e "\n  ${GREEN}INSTALLE :${NC}"     && for i in "${INSTALLED[@]}";  do echo -e "    ${GREEN}+${NC} $i"; done
[ ${#CONFIGURED[@]} -gt 0 ] && echo -e "\n  ${CYAN}CONFIGURE :${NC}"    && for i in "${CONFIGURED[@]}"; do echo -e "    ${CYAN}~${NC} $i"; done
[ ${#SKIPPED[@]}    -gt 0 ] && echo -e "\n  ${YELLOW}DEJA PRESENT :${NC}" && for i in "${SKIPPED[@]}";    do echo -e "    ${YELLOW}=${NC} $i"; done
[ ${#FAILED[@]}     -gt 0 ] && echo -e "\n  ${RED}ECHECS :${NC}"         && for i in "${FAILED[@]}";     do echo -e "    ${RED}!${NC} $i"; done

echo -e "\n${WHITE}  Actions post-installation :
  1. Fermez et relancez votre terminal (zsh se charge automatiquement)
  2. Installez une Nerd Font si les icones s'affichent en carres :
       - Recommandee : MesloLGS NF  (installee auto par setup.ps1 sous Windows)
       - Ou manuellement : https://www.nerdfonts.com/
  3. Pour reconfigurer le theme : p10k configure

  Raccourcis :
  - Ctrl+R      : recherche fuzzy dans l historique (fzf/McFly)
  - Ctrl+G      : cheatsheets navi
  - Fleche haut : historique par prefixe
  - Double ESC  : ajoute sudo a la commande courante

  Commandes :
  - ll / lt     : ls avec icones / arborescence
  - extract     : decompresse toute archive
  - mkcd        : mkdir + cd en une commande
  - myinfo      : affiche les IPs
${NC}"
