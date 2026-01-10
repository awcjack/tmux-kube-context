#!/usr/bin/env bash
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

get_kubeconfig_path() {
    local isolation_level context_dir session_name window_index pane_index
    
    isolation_level=$(get_tmux_option "@kube_isolation_level" "session")
    context_dir=$(get_tmux_option "@kube_context_storage_dir" "${HOME}/.tmux-kube-contexts")
    session_name=$(tmux display-message -p '#{session_name}' | sed 's/[^a-zA-Z0-9_-]/_/g')
    window_index=$(tmux display-message -p '#{window_index}')
    pane_index=$(tmux display-message -p '#{pane_index}')
    
    case "$isolation_level" in
        pane)
            echo "${context_dir}/${session_name}_w${window_index}_p${pane_index}.kubeconfig"
            ;;
        window)
            echo "${context_dir}/${session_name}_w${window_index}.kubeconfig"
            ;;
        *)
            echo "${context_dir}/${session_name}.kubeconfig"
            ;;
    esac
}

main() {
    local session_name
    local kubeconfig_path
    local current_context
    local isolation_level
    
    session_name=$(tmux display-message -p '#{session_name}')
    isolation_level=$(get_tmux_option "@kube_isolation_level" "session")
    kubeconfig_path=$(get_kubeconfig_path)
    
    if [ ! -f "$kubeconfig_path" ]; then
        tmux display-message "No kubeconfig for $isolation_level '$session_name'"
        exit 0
    fi
    
    current_context=$(kubectl config current-context --kubeconfig="$kubeconfig_path" 2>/dev/null || echo "<none>")
    
    local cluster_name
    cluster_name=$(kubectl config view --kubeconfig="$kubeconfig_path" \
        -o jsonpath="{.contexts[?(@.name==\"$current_context\")].context.cluster}" 2>/dev/null || echo "")
    
    local namespace
    namespace=$(kubectl config view --kubeconfig="$kubeconfig_path" \
        -o jsonpath="{.contexts[?(@.name==\"$current_context\")].context.namespace}" 2>/dev/null || echo "default")
    
    tmux display-message "Session: $session_name | Context: $current_context | Cluster: ${cluster_name:-N/A} | NS: ${namespace:-default}"
}

main "$@"
