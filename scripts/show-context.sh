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
    local current_context
    
    session_name=$(get_session_name)
    sanitized_name=$(sanitize_name "$session_name")
    context_dir=$(get_tmux_option "@kube_context_storage_dir" "${HOME}/.tmux-kube-contexts")
    session_kubeconfig="${context_dir}/${sanitized_name}.kubeconfig"
    
    if [ ! -f "$session_kubeconfig" ]; then
        tmux display-message "No kubeconfig for session '$session_name'"
        exit 0
    fi
    
    current_context=$(kubectl config current-context --kubeconfig="$session_kubeconfig" 2>/dev/null || echo "<none>")
    
    local cluster_name
    cluster_name=$(kubectl config view --kubeconfig="$session_kubeconfig" \
        -o jsonpath="{.contexts[?(@.name==\"$current_context\")].context.cluster}" 2>/dev/null || echo "")
    
    local namespace
    namespace=$(kubectl config view --kubeconfig="$session_kubeconfig" \
        -o jsonpath="{.contexts[?(@.name==\"$current_context\")].context.namespace}" 2>/dev/null || echo "default")
    
    tmux display-message "Session: $session_name | Context: $current_context | Cluster: ${cluster_name:-N/A} | NS: ${namespace:-default}"
}

main "$@"
