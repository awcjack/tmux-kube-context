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
    local contexts
    local selected_context
    
    session_name=$(get_session_name)
    sanitized_name=$(sanitize_name "$session_name")
    context_dir=$(get_tmux_option "@kube_context_storage_dir" "${HOME}/.tmux-kube-contexts")
    session_kubeconfig="${context_dir}/${sanitized_name}.kubeconfig"
    
    if [ ! -f "$session_kubeconfig" ]; then
        tmux display-message "No kubeconfig for session '$session_name'"
        exit 1
    fi
    
    contexts=$(kubectl config get-contexts --kubeconfig="$session_kubeconfig" -o name 2>/dev/null || echo "")
    
    if [ -z "$contexts" ]; then
        tmux display-message "No contexts available in session kubeconfig"
        exit 1
    fi
    
    local current_context
    current_context=$(kubectl config current-context --kubeconfig="$session_kubeconfig" 2>/dev/null || echo "")
    
    selected_context=$(echo "$contexts" | fzf-tmux -p 60%,40% \
        --header="Select Kubernetes context for session: $session_name" \
        --prompt="Context> " \
        --preview="kubectl config view --kubeconfig='$session_kubeconfig' -o jsonpath='{.contexts[?(@.name==\"{}\")]}' 2>/dev/null | jq . 2>/dev/null || echo 'Context: {}'" \
        --preview-window=right:50% \
        ${current_context:+--query="$current_context"} \
        2>/dev/null)
    
    if [ -n "$selected_context" ]; then
        kubectl config use-context "$selected_context" --kubeconfig="$session_kubeconfig" >/dev/null 2>&1
        tmux display-message "Switched to context: $selected_context"
        
        local panes
        panes=$(tmux list-panes -s -t "$session_name" -F '#{pane_id}' 2>/dev/null || true)
        
        for pane_id in $panes; do
            local pane_current_command
            pane_current_command=$(tmux display-message -p -t "$pane_id" '#{pane_current_command}' 2>/dev/null || true)
            
            case "$pane_current_command" in
                bash|zsh|sh|fish|ksh|tcsh|csh)
                    tmux send-keys -t "$pane_id" "" 2>/dev/null || true
                    ;;
            esac
        done
    fi
}

main "$@"
