#!/usr/bin/env bash
# Claude CLI status line
# Line 1: model · git branch · dirty · ahead/behind · autorun · session · worktree
# Line 2: context bar · cost · lines changed

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
PARAMS=$(echo "$input" | jq -r '.model.param_summary // ""')
MAX=$(echo "$input" | jq -r 'if .model.max_mode then " MAX" else "" end')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
SESSION=$(echo "$input" | jq -r '.session_name // ""')
IS_AUTORUN=$(echo "$input" | jq -r '.autorun // false')
WORKTREE=$(echo "$input" | jq -r '.worktree.name // ""')
WIDTH=$(echo "$input" | jq -r '.render_width_chars // 80')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // ""')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# ── ANSI helpers ─────────────────────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
MAGENTA="\033[35m"
BLUE="\033[34m"
WHITE="\033[97m"
ORANGE="\033[38;5;208m"

# Dim separator between groups
SEP=" ${DIM}│${RESET} "

# ── Context bar (20 chars wide) ───────────────────────────────────────────────
BAR_WIDTH=20
FILLED=$((PCT * BAR_WIDTH / 100))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
EMPTY=$((BAR_WIDTH - FILLED))

BAR=""
if [ "$FILLED" -gt 0 ]; then
  printf -v FILL "%${FILLED}s"
  BAR="${FILL// /█}"
fi
if [ "$EMPTY" -gt 0 ]; then
  printf -v PAD "%${EMPTY}s"
  BAR="${BAR}${PAD// /░}"
fi

if [ "$PCT" -ge 80 ]; then
  BAR_COLOR="$RED"
elif [ "$PCT" -ge 50 ]; then
  BAR_COLOR="$YELLOW"
else
  BAR_COLOR="$GREEN"
fi

# ── Git branch + dirty count + ahead/behind ───────────────────────────────────
GIT=""
if [ -n "$CWD" ] && git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
  if [ -n "$BRANCH" ]; then
    GIT=" ${MAGENTA}${BRANCH}${RESET}"

    # dirty count
    DIRTY_COUNT=$(git -C "$CWD" status --short 2>/dev/null | wc -l | tr -d ' ')
    [ "$DIRTY_COUNT" -gt 0 ] && GIT="${GIT} ${ORANGE}●${DIRTY_COUNT}${RESET}"

    # ahead / behind upstream
    if COUNTS=$(git -C "$CWD" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null); then
      BEHIND=$(echo "$COUNTS" | cut -f1)
      AHEAD=$(echo "$COUNTS" | cut -f2)
      [ "${AHEAD:-0}" -gt 0 ] && GIT="${GIT} ${GREEN}↑${AHEAD}${RESET}"
      [ "${BEHIND:-0}" -gt 0 ] && GIT="${GIT} ${RED}↓${BEHIND}${RESET}"
    fi

    GIT="${SEP}${DIM}⎇${RESET}${GIT}"
  fi
fi

# ── Model string ──────────────────────────────────────────────────────────────
MODEL_STR="${BOLD}${CYAN}${MODEL}${RESET}"
[ -n "$PARAMS" ] && MODEL_STR="${MODEL_STR} ${DIM}${PARAMS}${RESET}"
[ -n "$MAX" ] && MODEL_STR="${MODEL_STR}${YELLOW}${MAX}${RESET}"

# ── Autorun badge (bold red when active) ─────────────────────────────────────
AUTORUN_BADGE=""
if [ "$IS_AUTORUN" = "true" ]; then
  AUTORUN_BADGE="${SEP}${BOLD}${RED}⚡ AUTORUN${RESET}"
fi

# ── Session / worktree badges ─────────────────────────────────────────────────
BADGES=""
[ -n "$SESSION" ] && BADGES="${BADGES} ${DIM}[${SESSION}]${RESET}"
[ -n "$WORKTREE" ] && BADGES="${BADGES} ${BLUE}⌥ ${WORKTREE}${RESET}"

# ── Cost + lines changed ──────────────────────────────────────────────────────
COST_STR=""
COST_FMT=$(printf "%.2f" "$COST" 2>/dev/null)
if [ "$COST_FMT" != "0.00" ] && [ -n "$COST_FMT" ]; then
  COST_STR="${SEP}${GREEN}\$${COST_FMT}${RESET}"
fi

LINES_STR=""
if [ "${ADDED:-0}" -gt 0 ] || [ "${REMOVED:-0}" -gt 0 ]; then
  LINES_STR="${SEP}${GREEN}+${ADDED}${RESET} ${RED}-${REMOVED}${RESET}"
fi

# ── Render ────────────────────────────────────────────────────────────────────
# Line 1: model + git + autorun + badges
printf "${MODEL_STR}${GIT}${AUTORUN_BADGE}${BADGES}\n"

# Line 2: context window + cost + lines
printf "${DIM}ctx${RESET} ${BAR_COLOR}${BAR}${RESET} ${WHITE}${PCT}%%${RESET}${COST_STR}${LINES_STR}\n"
