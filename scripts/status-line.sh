#!/usr/bin/env bash

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
    local format
    
    format=$(get_tmux_option "@kube_context_format" "⎈ #[fg=cyan]%c#[default]")
    session_name=$(get_session_name)
    sanitized_name=$(sanitize_name "$session_name")
    context_dir=$(get_tmux_option "@kube_context_storage_dir" "${HOME}/.tmux-kube-contexts")
    session_kubeconfig="${context_dir}/${sanitized_name}.kubeconfig"
    
    if [ ! -f "$session_kubeconfig" ]; then
        echo ""
        exit 0
    fi
    
    current_context=$(kubectl config current-context --kubeconfig="$session_kubeconfig" 2>/dev/null || echo "")
    
    if [ -z "$current_context" ]; then
        echo ""
        exit 0
    fi
    
    local namespace
    namespace=$(kubectl config view --kubeconfig="$session_kubeconfig" \
        -o jsonpath="{.contexts[?(@.name==\"$current_context\")].context.namespace}" 2>/dev/null || echo "default")
    
    [ -z "$namespace" ] && namespace="default"
    
    local output="$format"
    output="${output//%c/$current_context}"
    output="${output//%n/$namespace}"
    output="${output//%s/$session_name}"
    
    echo "$output"
}

main "$@"
