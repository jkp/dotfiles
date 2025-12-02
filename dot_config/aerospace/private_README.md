# Aerospace Config

## Design Philosophy

This config unifies window navigation around a simple principle: **right hand for all actions, left hand for mode entry only**.

### The Problem

The original config had workspace switching on the left hand (A/R/S/T keys) and navigation on the right hand (M/N/E/I in Colemak). This created cognitive load - different hands did different types of things, and the bindings didn't mirror well to WezTerm for a unified navigation experience.

### The Solution

1. **Right hand owns all actions** - whether focusing windows, switching workspaces, resizing, or moving things around, the right hand does the work
2. **Left hand only enters modes** - the left home row (A/R/S/T) activates different operational modes
3. **Frequency determines layer depth**:
   - Most frequent (focus, workspace switch) → Base layer (Meh only)
   - Less frequent (move window) → Overlay layer (Meh+Cmd)
   - Infrequent (resize, layout, tidy) → Modes (Meh + left key → sticky mode)

### Physical Layout Considerations

This config is optimized for:
- **Colemak-DH** keyboard layout
- **Ortholinear keyboard** with thumb clusters (external) or standard keyboard (internal)
- **Kanata** remapping spacebar hold to Meh (Alt+Ctrl+Shift)

The right hand has 15 keys (5 columns × 3 rows). Four are used for directional navigation (M/N/E/I), leaving 11 for workspaces and other functions.

Workspace positions were chosen by:
- **Index fingers (L/H)** → Personal/Work browsers (mirrored vertically)
- **Comfortable keys** → Frequent workspaces (terminal, llm, messages)
- **Awkward inner index (J/K)** → Scratch workspaces (infrequent)
- **Pinky stretch (;, /)** → Less frequent (music, notes)

### Layer Structure

```
┌─────────────────────────────────────────────────────────────────┐
│ BASE LAYER (Meh)                                                │
│   Right hand: Focus + Workspaces                                │
│   Left hand: Mode entry (A/R/S/T)                               │
├─────────────────────────────────────────────────────────────────┤
│ OVERLAY LAYER (Meh+Cmd)                                         │
│   Same keys as base, but MOVE instead of focus/switch           │
├─────────────────────────────────────────────────────────────────┤
│ MODES (entered via Meh + left key, sticky until A or Esc)       │
│   A → Floating-nav: Focus including floating windows            │
│   R → Resize: Directional resize                                │
│   S → Swap: Move windows in direction                           │
│   T → Tidy: Layout toggles, balance, flatten, fullscreen        │
└─────────────────────────────────────────────────────────────────┘
```

### Why Sticky Modes?

All modes are sticky (stay in mode until explicitly exiting with `A` or `Esc`). This was chosen over one-shot because:
- Easier to reason about - you're either in a mode or you're not
- Often want to perform multiple actions (resize several times, try different layouts)
- Consistent mental model across all modes
- `A` (left pinky) is a natural "cancel/exit" gesture

---

## Base Layer (Meh only)

### Right Hand Layout
```
Row 1:  J(8-scratch)  L(1-personal)  U(2-llm)    Y(3-messages)  ;(4-music)
Row 2:  M(←focus)     N(↓focus)      E(↑focus)   I(→focus)      O(5-terminal)
Row 3:  K(9-scratch)  H(6-work)      ,(prev)     .(next)        /(7-notes)
```

### Bindings
| Key | Action |
|-----|--------|
| M/N/E/I | Focus left/down/up/right |
| L | workspace 1-personal |
| U | workspace 2-llm |
| Y | workspace 3-messages |
| ; | workspace 4-music |
| O | workspace 5-terminal |
| H | workspace 6-work |
| / | workspace 7-notes (NOTE: Meh+Cmd+/ move binding not working - investigate) |
| J | workspace 8-scratch |
| K | workspace 9-scratch |
| , | workspace prev (wrap) |
| . | workspace next (wrap) |
| backspace | focus-back-and-forth |

---

## Overlay Layer (Meh+Cmd)

Same keys, but **move window** instead of focus/switch:

| Key | Action |
|-----|--------|
| M/N/E/I | Move window left/down/up/right |
| L/U/Y/;/O/H/J/K// | Move window to workspace + follow |

---

## Mode Entry (Meh + left hand home row)

| Key | Mode | Purpose |
|-----|------|---------|
| A | Floating-nav | Escape floating windows |
| R | Resize | Resize windows directionally |
| S | Swap | Move windows in direction |
| T | Tidy | Layout and housekeeping |

### Floating-nav Mode (Meh+A)
| Key | Action |
|-----|--------|
| M/N/E/I | Focus left/down/up/right (includes floating) |
| A / Esc | Exit to main mode |

### Resize Mode (Meh+R)
| Key | Action |
|-----|--------|
| M/N | resize smart -50 |
| E/I | resize smart +50 |
| A / Esc | Exit to main mode |

### Swap Mode (Meh+S)
| Key | Action |
|-----|--------|
| M/N/E/I | Move window left/down/up/right |
| A / Esc | Exit to main mode |

### Tidy Mode (Meh+T)
| Key | Action |
|-----|--------|
| N | layout horizontal/vertical toggle |
| E | layout accordion/tiles toggle |
| I | balance-sizes |
| O | flatten-workspace-tree |
| M | macos-native-fullscreen |
| A / Esc | Exit to main mode |

---

## Utilities (Meh+Cmd)

| Key | Action |
|-----|--------|
| V | toggle-keymapp.sh |
| C | cleanup-phantom-windows.sh |

---

## Auto-assignment Rules

| App | Workspace |
|-----|-----------|
| Keymapp | layout floating |
| Spotify, JPLAY | 4-music |
| Obsidian | 7-notes |
| Claude | 5-terminal |
| ChatGPT | 2-llm |
| WhatsApp, Messages | 3-messages |

---

## Other Config
- `exec-on-workspace-change` → sticky-keymapp.sh (keeps Keymapp on active workspace)
- `after-startup-command` → borders (window border highlighting)
- `on-focused-monitor-changed` → move-mouse monitor-lazy-center
- Gaps: 10px inner, 5px outer
