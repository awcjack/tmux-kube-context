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

# Check if context matches production patterns
is_production_context() {
    local context="$1"
    local prod_patterns
    
    # Get production patterns from tmux option, default to common production patterns
    prod_patterns=$(get_tmux_option "@kube_prod_patterns" "prod,production")
    
    # Convert comma-separated patterns to array and check each
    IFS=',' read -ra patterns <<< "$prod_patterns"
    for pattern in "${patterns[@]}"; do
        # Trim whitespace
        pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Case-insensitive match using grep
        if echo "$context" | grep -iq "$pattern"; then
            return 0  # true - is production
        fi
    done
    
    return 1  # false - not production
}

main() {
    local kubeconfig_path
    local current_context
    local format
    local format_prod
    local session_name
    
    format=$(get_tmux_option "@kube_context_format" "⎈ #[fg=cyan]%c#[default]")
    format_prod=$(get_tmux_option "@kube_context_format_prod" "⎈ #[fg=red,bold]%c#[default]")
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
    
    # Select format based on whether context is production
    local output
    if is_production_context "$current_context"; then
        output="$format_prod"
    else
        output="$format"
    fi
    
    output="${output//%c/$current_context}"
    output="${output//%n/$namespace}"
    output="${output//%s/$session_name}"
    
    echo "$output"
}

main "$@"
