#!/usr/bin/env bash
# =============================================================================
# claude-ai.sh
# Author  : [YOUR NAME]
# Created : 2026-04-04
# Purpose : Profile-based Claude Code launcher with aliases
#
# Usage   : source ~/.claude-ai.sh          # load aliases into current shell
#           claude-ai.sh <profile> [args]   # run directly
#
# Profiles:
#   c89         C89/ANSI C — variable ordering enforced, strict compliance
#   cpp         C++ general — daily coding, Sonnet, skip permissions
#   cpp-adv     C++ advanced — Opus, max effort, large codebase / architecture
#   ps          PowerShell v7 — scripting, Mandatory params enforced
#   chat        Casual conversation — Haiku, fast, cheap
#   history     History / geopolitics / research — Opus, high effort
#   generic     General purpose — Sonnet, balanced defaults
#
# Aliases (load via: source ~/.claude-ai.sh):
#   cc89        → c89 profile
#   ccpp        → cpp profile
#   ccpp+       → cpp-adv profile
#   cps         → ps profile
#   cchat       → chat profile
#   chist       → history profile
#   cai         → generic profile
#   cai-cont    → continue last session (generic model)
#   cai-update  → update Claude Code to latest version
#   cai-status  → show auth status
# =============================================================================

# =============================================================================
# ALL AVAILABLE CLI FLAGS — REFERENCE (as of April 2026)
# Source: https://code.claude.com/docs/en/cli-reference
# =============================================================================
#
# SESSION CONTROL
#   -c, --continue                   Resume most recent conversation in cwd
#   -r, --resume <id|name>           Resume specific session by ID or name
#       --fork-session               Create new session ID when resuming
#       --session-id <uuid>          Use a specific UUID for the session
#   -n, --name <name>                Set display name for session
#       --from-pr <number|url>       Resume sessions linked to a GitHub PR
#       --no-session-persistence     Do not save session to disk (print mode only)
#
# OUTPUT / PRINT MODE
#   -p, --print "query"              One-shot query, then exit (non-interactive)
#       --output-format text|json|stream-json
#       --input-format  text|stream-json
#       --include-partial-messages   Streaming events (needs stream-json)
#       --include-hook-events        Hook lifecycle events in output stream
#       --replay-user-messages       Re-emit user messages on stdout
#       --json-schema '{...}'        Validated structured JSON output (print only)
#       --max-turns <n>              Cap agentic turns (print mode only)
#       --max-budget-usd <n>         Spending cap in USD (print mode only)
#       --fallback-model <model>     Auto-fallback if primary overloaded (print only)
#
# MODEL SELECTION
#       --model <id|alias>           Set model: claude-opus-4-6 | claude-sonnet-4-6
#                                    | claude-haiku-4-5-20251001 | opus | sonnet
#       --effort low|medium|high|max Adaptive reasoning level (Sonnet 4.6 / Opus 4.6)
#                                    max = Opus 4.6 only, does not persist
#
# PERMISSION MODES
#       --dangerously-skip-permissions     Skip ALL permission prompts
#                                          (equivalent to --permission-mode bypassPermissions)
#       --allow-dangerously-skip-permissions  Add bypassPermissions to Shift+Tab cycle
#                                             without starting in it
#       --permission-mode <mode>     default | acceptEdits | plan | auto |
#                                    dontAsk | bypassPermissions
#       --enable-auto-mode           Unlock auto mode in Shift+Tab cycle
#                                    (requires Team/Enterprise/API + Sonnet 4.6 or Opus 4.6)
#       --allowedTools "Bash(git *)" "Read"   Tools that run without prompting
#       --disallowedTools "Edit"              Tools removed from context entirely
#       --tools "Bash,Edit,Read"     Restrict available built-in tools
#                                    Use "" to disable all, "default" for all
#       --permission-prompt-tool <mcp-tool>   MCP tool for permission prompts (non-interactive)
#
# SYSTEM PROMPT
#       --system-prompt "text"       Replace entire system prompt
#       --system-prompt-file <path>  Load system prompt from file (replaces default)
#       --append-system-prompt "text"        Append to default prompt (recommended)
#       --append-system-prompt-file <path>   Append from file to default prompt
#
# WORKING DIRECTORIES
#       --add-dir <path> [<path>...]  Add extra directories for file access
#       --worktree, -w <branch>       Isolated git worktree session
#       --tmux                        Create tmux session for worktree
#                                     --tmux=classic for traditional tmux
#
# MCP (MODEL CONTEXT PROTOCOL)
#       --mcp-config <file|json>     Load MCP servers from JSON file(s)
#       --strict-mcp-config          Only use MCP from --mcp-config, ignore all others
#
# AGENTS / SUBAGENTS
#       --agent <name>               Specify agent for current session
#       --agents '{...}'             Define subagents inline as JSON
#       --teammate-mode auto|in-process|tmux   Agent team display mode
#
# PERFORMANCE / STARTUP
#       --bare                       Minimal mode: skip hooks, skills, plugins,
#                                    MCP, auto-memory, CLAUDE.md (faster startup)
#       --ide                        Auto-connect to IDE if exactly one available
#       --init                       Run init hooks then start interactive mode
#       --init-only                  Run init hooks then exit
#       --maintenance                Run maintenance hooks then start interactive
#
# SETTINGS
#       --settings <file|json>       Load additional settings from file or JSON string
#       --setting-sources user,project,local   Which setting sources to load
#
# PLUGINS
#       --plugin-dir <path>          Load plugins from directory (session only)
#                                    Repeat flag for multiple dirs
#
# REMOTE / WEB
#       --remote "task"              Create new web session on claude.ai
#       --remote-control, --rc       Enable Remote Control (control from claude.ai/app)
#       --teleport                   Resume a web session in local terminal
#
# BROWSER INTEGRATION
#       --chrome                     Enable Chrome browser integration
#       --no-chrome                  Disable Chrome for this session
#
# DEBUG / DIAGNOSTICS
#       --debug [categories]         Debug mode; optionally filter e.g. "api,mcp"
#                                    Negate with "!" e.g. "!statsig,!file"
#       --debug-file <path>          Write debug logs to file (enables debug mode)
#
# API / ADVANCED
#       --betas <header>             Beta headers for API requests (API key users only)
#                                    e.g. interleaved-thinking
#       --channels <plugin>          MCP channel notifications (research preview)
#       --dangerously-load-development-channels  Load non-allowlisted channels (dev)
#
# TOP-LEVEL COMMANDS (not flags)
#   claude update                    Update to latest version
#   claude auth login [--console]    Authenticate (--console for API billing)
#   claude auth logout               Log out
#   claude auth status [--text]      Show auth status
#   claude agents                    List configured subagents
#   claude mcp                       Configure MCP servers
#   claude plugin [install|list...]  Manage plugins
#   claude remote-control            Start remote control server (no local session)
#   claude auto-mode defaults        Print built-in auto mode classifier rules as JSON
#
# =============================================================================
# MODEL IDs (April 2026)
#   claude-opus-4-6                  Opus 4.6  — 1M ctx, 128k out, $15/$75 MTok
#   claude-sonnet-4-6                Sonnet 4.6 — 1M ctx, 64k out,  $3/$15 MTok
#   claude-haiku-4-5-20251001        Haiku 4.5  — 200k ctx,          $0.80/$4 MTok
#   Aliases: opus | sonnet  (resolve to latest in their tier)
# =============================================================================

