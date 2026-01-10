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
    local contexts
    local selected_context
    local isolation_level
    
    session_name=$(tmux display-message -p '#{session_name}')
    isolation_level=$(get_tmux_option "@kube_isolation_level" "session")
    kubeconfig_path=$(get_kubeconfig_path)
    
    if [ ! -f "$kubeconfig_path" ]; then
        tmux display-message "No kubeconfig for $isolation_level '$session_name'"
        exit 1
    fi
    
    contexts=$(kubectl config get-contexts --kubeconfig="$kubeconfig_path" -o name 2>/dev/null || echo "")
    
    if [ -z "$contexts" ]; then
        tmux display-message "No contexts available in kubeconfig"
        exit 1
    fi
    
    local current_context
    current_context=$(kubectl config current-context --kubeconfig="$kubeconfig_path" 2>/dev/null || echo "")
    
    selected_context=$(echo "$contexts" | fzf-tmux -p 60%,40% \
        --header="Select Kubernetes context ($isolation_level: $session_name)" \
        --prompt="Context> " \
        --preview="kubectl config view --kubeconfig='$kubeconfig_path' -o jsonpath='{.contexts[?(@.name==\"{}\")]}' 2>/dev/null | jq . 2>/dev/null || echo 'Context: {}'" \
        --preview-window=right:50% \
        ${current_context:+--query="$current_context"} \
        2>/dev/null)
    
    if [ -n "$selected_context" ]; then
        kubectl config use-context "$selected_context" --kubeconfig="$kubeconfig_path" >/dev/null 2>&1
        tmux display-message "Switched to context: $selected_context"
        
        # Only refresh panes in session mode, not window/pane mode
        if [ "$isolation_level" = "session" ]; then
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
    fi
}

main "$@"
