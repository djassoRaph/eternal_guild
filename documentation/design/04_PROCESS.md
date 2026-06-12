# Eternal Guild — Process

**How this project actually runs. For Raphael, Claude, and Claude Code.**
*Last updated: 2026-06-09.*

---

## The two-Claude workflow

- **Claude (chat)** — lead designer and architect. Plans, diagnoses, critiques,
  writes prompts. Does not guess at code it hasn't seen.
- **Claude Code** — executes. Reads real files, makes edits, reports back.
- **Raphael** — decides, tests in-engine, reports results.

## Recon → Build → Commit

Every build step follows this shape. No exceptions, because guessing at
architecture is how this project historically broke.

1. **Recon prompt** — Claude Code reads the actual files, reports structure,
   line numbers, data shapes. **Read-only. No edits during recon.**
2. **Reported answer** — pasted back to chat-Claude.
3. **Scoped build prompt** — written against the reported reality, one file at
   a time, complete functions (never fragments to stitch), non-breaking and
   additive.
4. **Test gate** — a concrete in-engine check Raphael runs before the next step.
5. **Commit** — small, named, on `shiningsun`.

## Hard rules (architecture)

- Signal-based singletons. One source of truth per fact.
- The world map is generated ONCE and persisted. Display-only afterwards.
- JSON-driven content with fallbacks. Reuse DataManager's existing generators.
- Don't fight the pixel shader: UI feedback lives in 2D CanvasLayer overlays.
- `queue_free()` not `hide()` for popups.
- Verify the current version of any file before editing it.
- Check the owner table (02_STATE_OF_THE_BUILD.md) before deciding where logic goes.

## Working style (how to help Raphael)

- Slow down before building. He makes critical errors when rushed — this is
  his own standing instruction, not an insult.
- Design before code. Discuss options first.
- Prose over bullet-spam in design discussion. Short, direct exchanges.
- Flag scope creep out loud, in the moment. The documented pattern: bouncing
  to new topics when detailed work gets close.
- Explain causes of bugs before fixes.
- The smallest version of the end-of-day reveal is the real game; everything
  else serves it. Use this to judge what's worth finishing.
- `[TIMELAPSE]` in a message = returning after sleep.
- Sessions often run late (Paris time).

## Memory & docs discipline

- Distributed small docs beat a monolithic GDD. Single purpose per file.
- Session changelogs are scaffolding: fold their survivals into canon, then
  archive to `documentation/old/`. Do this at the END of a feature, not never.
- 02_STATE_OF_THE_BUILD.md wins every "is this done?" argument.
