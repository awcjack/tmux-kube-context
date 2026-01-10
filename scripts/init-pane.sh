#!/usr/bin/env bash
#
# init-pane.sh - Initialize per-pane KUBECONFIG
#
# Only active when @kube_isolation_level is "pane"
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
    
    if [ "$isolation_level" != "pane" ]; then
        return 0
    fi
    
    local session_name
    local window_index
    local pane_index
    local context_dir
    local base_kubeconfig
    local pane_kubeconfig
    
    session_name=$(tmux display-message -p '#{session_name}')
    window_index=$(tmux display-message -p '#{window_index}')
    pane_index=$(tmux display-message -p '#{pane_index}')
    context_dir=$(get_tmux_option "@kube_context_storage_dir" "${HOME}/.tmux-kube-contexts")
    base_kubeconfig=$(get_tmux_option "@kube_base_kubeconfig" "${HOME}/.kube/config")
    
    local sanitized_session
    sanitized_session=$(sanitize_name "$session_name")
    pane_kubeconfig="${context_dir}/${sanitized_session}_w${window_index}_p${pane_index}.kubeconfig"
    
    mkdir -p "$context_dir"
    
    if [ ! -f "$pane_kubeconfig" ]; then
        if [ -f "$base_kubeconfig" ]; then
            cp "$base_kubeconfig" "$pane_kubeconfig"
            chmod 600 "$pane_kubeconfig"
        else
            cat > "$pane_kubeconfig" << 'EOF'
apiVersion: v1
kind: Config
preferences: {}
clusters: []
contexts: []
users: []
EOF
            chmod 600 "$pane_kubeconfig"
        fi
    fi
    
    local pane_id
    pane_id=$(tmux display-message -p '#{pane_id}')
    
    local pane_current_command
    pane_current_command=$(tmux display-message -p '#{pane_current_command}' 2>/dev/null || true)
    
    case "$pane_current_command" in
        bash|zsh|sh|fish|ksh|tcsh|csh)
            tmux send-keys -t "$pane_id" "export KUBECONFIG='$pane_kubeconfig'" Enter 2>/dev/null || true
            ;;
    esac
}

main "$@"
