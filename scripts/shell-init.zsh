_tmux_kube_context_init() {
    [[ -z "$TMUX" ]] && return
    
    local isolation_level
    isolation_level=$(tmux show-option -gqv "@kube_isolation_level" 2>/dev/null)
    [[ -z "$isolation_level" ]] && isolation_level="session"
    
    local context_dir
    context_dir=$(tmux show-option -gqv "@kube_context_storage_dir" 2>/dev/null)
    [[ -z "$context_dir" ]] && context_dir="${HOME}/.tmux-kube-contexts"
    
    local session_name window_index pane_index kubeconfig_path
    session_name=$(tmux display-message -p '#{session_name}' | sed 's/[^a-zA-Z0-9_-]/_/g')
    window_index=$(tmux display-message -p '#{window_index}')
    pane_index=$(tmux display-message -p '#{pane_index}')
    
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
    
    if [[ -f "$kubeconfig_path" ]]; then
        export KUBECONFIG="$kubeconfig_path"
    else
        local session_kubeconfig
        session_kubeconfig=$(tmux show-environment KUBECONFIG 2>/dev/null | cut -d= -f2-)
        if [[ -n "$session_kubeconfig" ]] && [[ -f "$session_kubeconfig" ]]; then
            export KUBECONFIG="$session_kubeconfig"
        fi
    fi
}

_tmux_kube_context_init