# ---------------------------------------------------------------------------
# CONFIGURATION — edit these
# ---------------------------------------------------------------------------

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
SETTINGS_DIR="${HOME}/.claude/profiles"

# Per-profile system prompt snippets (appended to Claude's default prompt)
PROMPT_C89='You are assisting with C programming strictly conforming to the C89/ANSI C standard. \
Rules: (1) All variables must be declared at the top of their function before any statements. \
(2) Variables must be declared in order of size, largest first (e.g. double, long, int, short, char). \
(3) No C99/C11 features: no // comments, no mixed declarations and code, no VLAs, no stdint.h unless asked. \
(4) Use /* */ comments only. (5) Prefer explicit casts. Flag any non-C89 construct immediately.'

PROMPT_CPP='You are assisting with C++ development. \
Rules: (1) Default to modern C++ (C++17/20) unless the project context indicates otherwise. \
(2) Prefer RAII, smart pointers, and STL over raw pointers and manual memory. \
(3) Flag undefined behaviour and memory safety issues explicitly. \
(4) When writing functions, include parameter validation.'

PROMPT_CPP_ADV='You are assisting with complex C++ architecture and large codebase work. \
Rules: (1) Think through design decisions before writing code — consider ABI stability, \
compilation time, and testability. (2) Prefer compile-time solutions over runtime where \
appropriate. (3) Flag ODR violations, linker issues, and undefined behaviour. \
(4) When analysing existing code, identify tech debt and scalability concerns explicitly.'

