#!/usr/bin/env bash

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
    local kubeconfig_path
    local current_context
    local format
    local session_name
    
    format=$(get_tmux_option "@kube_context_format" "⎈ #[fg=cyan]%c#[default]")
    session_name=$(tmux display-message -p '#{session_name}')
    kubeconfig_path=$(get_kubeconfig_path)
    
    if [ ! -f "$kubeconfig_path" ]; then
        echo ""
        exit 0
    fi
    
    current_context=$(kubectl config current-context --kubeconfig="$kubeconfig_path" 2>/dev/null || echo "")
    
    if [ -z "$current_context" ]; then
        echo ""
        exit 0
    fi
    
    local namespace
    namespace=$(kubectl config view --kubeconfig="$kubeconfig_path" \
        -o jsonpath="{.contexts[?(@.name==\"$current_context\")].context.namespace}" 2>/dev/null || echo "default")
    
    [ -z "$namespace" ] && namespace="default"
    
    local output="$format"
    output="${output//%c/$current_context}"
    output="${output//%n/$namespace}"
    output="${output//%s/$session_name}"
    
    echo "$output"
}

main "$@"
