#!/usr/bin/env bash
#
# tmux-kube-context - Per-session/window/pane Kubernetes context isolation plugin for tmux
#
# This plugin ensures each tmux session/window/pane has its own isolated KUBECONFIG,
# preventing context switches in one place from affecting others or the global config.
#
# Isolation levels:
#   session - All panes in a session share the same context (default)
#   window  - Each window has its own context, panes in same window share
#   pane    - Each pane has its own isolated context
#

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default options
default_kube_context_dir="${HOME}/.tmux-kube-contexts"
default_base_kubeconfig="${HOME}/.kube/config"
default_isolation_level="session"

# Get plugin options with defaults
get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local option_value
    option_value=$(tmux show-option -gqv "$option")
    if [ -z "$option_value" ]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

# Initialize the plugin
main() {
    local context_dir
    local base_kubeconfig
    local isolation_level
    
    context_dir=$(get_tmux_option "@kube_context_dir" "$default_kube_context_dir")
    base_kubeconfig=$(get_tmux_option "@kube_base_kubeconfig" "$default_base_kubeconfig")
    isolation_level=$(get_tmux_option "@kube_isolation_level" "$default_isolation_level")
    
    # Validate isolation level
    case "$isolation_level" in
        session|window|pane)
            ;;
        *)
            isolation_level="session"
            ;;
    esac
    
    # Create context storage directory
    mkdir -p "$context_dir"
    
    # Store plugin paths as tmux options for scripts to use
    tmux set-option -g @kube_context_plugin_dir "$CURRENT_DIR"
    tmux set-option -g @kube_context_storage_dir "$context_dir"
    tmux set-option -g @kube_base_kubeconfig "$base_kubeconfig"
    tmux set-option -g @kube_isolation_level "$isolation_level"
    
    # Hook: Initialize KUBECONFIG when a new session is created
    tmux set-hook -g session-created "run-shell '$CURRENT_DIR/scripts/init-session.sh'"
    
    # Hook: Re-apply KUBECONFIG when client attaches to a session
    tmux set-hook -g client-session-changed "run-shell '$CURRENT_DIR/scripts/attach-session.sh'"
    
    # Hook: Initialize KUBECONFIG when a new window is created (for window/pane isolation)
    tmux set-hook -g window-linked "run-shell '$CURRENT_DIR/scripts/init-window.sh'"
    
    # Hook: Initialize KUBECONFIG when a new pane is created (for pane isolation)
    tmux set-hook -g pane-focus-in "run-shell '$CURRENT_DIR/scripts/init-pane.sh'"
    
    # Status line refresh hooks based on isolation level
    case "$isolation_level" in
        pane)
            tmux set-hook -g pane-focus-in "run-shell '$CURRENT_DIR/scripts/init-pane.sh'; refresh-client -S"
            ;;
        window)
            tmux set-hook -g session-window-changed "refresh-client -S"
            tmux set-hook -g client-session-changed "run-shell '$CURRENT_DIR/scripts/attach-session.sh'; refresh-client -S"
            ;;
        session)
            tmux set-hook -g client-session-changed "run-shell '$CURRENT_DIR/scripts/attach-session.sh'; refresh-client -S"
            ;;
    esac
    
    # Key binding: Switch kube context for current session (prefix + K)
    tmux bind-key K run-shell "$CURRENT_DIR/scripts/switch-context.sh"
    
    # Key binding: Show current kube context (prefix + Ctrl-K)
    tmux bind-key C-k run-shell "$CURRENT_DIR/scripts/show-context.sh"
    
    # Initialize current session if not already done
    "$CURRENT_DIR/scripts/init-session.sh"
}

main