PROMPT_PS='You are assisting with PowerShell v7 scripting and automation. \
Rules: (1) All function parameters must declare [Parameter(Mandatory=$true)] or \
[Parameter(Mandatory=$false)] — the Mandatory attribute must always be present, \
regardless of value. (2) Use approved verbs (Get-, Set-, New-, Remove-, etc.). \
(3) Include [CmdletBinding()] on all advanced functions. (4) Prefer pipeline-friendly \
output. (5) Use #Requires -Version 7 at script top when writing standalone scripts. \
(6) Prefer $PSCmdlet.ShouldProcess for destructive operations.'

PROMPT_BASH_PYTHON='You are assisting with development on LINUX using all the common \
development tools, scripting languages like Python, Perl and BASH, and are an expert in automation. \
You are aware and considerate of the differences between Linux distros, and always ask for clarification if a question is ambiguous. \
You are an expert with DOCKER, and how to compile and run them in a Linux environment. \
Rules: (1) Think through design decisions before writing code or scripts. \
(2) When writing scripts, include error handling and input validation. \
(3) For Dockerfiles, follow best practices for image size and caching. \
(4) When troubleshooting, ask clarifying questions to narrow down the issue.'


PROMPT_CHAT='You are having a casual, friendly conversation. Be concise and direct. \
No need for formal structure unless the topic requires it.'

PROMPT_HISTORY='You are assisting with historical research, geopolitical analysis, and \
current events. Rules: (1) Distinguish clearly between established historical fact, \
scholarly consensus, contested interpretation, and speculation. (2) Cite sources or \
indicate when a claim is from memory vs. verified. (3) Present multiple perspectives \
on contested events. (4) When discussing current geopolitics, flag where analysis \
is time-sensitive and may have changed.'

# ---------------------------------------------------------------------------
# HELPER FUNCTIONS
# ---------------------------------------------------------------------------

_claude_check() {
    if ! command -v "${CLAUDE_BIN}" &>/dev/null; then
        echo "ERROR: claude not found in PATH (looked for: ${CLAUDE_BIN})" >&2
        echo "Install: curl -fsSL https://claude.ai/install.sh | bash" >&2
        return 1
    fi
}

_claude_banner() {
    local profile="${1}"
    local model="${2}"
    printf '\033[1;34m[claude-ai]\033[0m profile=\033[1;33m%s\033[0m model=\033[1;36m%s\033[0m\n' \
        "${profile}" "${model}"
}

# ---------------------------------------------------------------------------
# PROFILES
# ---------------------------------------------------------------------------

