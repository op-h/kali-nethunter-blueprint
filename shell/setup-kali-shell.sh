#!/bin/bash
# Enhance the Kali NetHunter chroot shell: zsh + Kali theme + autosuggestions
# + syntax highlighting + completion + a ready-to-run tool menu.
set -e
export DEBIAN_FRONTEND=noninteractive
echo "[*] apt update + installing zsh stack..."
apt-get update -qq || true
apt-get install -y -qq zsh zsh-autosuggestions zsh-syntax-highlighting zsh-common \
  bash-completion grc lsd bat figlet toilet 2>/dev/null || \
  apt-get install -y -qq zsh zsh-autosuggestions zsh-syntax-highlighting bash-completion || true

echo "[*] writing /root/.zshrc ..."
cat > /root/.zshrc <<'ZRC'
# ===== NetHunter Kali enhanced shell (op-h) =====
export LANG=C.UTF-8
export TERM=xterm-256color
HISTFILE=~/.zsh_history; HISTSIZE=50000; SAVEHIST=50000
setopt inc_append_history share_history hist_ignore_dups hist_reduce_blanks
setopt autocd correct interactivecomments
bindkey -e

# completion (menu + case-insensitive + colors)
autoload -Uz compinit && compinit -u
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format '%F{cyan}%d%f'

# --- Kali-style two-line prompt (red root, arrow) ---
autoload -Uz colors && colors
setopt prompt_subst
PROMPT='%F{red}┌──(%F{white}root㉿nethunter%F{red})-[%F{white}%~%F{red}]
└─%F{red}# %f'
RPROMPT='%F{240}%D{%H:%M:%S}%f'

# fish-style autosuggestions + syntax highlighting
for f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
         /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [ -r "$f" ] && source "$f"
done
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'

# color aliases
alias ls='ls --color=auto'; alias ll='ls -lah --color=auto'; alias la='ls -A'
alias grep='grep --color=auto'; alias ip='ip -c'
command -v lsd >/dev/null && alias ll='lsd -lah'
command -v batcat >/dev/null && alias cat='batcat -pp'
alias myip='curl -4 -s ifconfig.me; echo'
alias ports='ss -tulpn'
alias update='apt update && apt -y full-upgrade'

# handy tool shortcuts (ready to run)
alias nmap-quick='nmap -T4 -F'
alias nmap-full='nmap -T4 -A -p-'
alias nmap-vuln='nmap -sV --script vuln'
alias msf='msfconsole -q'
alias webserver='python3 -m http.server 8000'
alias wifi-mon='airmon-ng start wlan1'
alias wifi-scan='airodump-ng wlan1mon'

# load the tool menu function
[ -r /root/.nh-tools.zsh ] && source /root/.nh-tools.zsh

# greeting banner on login
if command -v figlet >/dev/null 2>&1; then
  print -P "%F{red}"; figlet -f small "NetHunter" 2>/dev/null; print -P "%f"
fi
print -P "%F{cyan} Kali NetHunter · type %F{yellow}nh%F{cyan} for the tool menu · %F{yellow}tools%F{cyan} to list all%f"
ZRC

