# tmux-kube-context

Per-session Kubernetes context isolation for tmux. Each tmux session gets its own isolated kubeconfig, preventing context switches in one session from affecting others or the global kubeconfig.

## Features

- **Session Isolation**: Each tmux session has its own kubeconfig copy
- **Pane Inheritance**: All panes within a session share the same isolated context
- **Global Protection**: Changes never affect `~/.kube/config` or other sessions
- **Context Switching**: Built-in fzf-powered context switcher
- **Status Bar Integration**: Display current context in tmux status line
- **Shell Integration**: Automatic KUBECONFIG setup for new panes

## Requirements

- tmux 3.0+
- kubectl
- fzf (for context switching with `prefix + K`)
- jq (optional, for context preview)

## Installation

### With TPM (recommended)

Add to your `~/.tmux.conf`:

```bash
set -g @plugin 'awcjack/tmux-kube-context'
```

Press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/awcjack/tmux-kube-context ~/.tmux/plugins/tmux-kube-context
```

Add to `~/.tmux.conf`:

```bash
run-shell ~/.tmux/plugins/tmux-kube-context/kube-context.tmux
```

### Shell Integration (Required)

Add to your shell rc file to ensure new panes inherit the session's KUBECONFIG:

**For Bash** (`~/.bashrc`):
```bash
source ~/.tmux/plugins/tmux-kube-context/scripts/shell-init.sh
```

**For Zsh** (`~/.zshrc`):
```bash
source ~/.tmux/plugins/tmux-kube-context/scripts/shell-init.zsh
```

## Usage

### Automatic Behavior

When you create a new tmux session:
1. A copy of your kubeconfig is created at `~/.tmux-kube-contexts/<session-name>.kubeconfig`
2. The `KUBECONFIG` environment variable is set for the session
3. All panes in that session use this isolated config

### Key Bindings

| Binding | Action |
|---------|--------|
| `prefix + K` | Switch kubernetes context (fzf picker) |
| `prefix + Ctrl-k` | Show current context info |

### Status Bar

Add to your status line to show current context:

```bash
set -g status-right '#(~/.tmux/plugins/tmux-kube-context/scripts/status-line.sh)'
```

### Example Workflow

```bash
# Global context is "staging"
kubectl config current-context  # staging

# Create a production session
tmux new-session -s prod

# Inside prod session: switch to production context
# Press prefix + K and select "production"

# Open new pane (prefix + %) - still uses production context
kubectl config current-context  # production

# Detach and check global context
tmux detach
kubectl config current-context  # still staging!

# Create another session
tmux new-session -s dev
kubectl config current-context  # whatever was in original config

# Attach to prod session - still production
tmux attach -t prod
kubectl config current-context  # production
```

## Configuration Options

Set in `~/.tmux.conf` before loading the plugin:

```bash
# Directory to store session kubeconfigs (default: ~/.tmux-kube-contexts)
set -g @kube_context_dir "~/.tmux-kube-contexts"

# Base kubeconfig to copy for new sessions (default: ~/.kube/config)
set -g @kube_base_kubeconfig "~/.kube/config"

# Status line format (default: "⎈ #[fg=cyan]%c#[default]")
# %c = context name
# %n = namespace
# %s = session name
set -g @kube_context_format "⎈ #[fg=cyan]%c#[default]:#[fg=yellow]%n#[default]"
```

## How It Works

1. **Session Creation**: When a tmux session is created, the plugin copies your base kubeconfig to a session-specific file
2. **Environment Variable**: `KUBECONFIG` is set as a tmux session environment variable
3. **Pane Inheritance**: New panes inherit the session environment, getting the isolated KUBECONFIG
4. **Shell Integration**: The shell-init script ensures KUBECONFIG is exported in each shell

## Troubleshooting

### Context not being isolated

Ensure shell integration is set up:
```bash
# Check if KUBECONFIG is set correctly
echo $KUBECONFIG
# Should show: ~/.tmux-kube-contexts/<session-name>.kubeconfig
```

### New panes not inheriting context

1. Verify shell integration is sourced in your rc file
2. Check that the kubeconfig file exists:
```bash
ls -la ~/.tmux-kube-contexts/
```

### Cleaning up old configs

```bash
# Remove all session kubeconfigs
rm -rf ~/.tmux-kube-contexts/*
```

## License

MIT