# C89 — Sonnet, skip permissions, strict C89 system prompt
claude_c89() {
    _claude_check || return 1
    _claude_banner "c89" "claude-sonnet-4-6"
    "${CLAUDE_BIN}" \
        --model claude-sonnet-4-6 \
        --effort medium \
        --dangerously-skip-permissions \
        --append-system-prompt "${PROMPT_C89}" \
        --name "c89-$(date +%Y%m%d)" \
        "$@"
}

# C++ general — Sonnet, skip permissions, standard C++ prompt
claude_cpp() {
    _claude_check || return 1
    _claude_banner "cpp" "claude-sonnet-4-6"
    "${CLAUDE_BIN}" \
        --model claude-sonnet-4-6 \
        --effort medium \
        --dangerously-skip-permissions \
        --append-system-prompt "${PROMPT_CPP}" \
        --name "cpp-$(date +%Y%m%d)" \
        "$@"
}

# C++ advanced — Opus, high effort, for architecture / large codebases
claude_cpp_adv() {
    _claude_check || return 1
    _claude_banner "cpp-advanced" "claude-opus-4-6 [effort=high]"
    "${CLAUDE_BIN}" \
        --model claude-opus-4-6 \
        --effort high \
        --dangerously-skip-permissions \
        --append-system-prompt "${PROMPT_CPP_ADV}" \
        --name "cpp-adv-$(date +%Y%m%d)" \
        "$@"
}

# PowerShell v7 — Sonnet, skip permissions, PS v7 rules enforced
claude_ps() {
    _claude_check || return 1
    _claude_banner "powershell" "claude-sonnet-4-6"
    "${CLAUDE_BIN}" \
        --model claude-sonnet-4-6 \
        --effort medium \
        --dangerously-skip-permissions \
        --append-system-prompt "${PROMPT_PS}" \
        --name "ps-$(date +%Y%m%d)" \
        "$@"
}

claude_linuxdev() {
    _claude_check || return 1
    _claude_banner "linuxdev" "claude-sonnet-4-6"
    "${CLAUDE_BIN}" \
        --model claude-opus-4-6 \
        --effort high \
        --dangerously-skip-permissions \
        --append-system-prompt "${PROMPT_BASH_PYTHON}" \
        --name "ps-$(date +%Y%m%d)" \
        "$@"
}

# Chat — Haiku, fast and cheap, no need to skip permissions for casual use
claude_chat() {
    _claude_check || return 1
    _claude_banner "chat" "claude-haiku-4-5-20251001"
    "${CLAUDE_BIN}" \
        --model claude-haiku-4-5-20251001 \
        --effort low \
        --append-system-prompt "${PROMPT_CHAT}" \
        --name "chat-$(date +%Y%m%d)" \
        "$@"
}

# History / geopolitics — Opus, high effort, research-grade depth
claude_history() {
    _claude_check || return 1
    _claude_banner "history/geopolitics" "claude-opus-4-6 [effort=high]"
    "${CLAUDE_BIN}" \
        --model claude-opus-4-6 \
        --effort high \
        --append-system-prompt "${PROMPT_HISTORY}" \
        --name "history-$(date +%Y%m%d)" \
        "$@"
}

# Generic — Sonnet, balanced, no extra system prompt
claude_generic() {
    _claude_check || return 1
    _claude_banner "generic" "claude-sonnet-4-6"
    "${CLAUDE_BIN}" \
        --model claude-sonnet-4-6 \
        --effort medium \
        --dangerously-skip-permissions \
        --name "generic-$(date +%Y%m%d)" \
        "$@"
}

# ---------------------------------------------------------------------------
# UTILITY FUNCTIONS
# ---------------------------------------------------------------------------

# Continue last session with no model override (uses whatever the session had)
claude_continue() {
    _claude_check || return 1
    _claude_banner "continue" "last session"
    "${CLAUDE_BIN}" --continue "$@"
}

