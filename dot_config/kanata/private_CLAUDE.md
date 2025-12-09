# Kanata Configuration

## Validation

Always validate config changes before telling the user to reload:

```bash
kanata --check --cfg /Users/jkp/.config/kanata/colemak-dh-iso.kbd
```

## Key Syntax Notes

- Actions in `defchordsv2` need parentheses for complex actions, bare names for simple keys
- `caps-word` requires a timeout parameter: `(caps-word 2000)`
- Simple keys like `esc` don't need parentheses in chord definitions
- `one-shot` syntax: `(one-shot <timeout> <action>)`

## Testing Changes

After editing, always run the check command above before asking the user to reload the config.
