export EDITOR="nvim"
export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_TYPE=wayland
export MOZ_ENABLE_WAYLAND=1


tmux="TERM=screen-256color-bce tmux"

export XDG_CURRENT_DESKTOP=sway

eval "$(starship init zsh)"
eval "$(zoxide init --cmd cd zsh)"
eval "$(fzf --zsh)"
# Plugins
source ~/scripts/fzf-tab/fzf-tab.plugin.zsh
source ~/scripts/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
source ~/scripts/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh
source ~/scripts/sudo.plugin.zsh
autoload -U compinit && compinit
alias fsb='~/scripts/fsb.sh'
alias fshow='~/scripts/fshow.sh'
source ~/scripts/fzf-git.sh

export PATH="$HOME/.emacs.d/bin:$PATH" 


# Aliases
alias weather='curl wttr.in/Berlin'
alias fonts='wezterm ls-fonts --list-system | fzf'
alias givepassword='security find-generic-password -wa'
alias ipaddress='ifconfig | grep -A 5 en0 | grep "inet " | cut -f2 -d " "' # User configuration export MANPATH="/usr/local/man:$MANPATH"
alias kys="sudo shutdown -h now"
alias f="fastfetch -c neofetch"
alias ls="eza --color=always --git --icons=never --no-time --no-user --no-permissions"
alias oo="cd ~/Documents/Obsidian"
alias "pirates"="ani-cli one piece"
alias y="yazi"
alias s='sesh connect $(sesh list | fzf)'



HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'


#  Use fd instead of fzf 
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

TRANSIENT_PROMPT=`starship module character`
function zle-line-init() {
	emulate -L zsh

	[[ $CONTEXT == start ]] || return 0
	while true; do
		zle .recursive-edit
		local -i ret=$?
		[[ $ret == 0 && $KEYS == $'\4' ]] || break
		[[ -o ignore_eof ]] || exit 0
	done

	local saved_prompt=$PROMPT
	local saved_rprompt=$RPROMPT

	PROMPT=$TRANSIENT_PROMPT
	zle .reset-prompt
	PROMPT=$saved_prompt

	if (( ret )); then
		zle .send-break
	else
		zle .accept-line
	fi
	return ret
}


zle -N zle-line-init
export BAT_THEME=tokyonight_night
unsetopt BEEP




[ -f "/home/amulabeg/.ghcup/env" ] && . "/home/amulabeg/.ghcup/env" # ghcup-env

# pnpm
export PNPM_HOME="/home/amulabeg/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
