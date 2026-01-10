#!/usr/bin/env bash
#
# init-window.sh - Initialize per-window KUBECONFIG
#
# Only active when @kube_isolation_level is "window" or "pane"
#

set -e

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

sanitize_name() {
    echo "$1" | sed 's/[^a-zA-Z0-9_-]/_/g'
}

main() {
    local isolation_level
    isolation_level=$(get_tmux_option "@kube_isolation_level" "session")
    
    # Only run for window or pane isolation
    if [ "$isolation_level" != "window" ] && [ "$isolation_level" != "pane" ]; then
        return 0
    fi
    
    # For pane isolation, let init-pane.sh handle it
    if [ "$isolation_level" = "pane" ]; then
        return 0
    fi
    
    local session_name
    local window_index
    local context_dir
    local base_kubeconfig
    local window_kubeconfig
    
    session_name=$(tmux display-message -p '#{session_name}')
    window_index=$(tmux display-message -p '#{window_index}')
    context_dir=$(get_tmux_option "@kube_context_storage_dir" "${HOME}/.tmux-kube-contexts")
    base_kubeconfig=$(get_tmux_option "@kube_base_kubeconfig" "${HOME}/.kube/config")
    
    local sanitized_session
    sanitized_session=$(sanitize_name "$session_name")
    window_kubeconfig="${context_dir}/${sanitized_session}_w${window_index}.kubeconfig"
    
    mkdir -p "$context_dir"
    
    if [ ! -f "$window_kubeconfig" ]; then
        if [ -f "$base_kubeconfig" ]; then
            cp "$base_kubeconfig" "$window_kubeconfig"
            chmod 600 "$window_kubeconfig"
        else
            cat > "$window_kubeconfig" << 'EOF'
apiVersion: v1
kind: Config
preferences: {}
clusters: []
contexts: []
users: []
EOF
            chmod 600 "$window_kubeconfig"
        fi
    fi
    
    tmux set-environment KUBECONFIG "$window_kubeconfig"
}

main "$@"
