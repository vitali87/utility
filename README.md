<p align="center">
    <img src="u7.png" alt="u7 logo" width="600">
</p>

# u7 - Universal 7 CLI

A unified command-line interface with 7 intuitive verbs for humans and AI agents.

## The Universal 7 Verbs

| Verb | Purpose | Example |
|------|---------|---------|
| `sh` | Observe/Search | `u7 sh ip external` |
| `mk` | Create/Clone | `u7 mk password 16` |
| `dr` | Delete/Kill | `u7 dr file temp.txt` |
| `cv` | Transform/Extract | `u7 cv archive to files from backup.tar.gz` |
| `mv` | Relocate/Rename | `u7 mv file.txt to newname.txt` |
| `st` | Modify/Config | `u7 st text "old" to "new" in file.txt` |
| `rn` | Execute/Control | `u7 rn job "echo done" in 5s` |

## Installation

Requires [Nix](https://nixos.org/download.html) with flakes enabled.

```bash
git clone https://github.com/vitali87/utility.git
cd utility
nix develop
```

You're now in a reproducible shell with all dependencies and `u7` ready to use.

## Usage

```bash
# Get help
u7 --help
u7 sh --help

# Network
u7 sh ip external
u7 sh ip internal
u7 sh ssl google.com

# Files
u7 sh files match "TODO" in ./src
u7 sh files by modified
u7 sh csv first 10 from data.csv

# System
u7 sh cpu
u7 sh disk
u7 sh processes by cpu

# Create
u7 mk dir myproject
u7 mk password 32
u7 mk archive backup.tar.gz from ./src

# Transform
u7 cv archive to files from backup.tar.gz
u7 cv png to jpg from image.png yield image.jpg
u7 cv json to yaml from config.json

# Modify
u7 st text "foo" to "bar" in file.txt
u7 st perms to 755 on script.sh

# Execute
u7 rn job "echo done" in 10s
u7 rn background ./long-task.sh
```

## The Grammar

Every command follows a strict formula:

```
u7 <VERB> <ENTITY> [MODIFIER] [OPERATOR ARG]...
```

| Component | Role | Question to Ask |
|-----------|------|-----------------|
| **Verb** | The action (1 of 7) | What am I doing? |
| **Entity** | The noun being acted on | What thing am I manipulating? |
| **Modifier** | Variant or filter | Which subset or type? |
| **Operator Arg** | Relationship + value | From where? To what? How? |

### Operators

| Operator | Relationship | Example |
|----------|--------------|---------|
| `from` | Source | `cv png ... from image.png` |
| `to` | Target state | `st owner to root`, `cv png to jpg` |
| `yield` | File output | `cv ... yield output.jpg` |
| `in` | Container/delay | `st text ... in file`, `rn job ... in 5s` |
| `on` | Target | `st perms to 755 on script.sh` |
| `by` | Criteria | `sh files by size` |
| `for` | Duration | `rn job ... for 30s` |
| `with` | Options | `rn job ... with retry 3` |
| `match` | Filter | `sh files match "TODO"` |

**Modifiers** (not operators — they filter the entity):

| Modifier | Type | Example |
|----------|------|---------|
| `first N` | Position | `sh lines first 10 from file` |
| `last N` | Position | `sh lines last 5 from file` |
| `empty` | State | `dr dirs empty` |
| `blank` | State | `dr lines blank from file` |
| `external/internal` | Property | `sh ip external` |

### The English Litmus Test

Read the command aloud. It must sound like (slightly robotic) English:

- `u7 sh lines first 10 from file` → "Show lines, first 10, from file" ✓
- `u7 st perms to 755 on script.sh` → "Set perms to 755 on script" ✓
- `u7 cv png to jpg from a.png yield b.jpg` → "Convert png to jpg from a.png, yield b.jpg" ✓

## Why u7?

- **Minimal vocabulary**: 7 verbs cover all Unix operations
- **Strict grammar**: `u7 <VERB> <ENTITY> [MODIFIER] [OPERATOR ARG]`
- **Aliases**: Full verbs (`show`, `make`, `drop`, `convert`, `move`, `set`, `run`) also supported
- **AI-friendly**: Predictable structure for humans and AI agents
- **Reproducible**: Nix ensures identical environments everywhere
- **Cross-platform**: Works on Linux and macOS

## Author

Vitali Avagyan: [@vitali87](https://github.com/vitali87)

## License

[![MIT License](https://img.shields.io/apm/l/atomic-design-ui.svg?)](https://choosealicense.com/licenses/mit/)

## Support

If you find this project helpful:

<a href="https://www.buymeacoffee.com/vitali87" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>
