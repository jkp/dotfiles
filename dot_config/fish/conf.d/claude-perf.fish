# Tune Bun/JSC garbage collection for long-running Claude Code sessions
# See: https://github.com/anthropics/claude-code/issues/22509
set -gx MIMALLOC_PURGE_DELAY 0
set -gx MIMALLOC_ARENA_EAGER_COMMIT 0
set -gx BUN_JSC_gcMaxHeapSize 1500000000
set -gx BUN_JSC_smallHeapRAMFraction 0.05
set -gx BUN_JSC_mediumHeapRAMFraction 0.15
set -gx BUN_GC_TIMER_INTERVAL 300
set -gx CLAUDE_CODE_NO_FLICKER 1