# Resume by name or ID
# Usage: claude_resume my-session-name
claude_resume() {
    _claude_check || return 1
    if [[ -z "${1}" ]]; then
        echo "Usage: claude_resume <session-name-or-id>" >&2
        return 1
    fi
    _claude_banner "resume" "${1}"
    "${CLAUDE_BIN}" --resume "${1}" "${@:2}"
}

# Quick one-shot print query, no session saved
# Usage: cq "what is the size of a long in C89 on a 32-bit system?"
claude_query() {
    _claude_check || return 1
    if [[ -z "${1}" ]]; then
        echo "Usage: claude_query \"your question\"" >&2
        return 1
    fi
    "${CLAUDE_BIN}" \
        --model claude-sonnet-4-6 \
        --print \
        --no-session-persistence \
        "${1}"
}

# Pipe a file or stdin into Claude for a one-shot analysis
# Usage: cat myfile.c | claude_pipe "explain this code"
claude_pipe() {
    _claude_check || return 1
    local prompt="${1:-explain this}"
    "${CLAUDE_BIN}" \
        --model claude-sonnet-4-6 \
        -p "${prompt}" \
        --no-session-persistence
}

# Update Claude Code
claude_update() {
    _claude_check || return 1
    "${CLAUDE_BIN}" update
}

# Auth status
claude_status() {
    _claude_check || return 1
    "${CLAUDE_BIN}" auth status --text
}

# ---------------------------------------------------------------------------
# ALIASES — source this file to activate them
# Usage: echo 'source ~/.claude-ai.sh' >> ~/.bashrc
# ---------------------------------------------------------------------------

alias cc89='claude_c89'
alias ccpp='claude_cpp'
alias ccpp+='claude_cpp_adv'
alias cps='claude_ps'
alias cchat='claude_chat'
alias chist='claude_history'
alias cai='claude_generic'
alias cai-cont='claude_continue'
alias cai-res='claude_resume'
alias cq='claude_query'
alias cpipe='claude_pipe'
alias cai-update='claude_update'
alias cai-status='claude_status'

# ---------------------------------------------------------------------------
# DIRECT EXECUTION — run as script: ./claude-ai.sh <profile> [args]
# ---------------------------------------------------------------------------

_claude_usage() {
    cat <<'EOF'
Usage: claude-ai.sh <profile> [extra claude flags]

Profiles:
  c89         C89/ANSI C strict mode          (Sonnet, medium effort)
  cpp         C++ general                     (Sonnet, medium effort)
  cpp-adv     C++ advanced / architecture     (Opus,   high effort)
  ps          PowerShell v7                   (Sonnet, medium effort)
  chat        Casual chat                     (Haiku,  low effort)
  history     History / geopolitics           (Opus,   high effort)
  generic     General purpose                 (Sonnet, medium effort)

Utilities:
  continue                    Resume last session
  resume <name|id>            Resume specific session
  query  "question"           One-shot print query, no session saved
  update                      Update Claude Code
  status                      Show auth status

Aliases (source this file first):
  cc89  ccpp  ccpp+  cps  cchat  chist  cai  cai-cont  cai-res  cq  cpipe  cai-update  cai-status
EOF
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Running as a script, not sourced
    case "${1}" in
        c89)        shift; claude_c89 "$@" ;;
        cpp)        shift; claude_cpp "$@" ;;
        cpp-adv)    shift; claude_cpp_adv "$@" ;;
        ps)         shift; claude_ps "$@" ;;
        chat)       shift; claude_chat "$@" ;;
        history)    shift; claude_history "$@" ;;
        linuxdev)   shift; claude_linuxdev "$@" ;;
        generic)    shift; claude_generic "$@" ;;
        continue)   shift; claude_continue "$@" ;;
        resume)     shift; claude_resume "$@" ;;
        query)      shift; claude_query "$@" ;;
        update)     claude_update ;;
        status)     claude_status ;;
        -h|--help|"") _claude_usage ;;
        *)          echo "Unknown profile: ${1}" >&2; _claude_usage; exit 1 ;;
    esac
fi
