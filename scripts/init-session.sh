#!/usr/bin/env bash
#
# init-session.sh - Initialize per-session KUBECONFIG for a tmux session
#
# Creates an isolated copy of the kubeconfig for this session.
# For session-level isolation, all panes within the session share this config.
#

set -e

# Get the current session name
get_session_name() {
    tmux display-message -p '#{session_name}'
}

# Get plugin option
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

# Sanitize name for use as filename
sanitize_name() {
    echo "$1" | sed 's/[^a-zA-Z0-9_-]/_/g'
}

main() {
    local session_name
    local sanitized_name
    local context_dir
    local base_kubeconfig
    local session_kubeconfig
    local isolation_level
    
    session_name=$(get_session_name)
    sanitized_name=$(sanitize_name "$session_name")
    context_dir=$(get_tmux_option "@kube_context_storage_dir" "${HOME}/.tmux-kube-contexts")
    base_kubeconfig=$(get_tmux_option "@kube_base_kubeconfig" "${HOME}/.kube/config")
    isolation_level=$(get_tmux_option "@kube_isolation_level" "session")
    
    # For session-level isolation, create session kubeconfig
    # For window/pane isolation, this just ensures the directory exists
    session_kubeconfig="${context_dir}/${sanitized_name}.kubeconfig"
    
    # Ensure context directory exists
    mkdir -p "$context_dir"
    
    # Only set session-level KUBECONFIG if isolation is at session level
    if [ "$isolation_level" = "session" ]; then
        # Check if session kubeconfig already exists
        if [ ! -f "$session_kubeconfig" ]; then
            # Create new session-specific kubeconfig by copying the base config
            if [ -f "$base_kubeconfig" ]; then
                cp "$base_kubeconfig" "$session_kubeconfig"
                chmod 600 "$session_kubeconfig"
            else
                # Create empty kubeconfig if base doesn't exist
                cat > "$session_kubeconfig" << 'EOF'
apiVersion: v1
kind: Config
preferences: {}
clusters: []
contexts: []
users: []
EOF
                chmod 600 "$session_kubeconfig"
            fi
        fi
        
        # Set the KUBECONFIG environment variable for this session
        tmux set-environment -t "$session_name" KUBECONFIG "$session_kubeconfig"
        
        # Store the mapping for later reference
        tmux set-option -t "$session_name" @kube_session_config "$session_kubeconfig"
    fi
}

main "$@"
