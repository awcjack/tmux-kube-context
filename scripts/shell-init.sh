#!/usr/bin/env bash

_tmux_kube_context_init() {
    if [ -z "$TMUX" ]; then
        return
    fi
    
    local session_kubeconfig
    session_kubeconfig=$(tmux show-environment KUBECONFIG 2>/dev/null | cut -d= -f2-)
    
    if [ -n "$session_kubeconfig" ] && [ -f "$session_kubeconfig" ]; then
        export KUBECONFIG="$session_kubeconfig"
    fi
}

_tmux_kube_context_init