echo "[*] writing tool menu (/root/.nh-tools.zsh) ..."
cat > /root/.nh-tools.zsh <<'NHT'
# ready-to-run tool menu, driven by what is actually installed
_nh_have(){ command -v "$1" >/dev/null 2>&1; }
tools(){
  print -P "%F{red}== Installed offensive tooling ==%f"
  for t in nmap masscan msfconsole sqlmap hydra john hashcat aircrack-ng airmon-ng \
           airodump-ng wifite reaver bettercap ettercap responder nikto gobuster \
           ffuf wpscan dirb enum4linux crackmapexec impacket-smbclient searchsploit \
           setoolkit beef-xss recon-ng theharvester wireshark tshark tcpdump \
           netcat ncat socat; do
    if _nh_have "$t"; then print -P "  %F{green}✔%f $t"; else print -P "  %F{240}·%f $t (not installed)"; fi
  done
}
# interactive categorized launcher
nh(){
  local cat tool cmd
  while true; do
    print -P "\n%F{red}┌─ NetHunter tool menu ──────────────%f"
    print -P "%F{red}│%f 1) Recon / OSINT      5) Wireless"
    print -P "%F{red}│%f 2) Scanning           6) Web"
    print -P "%F{red}│%f 3) Exploitation       7) Passwords"
    print -P "%F{red}│%f 4) Sniff / MITM       8) Sessions (list) "
    print -P "%F{red}│%f q) quit"
    print -P "%F{red}└────────────────────────────────────%f"
    read "cat?select> "
    case $cat in
      1) _nh_pick "recon-ng theHarvester:'theHarvester -d TARGET -b all' 'dnsrecon -d TARGET' 'whatweb TARGET' 'enum4linux -a TARGET'";;
      2) _nh_pick "'nmap -T4 -A -p- TARGET' 'nmap -sV --script vuln TARGET' 'masscan -p1-65535 TARGET --rate 1000' 'gobuster dir -u http://TARGET -w /usr/share/wordlists/dirb/common.txt'";;
      3) _nh_pick "'msfconsole -q' 'searchsploit TERM' 'crackmapexec smb TARGET -u USER -p PASS'";;
      4) _nh_pick "'bettercap -iface wlan0' 'responder -I wlan0' 'tcpdump -i any -n' 'ettercap -T -q -i wlan0'";;
      5) _nh_pick "'airmon-ng start wlan1' 'airodump-ng wlan1mon' 'wifite' 'aircrack-ng CAP -w WORDLIST' 'reaver -i wlan1mon -b BSSID'";;
      6) _nh_pick "'sqlmap -u URL --batch' 'nikto -h http://TARGET' 'wpscan --url http://TARGET' 'ffuf -u http://TARGET/FUZZ -w /usr/share/wordlists/dirb/common.txt'";;
      7) _nh_pick "'hydra -l USER -P WORDLIST TARGET SERVICE' 'john --wordlist=/usr/share/wordlists/rockyou.txt HASHFILE' 'hashcat -m 0 HASHFILE /usr/share/wordlists/rockyou.txt'";;
      8) print -P '%F{cyan}(sessions handled by the terminal app tabs)%f';;
      q|Q) break;;
      *) print -P "%F{yellow}pick 1-8 or q%f";;
    esac
  done
}
_nh_pick(){
  local -a items; items=("${(@s/ /)1}")
  # rebuild entries that contain spaces (quoted)
  local raw="$1"; print -P "%F{cyan}Ready-to-run (edit TARGET/USER/etc. then Enter; Ctrl-C to cancel):%f"
  local i=1; local line
  print -r -- "$raw" | grep -oE "'[^']+'" | while read -r line; do
     print -P "  %F{green}$i)%f ${line//\'/}"; i=$((i+1))
  done
  local sel; read "sel?run #> "
  local chosen; chosen=$(print -r -- "$raw" | grep -oE "'[^']+'" | sed -n "${sel}p" | sed "s/'//g")
  [ -z "$chosen" ] && return
  print -z "$chosen"   # put on the command line for editing, not auto-exec
}
NHT

echo "[*] setting root login shell to zsh ..."
chsh -s /usr/bin/zsh root 2>/dev/null || sed -i 's#^root:\(.*\):[^:]*$#root:\1:/usr/bin/zsh#' /etc/passwd
# make sure bootkali login lands in zsh even if chsh ignored
grep -q 'exec zsh' /root/.bash_profile 2>/dev/null || echo '[ -z "$ZSH_VERSION" ] && [ -x /usr/bin/zsh ] && exec /usr/bin/zsh -l' >> /root/.bash_profile

echo "[*] done. zsh: $(zsh --version 2>/dev/null)"
echo "SHELL_SETUP_DONE"
