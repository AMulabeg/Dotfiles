#!/usr/bin/env bash
get_tmux_option() {
  local option=$1
  local default_value="$2"
  local option_value
  option_value=$(tmux show-options -gqv "$option")
  if [ "$option_value" != "" ]; then
    echo "$option_value"
    return
  fi
  echo "$default_value"
}

# Default color reset
default_color="#[bg=default,fg=default,nobold,noitalics,nounderscore]"

# Subtle dark palette that blends with terminal
bg=$(get_tmux_option "@minimal-tmux-bg" '#1c1c1c')
fg=$(get_tmux_option "@minimal-tmux-fg" '#a8a8a8')
accent_subtle="#3a3a3a"        # darker gray for active tab background
accent_text="#d0d0d0"          # slightly brighter text for active tab
accent_indicator="#6c6c6c"     # muted gray for indicator
accent_session="#5f8787"       # muted teal for session name

use_arrow=$(get_tmux_option "@minimal-tmux-use-arrow" true)
larrow="$("$use_arrow" && get_tmux_option "@minimal-tmux-left-arrow" "")"
rarrow="$("$use_arrow" && get_tmux_option "@minimal-tmux-right-arrow" "")"
# status=$(get_tmux_option "@minimal-tmux-status" "top")
justify="left"

# prefix indicator (muted)
indicator_state=$(get_tmux_option "@minimal-tmux-indicator" true)
indicator_str=$(get_tmux_option "@minimal-tmux-indicator-str" " ⌘ ")
indicator=$("$indicator_state" && echo "#[fg=${accent_indicator}]$indicator_str#[default]")

right_state=$(get_tmux_option "@minimal-tmux-right" true)

# LEFT SIDE
status_left="${indicator} "

# RIGHT SIDE
status_right=$("$right_state" && get_tmux_option "@minimal-tmux-status-right" "#[fg=${accent_session}]#S")

window_status_format=$(get_tmux_option "@minimal-tmux-window-status-format" ' #I:#W ')
expanded_icon=$(get_tmux_option "@minimal-tmux-expanded-icon" '󰊓 ')
show_expanded_icon_for_all_tabs=$(get_tmux_option "@minimal-tmux-show-expanded-icon-for-all-tabs" false)

# Apply settings
tmux set-option -g status-position "$status"
tmux set-option -g status-style "bg=${bg},fg=${fg}"
tmux set-option -g status-justify "$justify"
tmux set-option -g status-left "$status_left"
tmux set-option -g status-right "$status_right"

# Window styles - subtle highlighting for active window
tmux set-option -g window-status-format "#[fg=${fg},bg=${bg}]$window_status_format"
"$show_expanded_icon_for_all_tabs" && tmux set-option -g window-status-format " ${window_status_format}#{?window_zoomed_flag,${expanded_icon},}"

# Active window: subtle darker background with slightly brighter text
tmux set-option -g window-status-current-format "#[fg=${bg}]$larrow#[bg=${accent_subtle},fg=${accent_text}]$window_status_format#{?window_zoomed_flag,${expanded_icon},}#[fg=${accent_subtle},bg=${bg}]$rarrow"
