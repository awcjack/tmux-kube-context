#!/usr/bin/env bash

_tmux_kube_context_init() {
    [[ -z "$TMUX" ]] && return
    
    local isolation_level
    isolation_level=$(tmux show-option -gqv "@kube_isolation_level" 2>/dev/null)
    [[ -z "$isolation_level" ]] && isolation_level="session"
    
    local context_dir
    context_dir=$(tmux show-option -gqv "@kube_context_storage_dir" 2>/dev/null)
    [[ -z "$context_dir" ]] && context_dir="${HOME}/.tmux-kube-contexts"
    
    local base_kubeconfig
    base_kubeconfig=$(tmux show-option -gqv "@kube_base_kubeconfig" 2>/dev/null)
    [[ -z "$base_kubeconfig" ]] && base_kubeconfig="${HOME}/.kube/config"
    
    local session_name window_index pane_index kubeconfig_path
    
    # Get session name and validate it's not empty
    session_name=$(tmux display-message -p '#{session_name}' 2>/dev/null)
    if [[ -z "$session_name" ]]; then
        return
    fi
    session_name=$(echo "$session_name" | sed 's/[^a-zA-Z0-9_-]/_/g')
    
    window_index=$(tmux display-message -p '#{window_index}' 2>/dev/null)
    pane_index=$(tmux display-message -p '#{pane_index}' 2>/dev/null)
    
    case "$isolation_level" in
        pane)
            kubeconfig_path="${context_dir}/${session_name}_w${window_index}_p${pane_index}.kubeconfig"
            ;;
        window)
            kubeconfig_path="${context_dir}/${session_name}_w${window_index}.kubeconfig"
            ;;
        *)
            kubeconfig_path="${context_dir}/${session_name}.kubeconfig"
            ;;
    esac
    
    mkdir -p "$context_dir"
    
    if [[ ! -f "$kubeconfig_path" ]]; then
        if [[ -f "$base_kubeconfig" ]]; then
            cp "$base_kubeconfig" "$kubeconfig_path"
            chmod 600 "$kubeconfig_path"
        fi
    fi
    
    if [[ -f "$kubeconfig_path" ]]; then
        export KUBECONFIG="$kubeconfig_path"
    fi
}

_tmux_kube_context_init
