#!/usr/bin/env bash
set -e

get_session_name() {
    tmux display-message -p '#{session_name}'
}

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
    local session_name
    local sanitized_name
    local context_dir
    local session_kubeconfig
    
    session_name=$(get_session_name)
    sanitized_name=$(sanitize_name "$session_name")
    context_dir=$(get_tmux_option "@kube_context_storage_dir" "${HOME}/.tmux-kube-contexts")
    session_kubeconfig="${context_dir}/${sanitized_name}.kubeconfig"
    
    if [ -f "$session_kubeconfig" ]; then
        tmux set-environment -t "$session_name" KUBECONFIG "$session_kubeconfig"
        tmux set-option -t "$session_name" @kube_session_config "$session_kubeconfig"
    fi
}

main "$@"
