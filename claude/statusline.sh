#!/usr/bin/env bash
# Claude CLI status line
# Shows: model · context bar · git branch · dirty count · autorun · session · worktree

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

# ── Git branch + dirty count ──────────────────────────────────────────────────
BRANCH=""
DIRTY=""
if [ -n "$CWD" ] && git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
  [ -n "$BRANCH" ] && BRANCH=" ${DIM}on${RESET} ${MAGENTA}${BRANCH}${RESET}"

  DIRTY_COUNT=$(git -C "$CWD" status --short 2>/dev/null | wc -l | tr -d ' ')
  if [ "$DIRTY_COUNT" -gt 0 ]; then
    DIRTY=" ${ORANGE}~${DIRTY_COUNT}${RESET}"
  fi
fi

# ── Model string ──────────────────────────────────────────────────────────────
MODEL_STR="${BOLD}${CYAN}${MODEL}${RESET}"
[ -n "$PARAMS" ] && MODEL_STR="${MODEL_STR} ${DIM}${PARAMS}${RESET}"
[ -n "$MAX" ] && MODEL_STR="${MODEL_STR}${YELLOW}${MAX}${RESET}"

# ── Autorun badge (bold red when active) ─────────────────────────────────────
AUTORUN_BADGE=""
if [ "$IS_AUTORUN" = "true" ]; then
  AUTORUN_BADGE=" ${BOLD}${RED}⚡ AUTORUN${RESET}"
fi

# ── Session / worktree badges ─────────────────────────────────────────────────
BADGES=""
[ -n "$SESSION" ] && BADGES="${BADGES} ${DIM}[${SESSION}]${RESET}"
[ -n "$WORKTREE" ] && BADGES="${BADGES} ${BLUE}⎇ ${WORKTREE}${RESET}"

# ── Render ────────────────────────────────────────────────────────────────────
# Line 1: model + git branch + dirty count + autorun + badges
printf "${MODEL_STR}${BRANCH}${DIRTY}${AUTORUN_BADGE}${BADGES}\n"

# Line 2: context window
printf "${DIM}ctx${RESET} ${BAR_COLOR}${BAR}${RESET} ${WHITE}${PCT}%%${RESET} ${DIM}used${RESET}\n"
