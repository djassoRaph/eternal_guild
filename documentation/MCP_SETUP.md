# Eternal Guild — MCP Setup & Usage Guide
Established 2026-06-21. Documents the Model Context Protocol integration for AI-assisted development.

## Overview
Two MCP servers connect Claude Code to the Godot project:
- **gopeak** — editor bridge, static scene/script tools, runtime ping
- **godot-runtime** — runtime interaction server (scene tree, screenshots via TCP)

Both are configured in `C:\Users\fathe\.claude\settings.json`.

## Prerequisites
- Godot 4.4.1 installed at `E:\Godot installer\Godot_v4.4.1-stable_win64.exe`
- Node.js via nvm4w at `C:\nvm4w\nodejs\node.exe`
- MCP Runtime addon installed in project (`addons/godot_mcp_runtime/`)
- `MCPRuntime` autoload enabled in Project Settings (project.godot line 28)
- `McpInteractionServer` autoload enabled (project.godot line 29) — listens on TCP port 9090

## Configuration (settings.json)
```json
{
  "mcpServers": {
    "gopeak": {
      "command": "C:\\nvm4w\\nodejs\\node.exe",
      "args": ["C:\\nvm4w\\nodejs\\node_modules\\gopeak\\build\\cli.js"],
      "env": {
        "GODOT_PATH": "E:\\Godot installer\\Godot_v4.4.1-stable_win64.exe",
        "GOPEAK_TOOL_PROFILE": "compact"
      }
    },
    "godot-runtime": {
      "command": "C:\\nvm4w\\nodejs\\node.exe",
      "args": ["F:\\GAME I AM MAKING\\godot-mcp\\build\\index.js"],
      "env": {
        "GODOT_PATH": "E:\\Godot installer\\Godot_v4.4.1-stable_win64.exe"
      }
    }
  }
}
```

## Ports
| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 7777 | WebSocket | MCPRuntime autoload | gopeak runtime communication (ping, inspect) |
| 9090 | TCP | McpInteractionServer autoload | Scene tree queries, screenshots, game interaction |

## How to Launch the Game for MCP Testing

### Method: Bash launch (recommended)
Launch directly from Claude Code's bash tool:
```bash
"E:/Godot installer/Godot_v4.4.1-stable_win64.exe" -d --path "F:/GAME I AM MAKING/shiningsun" 2>&1 &
```
This opens a visible game window and starts both MCP servers (ports 7777 and 9090).

### Why not gopeak's `editor-run` or godot-runtime's `run_project`?
- **gopeak `editor-run`**: Launches headless — the game runs but no window is visible to the user.
- **godot-runtime `run_project`**: Process spawns then immediately dies. The MCP server loses track of it. Even when a game IS running, godot-runtime only recognizes processes it spawned itself (`this.activeProcess` check). This is a known limitation in the godot-mcp codebase.

### Editor alongside the game
The Godot editor can be open simultaneously. The editor connects to gopeak independently. The "MCP: Connected" indicator in the editor top-right confirms the connection.

## Taking Screenshots
godot-runtime's `game_screenshot` tool does not work (requires its own process tracking). Screenshots are taken via TCP on port 9090:

```javascript
const net = require('net');
const client = new net.Socket();
client.connect(9090, '127.0.0.1', () => {
  client.write(JSON.stringify({type:'request', id:1, command:'screenshot'}) + '\n');
});
let buf = '';
client.on('data', (data) => {
  buf += data.toString();
  try {
    const parsed = JSON.parse(buf);
    if (parsed.data) {
      require('fs').writeFileSync('screenshot.png', Buffer.from(parsed.data, 'base64'));
      console.log('Saved');
    }
    client.destroy();
  } catch(e) {}
});
setTimeout(() => client.destroy(), 15000);
```
The response is a JSON object with a `data` field containing a base64-encoded PNG. Allow 10-15 seconds for large screenshots.

## Querying the Live Scene Tree
Same TCP connection, different command:
```javascript
client.write(JSON.stringify({type:'request', id:1, command:'get_scene_tree'}) + '\n');
```
Returns a nested JSON object with all nodes, types, and children in the running game.

## What Each MCP Can Do

### gopeak (editor + runtime ping)
- `runtime-status` — ping the running game on port 7777
- `project-info` — project metadata (name, version, scene/script counts)
- `scene-nodes` — read scene tree from .tscn files on disk
- `scene-node-properties` — inspect node properties in scene files
- `scene-node-add` / `scene-node-set` / `scene-node-delete` — modify scenes
- `script-create` / `script-modify` — create and edit GDScript files
- `class-query` / `class-info` — query Godot's ClassDB
- `editor-launch` — open the Godot editor GUI
- `editor-run` / `editor-stop` — run/stop game (headless)
- `visualizer-map` — interactive project map at localhost:6505

gopeak also has dynamic tool groups (`runtime`, `testing`, etc.) activated via `tool-groups`, but these tools don't appear in Claude's ToolSearch — they work only through gopeak's internal routing.

### godot-runtime (game interaction — only via TCP workaround)
The MCP tools (`game_screenshot`, `game_get_scene_tree`, etc.) require godot-runtime to have spawned the process. Since that's unreliable, use the TCP port 9090 directly for:
- Screenshots
- Scene tree inspection
- Node property queries
- Method calls on running nodes

## Troubleshooting

### "MCP: Disconnected" in editor
Normal when the game isn't running. The MCPRuntime autoload starts the WebSocket server only when the game launches.

### godot-runtime says "No active Godot process"
Expected. Use bash launch + TCP queries instead. See "How to Launch" above.

### gopeak can't see the game launched from F5
gopeak's `editor-run` and `editor-debug-output` only track processes gopeak spawned. Games launched from the editor's Play button are invisible to gopeak's process tracking, but the runtime on port 7777 still connects — `runtime-status` will show `connected: true`.

### Game crashes on launch via godot-runtime
The space in `E:\Godot installer\` may cause issues in some contexts. Node.js `spawn()` handles it fine, but the process exits immediately for unknown reasons. Use bash launch as the workaround.
