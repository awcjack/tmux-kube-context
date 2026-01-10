#!/usr/bin/env bash
#
# tmux-kube-context - Per-session Kubernetes context isolation plugin for tmux
#
# This plugin ensures each tmux session has its own isolated KUBECONFIG,
# preventing context switches in one session from affecting others or the global config.
#

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default options
default_kube_context_dir="${HOME}/.tmux-kube-contexts"
default_base_kubeconfig="${HOME}/.kube/config"

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
    
    context_dir=$(get_tmux_option "@kube_context_dir" "$default_kube_context_dir")
    base_kubeconfig=$(get_tmux_option "@kube_base_kubeconfig" "$default_base_kubeconfig")
    
    # Create context storage directory
    mkdir -p "$context_dir"
    
    # Store plugin paths as tmux options for scripts to use
    tmux set-option -g @kube_context_plugin_dir "$CURRENT_DIR"
    tmux set-option -g @kube_context_storage_dir "$context_dir"
    tmux set-option -g @kube_base_kubeconfig "$base_kubeconfig"
    
    # Hook: Initialize KUBECONFIG when a new session is created
    tmux set-hook -g session-created "run-shell '$CURRENT_DIR/scripts/init-session.sh'"
    
    # Hook: Re-apply KUBECONFIG when client attaches to a session
    # This ensures the environment is set correctly after attach
    tmux set-hook -g client-session-changed "run-shell '$CURRENT_DIR/scripts/attach-session.sh'"
    
    # Key binding: Switch kube context for current session (prefix + K)
    tmux bind-key K run-shell "$CURRENT_DIR/scripts/switch-context.sh"
    
    # Key binding: Show current kube context (prefix + Ctrl-K)
    tmux bind-key C-k run-shell "$CURRENT_DIR/scripts/show-context.sh"
    
    # Initialize current session if not already done
    "$CURRENT_DIR/scripts/init-session.sh"
}

main
