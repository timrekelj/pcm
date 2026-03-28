# pcm

`pcm` is a small CLI tool written in Odin for storing and switching PostgreSQL connection strings.

## What it currently does

- Add a named PostgreSQL connection
- List saved connections
- Set the current active connection
- Remove saved connections

The current connection is written in an env-style format so it can be reused in your shell or scripts.

## Commands

- `pcm add`
- `pcm list`
- `pcm set <name>`
- `pcm remove <name>`

## Storage

`pcm` stores its files under:

`~/.local/state/pcm/`

## Build

Build with Odin from the repository root:

`odin build ./src -out:pcm`

## Zed configuration

I currently use this tool to run PostgreSQL queries directly from Zed.

I have created two tasks:
```json
{
    {
        "label": "run_postgresql",
        "command": "source ~/.pcm/current_connection && psql \"$PSQL_CONNECTION\" -x -c \"$(cat <<'EOF'\n$ZED_SELECTED_TEXT\nEOF\n)\"",
        "use_new_terminal": true,
        "shell": "system",
        "show_command": false,
        "tags": ["psql"]
    },
    {
        "label": "run_postgresql_fullscreen",
        "command": "source ~/.pcm/current_connection && psql \"$PSQL_CONNECTION\" -c \"$(cat <<'EOF'\n$ZED_SELECTED_TEXT\nEOF\n)\"",
        "use_new_terminal": true,
        "reveal_target": "center",
        "shell": "system",
        "show_command": false,
        "tags": ["psql"]
    }
}
```

The key bindings I use to run these tasks:
```json
"shift-enter": ["task::Spawn", { "task_name": "run_postgresql" }],
"cmd-shift-enter": [ "task::Spawn", { "task_name": "run_postgresql_fullscreen" } ],
```
