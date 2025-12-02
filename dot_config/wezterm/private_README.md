# WezTerm Config

## Design Philosophy

This config mirrors the aerospace window manager bindings to create a **unified navigation experience** across the OS and terminal. The core principle: **same muscle memory, different contexts**.

See also: `~/.config/aerospace/README.md` for the aerospace side of this unified system.

---

## Alignment with Aerospace

| Concept | Aerospace (Meh+) | WezTerm (Cmd+) |
|---------|------------------|----------------|
| **Leader key** | Meh (Alt+Ctrl+Shift via Kanata) | Cmd |
| **Navigation** | M/N/E/I = focus left/down/up/right | M/N/E/I = pane left/down/up/right |
| **Prev/Next** | , / . = prev/next workspace | , / . = prev/next tab |
| **Resize mode** | Meh+R → sticky mode | Cmd+R → sticky mode |
| **Swap mode** | Meh+S → sticky mode | Cmd+S → sticky mode |
| **Exit mode** | A or Esc | A or Esc |

### Key Insight

Both tools use **sticky modes** for infrequent operations (resize, swap), entered via the same keys (R, S) and exited the same way (A on left pinky, or Esc). This means:

1. Learn it once, use it everywhere
2. Right hand does directional work in modes
3. Left hand enters/exits modes

---

## Key Bindings

### Base Layer (Cmd)

| Key | Action |
|-----|--------|
| M/N/E/I | Pane navigation (left/down/up/right) |
| Arrow keys | Pane navigation (alternate) |
| , / . | Previous/next tab |
| Cmd+Alt+Arrow | Previous/next tab (browser-style) |
| 1-9, 0 | Direct tab access |
| T | New tab |
| W | Close pane |
| - | Split vertical |
| \| | Split horizontal |
| Z | Toggle pane zoom |
| O | Workspace switcher |

### Modes

| Entry | Mode | Behavior |
|-------|------|----------|
| Cmd+R | Resize | Adjust pane size directionally (sticky) |
| Cmd+S | Swap | Rotate panes (sticky) |

#### Resize Mode (Cmd+R)
| Key | Action |
|-----|--------|
| M/N/E/I | Resize left/down/up/right |
| Arrow keys | Resize (alternate) |
| A / Esc | Exit to base |

#### Swap Mode (Cmd+S)
| Key | Action |
|-----|--------|
| M/I | Rotate counter-clockwise/clockwise |
| N/E | Rotate counter-clockwise/clockwise |
| A / Esc | Exit to base |

### Other

| Key | Action |
|-----|--------|
| Cmd+C | Copy |
| Cmd+V | Paste |
| Cmd+F | Search |
| Cmd+/ | Quick select |
| Cmd+Shift+X | Copy mode |
| Cmd+Shift+K | Clear scrollback |
| Ctrl+Shift+L | Debug overlay |

---

## Status Bar

The right side of the tab bar shows:
- **Normal**: Workspace name (gray)
- **In mode**: `MODE | workspace` with blue background

This provides visual feedback when in a sticky mode, similar to aerospace's menu bar indicator.

---

## Differences from Aerospace

| Feature | Aerospace | WezTerm | Reason |
|---------|-----------|---------|--------|
| Named workspaces | Yes (1-personal, 2-llm, etc.) | No (uses tabs + workspaces) | WezTerm workspaces are dynamic |
| Tidy mode | Yes (layout toggles) | No | WezTerm layouts are automatic |
| Floating-nav mode | Yes (escape floating windows) | No | No floating concept in terminal |
| Swap behavior | Directional move | Rotate panes | WezTerm doesn't have directional swap |

---

## Physical Layout

Optimized for:
- **Colemak-DH** keyboard layout
- **Cmd key** accessible on thumb (internal keyboard) or thumb cluster (ortholinear)

The M/N/E/I keys are the Colemak equivalent of Vim's H/J/K/L for directional navigation.
