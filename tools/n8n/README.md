# Asset image pipeline (n8n + Nano Banana)

This pipeline turns the prompts in `asset_prompts.json` into images: first **key art**, then **object concepts**,
then **front / side / top reference views**. Those images are the inputs for the Blender steps in
`documentation/design/08_ASSET_PROMPT_PACK.md` §6. It does **not** make 3D models.

It follows the same pattern as the sticker pipeline: a manual trigger, Code nodes, `$env` keys, and WSL paths.
Your sticker, Odoo, and Prodigi workflows are untouched and aren't used here.

## One-time setup

1. In n8n, go to **Workflows → Import from File** and pick `eternal_guild_asset_images.json`. If you already imported
   an older version, delete that one first.
2. That's it. The workflow uses the n8n instance your sticker pipeline runs on, so `GEMINI_API_KEY` and the rest are
   already set. You don't need the game repo on disk either: the prompts are built into the **Load Jobs** node.
3. Everything goes into `F:\raphael reck societe roots time corporation\Roots Time Projects\ART STICKERS\eternal_guild_art\`
   (created on the first run). The sticker pipeline only reads `ART STICKERS\input`, so the two don't mix.
   To use another folder, change `ART_DIR` in the CONFIG block of **Load Jobs**. It must be a folder n8n can see.
4. The first run writes `eternal_guild_art\asset_prompts.json`. After that, edit **that file** to change prompts or
   switch Batch 2 on. `tools/n8n/asset_prompts.json` in the repo is the master copy the node was built from.

## The loop: run → pick → run again

| Run | What it generates | What you do next |
|---|---|---|
| 1 | K1–K3 key art, 4 variants each (12 images) | Copy the best of each to `picked/K1_tavern_exterior.png`, `picked/K2_tavern_interior.png`, `picked/K3_world_map.png` |
| 2 | Batch-1 object concepts, 3 variants each (21 images), each styled from your picked key art | Copy the best of each to `picked/<id>.png` |
| 3 | Front / side / top views of each picked concept (22 images) | Nothing to copy. These views plus the picked concept go to Claude in Blender (§6.1) |

- The **Report + Gallery** output shows the gallery path as a Windows path
  (`F:\...\generated\index.html`). Open it in your browser.
- The gallery shows the exact `picked/...` filename to copy each pick to. `.jpg` and `.webp` also work.
- Nothing else unlocks until the matching pick exists. The report lists what's waiting.

## Things to know

- **Re-running is safe.** Images that already exist are skipped (tracked in `generated/status.json`).
  Don't delete `status.json` unless you want to regenerate, and pay for, everything.
- **What triggers regeneration:**
  - Editing a prompt regenerates only that job.
  - Bumping `"rev"` on a job regenerates it without changing the prompt.
  - Re-picking an image regenerates everything built from it. The older images stay in the gallery, below the new ones.
- **Changing `MODEL` regenerates every job**, because the model is part of each job's identity. Only do it on purpose.
- **Cost cap:** at most `MAX_IMAGES_PER_RUN` (30) images per run, and extra jobs wait for the next run. Check Google's
  current price per image before large runs.
- **A failed image doesn't stop the run.** It's listed in the report and retried on the next run.
  A missing API key, a broken `asset_prompts.json`, or a corrupt `status.json` stops the run with a clear error.
- **Batch 2:** set `"enabled": true` on a job in `asset_prompts.json`.
- **`generated/catalog.csv`** logs every image with its prompt and model. Keep it for Steam's AI-content disclosure.
- **Prompts:** the prompt list mirrors the prompt pack doc. If you change a prompt in one, change it in the other.

## Not included (on purpose, for v1)

- **GPT-image as a second generator.** You can add it later as a copy of the Generate + Save node.
- **Image-to-3D.** That's Route 2 in Blender, through the Blender MCP.
- **An automatic "does this match KayKit?" check by Claude.** Your eye is the check for now.
