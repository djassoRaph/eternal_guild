extends SceneTree

## Standalone failsafe tests — no framework, no autoloads needed.
## Run via CLI:
##   "E:\Godot installer\Godot_v4.4.1-stable_win64.exe" --headless --script res://test/failsafe_test.gd --path "F:\GAME I AM MAKING\shiningsun"
## Test 5 (asset-path integrity, Epic 25 / Story 25.1) checks every res:// path referenced
## from data/**/*.json against disk; known gaps live in res://test/asset_path_allowlist.json.
## Test 6 (ruin reservation, Story 25.2) loads HexMapGenerator.gd / WorldManager.gd, which name
## autoloads; those names only resolve once the engine has registered the autoloads, so the suite
## runs from _initialize() rather than _init(). Autoloads start either way (they always did); the
## tests themselves still use none of them. A watchdog guarantees the run ends (SaveSystem's
## 300 s autosave must never fire from a test run).
## Test 14 (mission payout, playtest 2026-09-25) is the exception: it drives GameManager's real
## mission resolver, so it waits one frame for the autoloads' _ready (DataManager's data) and runs
## last. Its fixtures keep every codex.dat write path unreachable (see the test).

const ASSET_ALLOWLIST_PATH := "res://test/asset_path_allowlist.json"
const WORLDGEN_FIXTURE_PATH := "res://test/fixtures/worldgen_seed_12345.json"
const RUIN_TOPPER_PATH := "res://assets/environment/custom/d1_prior_ruins.gltf"
const WATCHDOG_SECONDS := 120.0
const TAVERN_SCENE_PATH := "res://scenes/MainTavern.tscn"
const TAVERN_COLLIDERS_FIXTURE := "res://test/fixtures/tavern_colliders.json"
const ARCH_PATH := "SubViewportContainer/SubViewport/TavernNavigation/Architecture/"
const SHELL_KIT := ["b9_floor", "b9_wall_full", "b9_wall_window", "b9_wall_doorway", "b9_wall_low",
	"b9_post_full", "b9_post_low", "b9_beam", "b10_door_frame", "b10_door_leaf"]
# New colliders added by Story 25.3 (world AABB [x, y, z] ranges): the south-wall gap either side
# of the front door, and the two back corner holes Raphael asked to close (2026-09-24).
const SHELL_NEW_COLLIDERS := {
	"Shell/NearWalls/GapColliderWest/CollisionShape3D": [[6.73, 8.4], [0.0, 4.0], [4.33, 4.63]],
	"Shell/NearWalls/GapColliderEast/CollisionShape3D": [[10.8, 14.84], [0.0, 4.0], [4.33, 4.63]],
	"Shell/FarWalls/CornerCollider/CollisionShape3D": [[-5.15, -4.85], [0.0, 4.0], [-19.17, -16.66]],
	"Shell/NearWalls/CornerColliderEast/CollisionShape3D": [[14.84, 15.14], [0.0, 4.0], [-19.17, -16.59]],
}
# Review 2026-10-03 (Story 25.3): the hall floor collider ends at z 4.43 (top y 0.10) and the porch's starts at
# z 4.72, 0.43 m lower (top y -0.33): too high a step for the bake's 0.25 m climb, so the navmesh had no doorway.
# DoorThreshold is an invisible wedge under the doorway (between GapColliderWest and GapColliderEast) whose top
# runs from the hall floor's top down to the porch's.
const DOOR_THRESHOLD := "Shell/NearWalls/DoorThreshold/CollisionShape3D"
const DOORWAY_X := [8.4, 10.8]                 # the gap between GapColliderWest and GapColliderEast
const HALL_FLOOR_TOP := 0.100175               # the Floor collider's top
const PORCH_FLOOR_TOP := -0.332313             # the FloorEntrance collider's top
const HALL_NAV_POINT := Vector3(9.6, 0.42, 2.0)    # in the hall, 2.5 m inside the front door
const PORCH_NAV_POINT := Vector3(9.6, 0.17, 6.5)   # on the porch, 2 m outside it
# Story 25.8: the Guild Tavern outside (A1), its hex miniature (A2) and the home marker (C9).
const A1_PATH := "res://assets/environment/custom/a1_guild_tavern.gltf"
const A2_PATH := "res://assets/environment/custom/a2_guild_tavern_mini.gltf"
const C9_PATH := "res://assets/environment/custom/c9_home_marker.gltf"
const OLD_TAVERN_PATH := "res://assets/environment/hexagons/blue/building_tavern_blue.gltf"
const EXTERIOR_SCENE_PATH := "res://scenes/world/ExteriorWorld.tscn"
const EXIT_ZONE_SCRIPT_PATH := "res://scripts/world/exit_zone_interior.gd"
const ENTRANCE_ZONE_SCRIPT_PATH := "res://scripts/world/entrance_zone_exterior.gd"
const EDGE_SHADER_PATH := "res://assets/shaders/edge_detection.gdshader"
const PLAYER_RADIUS := 0.5   # Player.tscn CapsuleShape3D radius
# Story 25.29: the exterior terrain (hill, path, stream), bridge, village and forest.
const TERRAIN_PATH := "res://assets/environment/custom/a6_exterior_terrain.gltf"
const BRIDGE_PATH := "res://assets/environment/custom/a6_bridge.gltf"
const HEIGHTFIELD_FIXTURE := "res://test/fixtures/exterior_heightfield.json"
const PLAYER_MANAGER_PATH := "res://scripts/autoload/PlayerManager.gd"
const SEATED_GROUPS := ["Village/", "Yard/", "Forest/", "Scatter/", "Props/"]
const SEATED_ROOT_NODES := ["GuildTavern", "barrel2", "candle_thin_lit_obj", "candle_thin_lit_obj (1)"]
# Story 25.4: the Hourglass Pillar (B6) at the centre of the round bar, with reveal stages.
const PILLAR_PATH := "res://assets/environment/custom/b6_hourglass_pillar.gltf"
const PILLAR_SCENE_PATH := "res://scenes/game/HourglassPillar.tscn"
const PILLAR_SCRIPT_PATH := "res://scripts/game/hourglass_pillar.gd"
const PILLAR_RING_CENTRE := Vector3(7.74, 0.1, -8.22)   # TavernCounterCircular origin, floor top
const GAME_CONFIG_PATH := "res://data/config/game_config.json"
const PILLAR_STAGES := {
	0: ["pillar_foundation", "pillar_base", "pillar_stub"],
	1: ["pillar_foundation", "pillar_base", "pillar_band_low"],
	2: ["pillar_foundation", "pillar_base", "pillar_band_low", "pillar_hourglass"],
	3: ["pillar_foundation", "pillar_base", "pillar_band_low", "pillar_hourglass", "pillar_band_high"],
	4: ["pillar_foundation", "pillar_base", "pillar_band_low", "pillar_hourglass", "pillar_band_high", "pillar_capital"],
}

const HEARTH_PATH := "res://assets/environment/custom/b1_hearth.gltf"
const FIREWOOD_LOG_PATH := "res://assets/environment/custom/h3_firewood_log.gltf"
const FIREWOOD_BUNDLE_PATH := "res://assets/environment/custom/h3_firewood_bundle.gltf"
const HEARTH_SCENE_PATH := "res://scenes/game/Hearth.tscn"
const HEARTH_SCRIPT_PATH := "res://scripts/game/hearth.gd"
const FIRE_ZONE_SCRIPT_PATH := "res://scenes/fireplace_zone.gd"
const MINIGAME_SCRIPT_PATH := "res://scenes/ui/script/FireplaceMinigamePanel.gd"
const HEARTH_SPOT := Vector3(-4.87, 0.1, -9.3)     # on the far wall's inner face, floor top
const HEARTH_APPROACH := Vector3(-2.5, 1.0, -9.3)  # where the player stands to tend the fire
const HEARTH_BLOCKED := Vector2(-3.6, -9.3)       # on the navmesh before 25.5; beside the chimney body after
                                                   # (the 0.2 m apron is under the agents' 0.25 m climb, so it stays walkable)
const HEARTH_OBJECTS := ["hearth_stone", "mantel", "mantel_props", "andirons", "ember_bed", "hearth_runes"]
const HEARTH_MARKERS := ["sit_point", "interact_point", "fire_point", "smoke_point", "onibi_point"]

const ROUND_BAR_PATH := "res://assets/environment/custom/b2_round_bar.gltf"
const BAR_STOOL_PATH := "res://assets/environment/custom/b2_bar_stool_tall.gltf"   # Story 25.31 S2.0 (R-5); 25.6's b2_bar_stool.gltf stays on disk
## Story 25.31 S2.0 (R-5): the realistic sit clips' soles relative to the hips, measured on REAL-1 / REAL-2's Sit_Chair_Idle
## (heels 0.268 / 0.287, toes 0.620 / 0.580 ahead of the hips): the stool's footrest must lie under both.
const SIT_SOLES_AHEAD := Vector2(0.29, 0.58)
const BACK_BAR_PATH := "res://assets/environment/custom/b12_back_bar.gltf"
const TANKARD_FULL_PATH := "res://assets/environment/custom/h1_tankard_full.gltf"
const TANKARD_EMPTY_PATH := "res://assets/environment/custom/h1_tankard_empty.gltf"
const ROUND_BAR_SCENE_PATH := "res://scenes/game/RoundBar.tscn"
const BAR_STOOL_SCENE_PATH := "res://scenes/game/BarStool.tscn"
const SPAWNER_SCRIPT_PATH := "res://scripts/npcs/PatronSpawner.gd"
const PATRON_SCRIPT_PATH := "res://scripts/npcs/RealisticPatron.gd"
const OLD_BAR_NODES := ["Architecture/TavernCounterCircular", "Architecture/Keg", "Furniture/Bar/BarCounter",
	"Furniture/Stool2", "Furniture/Stool3", "Furniture/Stool4", "Furniture/Plate"]

const DESK_PATH := "res://assets/environment/custom/b3_guild_desk.gltf"
const BOARD_PATH := "res://assets/environment/custom/b4_mission_board.gltf"
const DESK_SCENE_PATH := "res://scenes/game/GuildDesk.tscn"
const NOTICE_SCENE_PATH := "res://scenes/game/GuildNoticeBoard.tscn"
const NOTICE_SCRIPT_PATH := "res://scripts/game/notice_board.gd"
const DESK_SPOT := Vector3(11.6, 0.1, -4.3)      # the guild desk's floor centre, facing +z (the room)
const BOARD_SPOT := Vector3(4.3, 0.1, -14.5)     # under the board on the partition's face, facing +z
const OLD_DESK_NODES := ["Furniture/Desk/MissionDesk", "Furniture/Chairs/Chair6", "Furniture/MissionBoard", "Environment/DeskLight"]

const DEMO_CLASSES := ["Fighter", "Rogue", "Mage", "Healer", "Barbarian", "Ranger"]   # D-3, 2026-09-24
const CLASSES_PATH := "res://data/characters/classes.json"
const CLASS_COLORS_PATH := "res://data/config/class_colors.json"
const FLAVOR_LINES_PATH := "res://data/reveal/flavor_lines.json"
const HEALER_MODEL_PATH := "res://assets/characters/custom/healer.glb"
const RANGER_MODEL_PATH := "res://assets/characters/custom/ranger.glb"
const GAME_MANAGER_PATH := "res://scripts/GameManager.gd"
const CAST_CLIPS := ["Idle", "Walking_A", "Running_A", "Sit_Chair_Down", "Sit_Chair_Idle", "Sit_Chair_StandUp", "Cheer", "Interact"]
const TOWNSFOLK_PATH := "res://data/characters/townsfolk.json"
const TOWNSFOLK_ROLES := ["farmer", "local", "traveller", "guard", "merchant", "old_woman"]   # Story 25.14
## Story 25.31 S2: the realistic townsfolk (route RL): their mesh prefixes, props, the patron / villager bodies' loops
## and one-shots (V12), and Walking_A / Running_A's measured ground speeds (real_townsfolk.measure; V9).
const TOWNSFOLK_PREFIX := {"farmer": "Farmer", "local": "Local", "traveller": "Traveller", "guard": "Guard",
	"merchant": "Merchant", "old_woman": "OldWoman"}
const TOWNSFOLK_PROPS := {"merchant": ["Merchant_Purse"], "old_woman": ["OldWoman_Cane"]}
const CAST_LOOPS := ["Idle", "Walking_A", "Running_A", "Sit_Chair_Idle"]
const CAST_ONE_SHOTS := ["Sit_Chair_Down", "Sit_Chair_StandUp", "Cheer", "Interact"]
const TOWNSFOLK_GROUND := {"farmer": [1.143, 2.629], "local": [1.207, 2.754], "traveller": [1.207, 2.629],
	"guard": [1.175, 2.671], "merchant": [1.111, 2.796], "old_woman": [1.026, 2.004]}
const PATRON_ORIGIN_TYPES := ["traveler", "local", "soldier", "trader"]
const PATRON_LINES_PATH := "res://data/dialogue/patron_lines.json"
const VILLAGER_BARKS_PATH := "res://data/dialogue/villager_barks.json"
const BARK_REGISTERS := ["grievance", "mirror", "paranoia"]   # narrative-design.md, the Villager's Voice
const BANNED_BARK_WORDS := ["the state", "government", "politician", "democracy", "capitalism", "okay"]
const VILLAGER_SCRIPT_PATH := "res://scripts/npcs/villager.gd"
const VILLAGER_SCENE_PATH := "res://scenes/npcs/Villager.tscn"
const CAT_PATH := "res://assets/characters/custom/g11_the_cat.glb"   # Story 25.15
const CAT_BASKET_PATH := "res://assets/environment/custom/b20_cat_basket.gltf"
const CAT_SCENE_PATH := "res://scenes/game/TheCat.tscn"
const CAT_SCRIPT_PATH := "res://scripts/game/the_cat.gd"
const CAT_LOOPS := ["Idle", "Sleep", "Walk"]
const HEARTH_INTERACT := Vector3(-2.98, 0.13, -9.30)   # the Hearth's interact_point in MainTavern: where the fire is tended
const DEN_FA_PATH := "res://assets/characters/custom/g9_den_fa.glb"   # Story 25.10
const DEN_FA_SCENE_PATH := "res://scenes/game/DenFa.tscn"
const DEN_FA_SCRIPT_PATH := "res://scripts/game/den_fa.gd"
const DEN_FA_LOOPS := ["Idle", "Sit", "Walk"]
const DEN_FA_ONE_SHOTS := ["Point", "StandUp", "SitDown"]
const DEN_FA_STATES := ["Sit", "SitDown", "StandUp", "Idle", "Walk", "Point"]
const KNIGHT_TOP := 2.315          # KayKit Knight head top, the tallest of the chibi cast
const FIRE_ANCHOR := Vector3(-2.970, 0.100, -9.300)   # the Hearth's interact_point, world (MainTavern)
const CAT_WORLD := Vector3(-2.937, 0.160, -6.895)
const BAR_SPOT := Vector3(3.95, 0.10, -7.55)            # between Stool03 and Stool04
const STAFF_DATA_PATH := "res://data/characters/staff.json"          # Story 25.13
const BARTENDER_PATH := "res://assets/characters/custom/g12_bartender_real.glb"       # Story 25.31: the realistic body (route RL)
const BARTENDER_FALLBACK_PATH := "res://assets/characters/custom/g12_bartender.glb"   # the 25.13 KayKit-rig Bartender: his fallback
const DEALER_PATH := "res://assets/characters/custom/g13_quest_dealer_real.glb"        # Story 25.31 (R-2): the realistic body
const DEALER_FALLBACK_PATH := "res://assets/characters/custom/g13_quest_dealer_anime_v2.glb"   # her anime body, the face-seam fix (Q3)
const DEALER_KAYKIT_PATH := "res://assets/characters/custom/g13_quest_dealer.glb"      # the 25.13 KayKit dealer (on disk, unused)
const BARTENDER_SCENE := "res://scenes/game/Bartender.tscn"
const DEALER_SCENE := "res://scenes/game/QuestDealer.tscn"
const STAFF_BASE_SCRIPT := "res://scripts/game/staff_npc.gd"
const BARTENDER_SCRIPT := "res://scripts/game/bartender.gd"
const DEALER_SCRIPT := "res://scripts/game/quest_dealer.gd"
const FRONT_DOOR_SCRIPT := "res://scripts/game/front_door.gd"
const STAFF_CLIPS := ["Walk_Bar", "Wipe", "Pour", "Serve", "Restock", "Write", "Brief"]
const STAFF_LOOPS := ["Idle", "Walking_A", "Walk_Bar", "Sit_Chair_Idle", "Wipe", "Restock", "Write", "Brief"]
const STAFF_ONE_SHOTS := ["Pour", "Serve", "Sit_Chair_Down", "Sit_Chair_StandUp", "Interact"]
const BARTENDER_MESH_ALLOW := ["Barbarian_Body", "Barbarian_Head", "Barbarian_ArmLeft", "Barbarian_ArmRight", "Barbarian_LegLeft", "Barbarian_LegRight"]
const DEALER_MESH_ALLOW := ["Mage_Body", "Mage_ArmLeft", "Mage_ArmRight", "Mage_LegLeft", "Mage_LegRight", "Rogue_Head"]
const RING_CENTER := Vector3(7.740, 0.100, -8.215)     # the RoundBar's origin (MainTavern, no rotation)
const DOOR_CENTER := Vector3(9.6, 0.0, 4.48)            # the FrontDoor's origin
const DESK_WORLD := Vector3(11.600, 0.100, -4.300)      # the GuildDesk's origin (Furniture offset included)
const DESK_SLAB_BACK := -4.776                          # the desk top's back edge (world z); its slab is y 0.88..0.95
const DEALER_IDLE_FRONT := 0.363                        # the Mage body's Idle front at desk-top height (measured, T0)
const LINTEL_Y := 2.30                                  # the door frame's lintel
# Story 25.30: the anime cast (route AN). Per-role clip lists: the dealer's file carries the 76 KayKit clips + her three.
const DEALER_CLIPS := ["Walk_Bar", "Write", "Brief"]
const DEALER_EXCLUDED := ["Wipe", "Pour", "Serve", "Restock"]
const DEALER_LOOPS := ["Idle", "Walking_A", "Walk_Bar", "Sit_Chair_Idle", "Write", "Brief"]
const DEALER_ONE_SHOTS := ["Sit_Chair_Down", "Sit_Chair_StandUp", "Interact"]
const DEALER_BODY_KEYS := ["hip_back", "stool_pull", "seated_front", "walk_half_at_desk", "idle_front", "bubble_seated", "hall_speed", "bar_speed"]
const ANIME_LOOK_SCRIPT := "res://scripts/game/anime_look.gd"
const ANIME_OUTLINE := "res://assets/characters/materials/anime_outline.tres"
const ANIME_TOON_SHADER := "res://assets/characters/materials/anime_toon.gdshader"
const AN_TRI_CAP := 10000              # the hard cap per AN body (whole GLB, props included)
const AN_BODY_SURFACES := 3            # surfaces on <Role>_Body (props counted apart)
const AN_TRI_BUDGET := 10000           # min(10000, ceil(9,459 measured x 1.15 / 500) x 500) = the cap (T3); the same number as 08
const AN_SIT_HIPS_Y := 0.450           # the re-fitted Sit_Chair_Idle hips height (model-local): T2's SIT_HIPS_Y (Base_Body; her seat within 0.03)
const AN_SEATED_SHOULDER_MIN := 1.05   # seated upperarm heads, root-local: the desk top 0.85 + 0.20 (N2)
## Story 25.31: REAL-2's sit re-fit (Sit_Chair_Idle's hips, model-local) and the realistic dealer's seated shoulders. Her
## shoulders measure 1.034, under 25.30's desk top + 0.20 (1.05): raise the desk stool or lower the desk is Raphael's call
## at Stage D (AC 6b); until then the measured value is the floor.
const RL_SIT_HIPS_Y_W := 0.5164
const RL_SEATED_SHOULDER_MIN_W := 1.03
# Story 25.31: the realistic cast (route RL; AH-15). The AN rules stay for the anime dealer (her fallback since R-2).
const RL_TRI_CAP := 10000              # per body, props included (14,000 only with re-measured hall and town budgets)
const RL_TRI_BUDGET := 10000
const RL_BODY_SURFACES := 3            # surfaces on <Role>_Body (props apart)
const RL_TEXTURES := 2                 # textures per body (the head projection + the body atlas), each <= RL_TEX_SIZE
const RL_TEX_SIZE := 1024
const RL_TOP := [1.50, 2.25]           # rest top with headwear (the lintel rule kept)
## The Bartender's own clips on route RL (N9: clips per role) and his loops (V12).
const BARTENDER_CLIPS := ["Walk_Bar", "Wipe", "Pour", "Serve", "Restock"]
const BARTENDER_EXCLUDED := ["Write", "Brief"]
const BARTENDER_LOOPS := ["Idle", "Walking_A", "Walk_Bar", "Sit_Chair_Idle", "Wipe", "Restock"]
const BARTENDER_ONE_SHOTS := ["Pour", "Serve", "Sit_Chair_Down", "Sit_Chair_StandUp", "Interact"]
## His body block (staff.json bartender › barkeep), measured by tools/blender/realistic/real_bar.py (V14).
const BARTENDER_BODY_KEYS := ["hall_speed", "bar_speed", "serve_r", "restock_r", "ring_r", "keg_r", "gap_r",
	"walk_bar_half_low", "walk_bar_half_shelf", "walk_bar_half_mid", "tankard_scale"]
const DIALOGUE_DIR := "res://data/dialogue/"                       # Story 10.2
const DEN_FA_DIALOGUE := "res://data/dialogue/den_fa.dialogue"
const SPEAKERS_PATH := "res://data/dialogue/speakers.json"
const BRIDGE_SCRIPT := "res://scripts/dialogue/dialogue_bridge.gd"
const RUNNER_SCRIPT := "res://scripts/dialogue/dialogue_runner.gd"
const BOX_SCENE := "res://scenes/ui/DialogueBox.tscn"
const BOX_SCRIPT := "res://scripts/ui/dialogue_box.gd"
const PLAYER_SCENE := "res://scenes/player/Player.tscn"
## Test 24 (Story 25.31, AC 5, V9, V10): the player's body from data.
const PLAYER_DATA_PATH := "res://data/characters/player.json"
const PLAYER_SCRIPT := "res://scripts/player/player.gd"
const PLAYER_BODY_PATH := "res://assets/characters/custom/g1_player_real.glb"
const PLAYER_FALLBACK_PATH := "res://assets/characters/models/kaykit_adventurers/Rogue.glb"
const PLAYER_MISSING_FIXTURE := "res://test/fixtures/player_missing_body.json"
const PLAYER_RUN_GROUND_SPEED := 6.996     # Running_A's ground speed on his body (real_player.rate(), m/s): V9's measure
const PLAYER_SPEED := 5.0                  # the gameplay speed (V9: unchanged)
## Test 25 (Story 25.23): the hall's light and mood, the day phases, the fireplace's floor rune.
const TAVERN_LIGHTING_SCRIPT := "res://scripts/game/tavern_lighting.gd"
const RUNE_CUE_SCENE := "res://scenes/game/FloorRuneCue.tscn"
const RUNE_CUE_SCRIPT := "res://scripts/game/floor_rune_cue.gd"
const CAMERA_SCRIPT := "res://scripts/camera/camera_3d.gd"
const BEDROOM_SCRIPT := "res://scenes/bedroom_popup.gd"
const BRIEFING_SCRIPT := "res://scenes/ui/script/morning_briefing.gd"
const INK_LAYER_MASK := 524288             # render layer 20: the EdgeQuad's alone (LM-3)
const TAVERN_ENV := "SubViewportContainer/SubViewport/TavernNavigation/Environment/"
const TAVERN_EDGE_QUAD := "SubViewportContainer/SubViewport/TavernNavigation/Camera3D/MeshInstance3D"
const LM_PHASES := ["morning", "day", "dusk", "evening", "late_night", "dawn"]
## The hall's light as saved on 2026-10-04 (the story's table): "today" is this, snapshotted at _ready (LM-2).
const LM_SUN_XF := Transform3D(Basis(Vector3(0.766044, 0, 0.642788), Vector3(0.45452, 0.707107, -0.541675), Vector3(-0.45452, 0.707107, 0.541675)), Vector3(9, 3, 8.01709))
const PORTRAIT_DIR := "res://assets/characters/portraits/npc/"          # Story 25.17
const PORTRAIT_STUDIO_SCENE := "res://scenes/dev/PortraitStudio.tscn"
const PORTRAIT_STUDIO_SCRIPT := "res://scripts/dev/portrait_studio.gd"
const PORTRAITS_RENDERED := ["den_fa", "quest_dealer", "bartender"]      # DP-2: the cast with a body
const PORTRAITS_PLANNED := {"elder": "Story 25.11", "bard": "Story 25.12"}   # no body yet: plate, path allowlisted
const PORTRAIT_SIZE := 512
const DEN_FA_TITLES :=["first_contact", "early_1", "early_2", "early_3"]
const BRIDGE_VALUES := ["reputation", "reputation_tier", "reputation_tier_index", "day", "roster_size", "adventurers_hired",
	"deaths_this_run", "gold", "is_demo"]
const GM_DIALOGUE_FIELDS := ["tavern_reputation", "current_day", "gold", "adventurers", "adventurers_hired_this_run",
	"deaths_this_run", "dialogue_flags", "game_over_active", "den_fa_state", "_den_fa_tier_warnings"]
## Test 21 (Story 10.3): the GameManager fields it sets, restored at its end.
const GM_DEN_FA_FIELDS := ["tavern_reputation", "current_day", "gold", "adventurers", "adventurers_hired_this_run",
	"deaths_this_run", "dialogue_flags", "game_over_active", "den_fa_state", "_den_fa_tier_warnings"]
const DEN_FA_STATE_ORDER := ["early", "mid", "late"]
const DEBUG_PANEL_SCRIPT := "res://scenes/ui/debug_panel.gd"
## Test 21's fixture (Story 10.3 review): Den Fa's entry title without its own mark_seen line.
const DIALOGUE_UNMARKED_ENTER_FIXTURE := "res://test/fixtures/dialogue_unmarked_enter.txt"
## Keys the box takes besides interact/ui_accept/ui_cancel/jump (review patch: Tab toggles the roster).
const BOX_ACTIONS_EXTRA := ["ui_focus_next", "ui_focus_prev"]
## Test 20's fixture files for Den Fa's E path: a file that doesn't compile, and one whose first contact says nothing.
const DIALOGUE_BROKEN_FIXTURE := "res://test/fixtures/dialogue_broken.txt"
const DIALOGUE_SILENT_FIXTURE := "res://test/fixtures/dialogue_silent_first_contact.txt"
## Test 20's inline fixture (S4): a reply whose condition fails, and a [#required] choice Esc can't skip.
const DIALOGUE_FIXTURE := "~ start\nFixture: Pick one. [#required]\n- Allow\n\tFixture: Allowed.\n- Hidden [if false]\n\tFixture: Never.\n- Refuse\n\tFixture: Refused.\nFixture: After.\n=> END\n"

var _pass_count := 0
var _fail_count := 0
var _elapsed := 0.0
var _t19_ms := 0          # Test 19's start (Time.get_ticks_msec), printed with its real time at the end (AC 8)
var _t20_ms := 0          # Test 20's start, printed with its real time (Story 10.2 AC 9: ≤ 10 s)


func _initialize() -> void:
	print("\n========== FAILSAFE TESTS ==========\n")

	test_save_load_round_trip()
	test_loot_rng_distribution()
	test_mission_success_formula()
	test_adventurer_status_transitions()
	test_asset_path_integrity()
	test_ruin_reservation()
	test_tavern_shell()
	test_tavern_exterior()
	test_exterior_world()
	test_hourglass_pillar()
	test_hearth()
	test_round_bar()
	test_desk_and_board()

	await process_frame  # autoloads enter the tree after _initialize() yields
	test_mission_payout_report()
	test_class_roster()
	test_townsfolk_kit()
	test_the_cat()
	await test_the_cat_yields()
	test_den_fa()
	await test_den_fa_e()
	test_staff()
	await test_staff_tavern()
	await test_staff_runtime()
	await test_front_door_edges()
	await test_doorway_path()
	print("[Test 10] The pillar's glow_energy at runtime")
	_check_pillar_glow_setter()
	print("
[Test 11] The hearth before its _ready")
	_check_hearth_early_calls()
	print("")
	await test_fire_resume()
	await test_tankard_upright()
	await test_townsfolk_runtime()
	await test_notice_board_live()
	await test_staff_review_fixes()
	await test_dialogue()
	await test_den_fa_states()
	test_dialogue_portraits()
	test_anime_look_presets()
	await test_player_body()
	await test_light_and_mood()

	_finish()


## Prints the summary and quits with exit code 1 on any failure (or a watchdog abort), so a script
## or CI run can't read a red suite as green.
func _finish(aborted := false) -> void:
	print("\n====================================")
	print("PASSED: %d  |  FAILED: %d" % [_pass_count, _fail_count])
	if aborted:
		print("*** ABORTED BY THE WATCHDOG: the counts above are partial ***")
	elif _fail_count > 0:
		print("*** SOME TESTS FAILED ***")
	else:
		print("All tests passed.")
	print("====================================\n")
	quit(1 if aborted or _fail_count > 0 else 0)


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > WATCHDOG_SECONDS:
		print("*** WATCHDOG: suite did not finish within %d s — aborting ***" % int(WATCHDOG_SECONDS))
		_finish(true)
		return true
	return false


func check(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS: %s" % label)
	else:
		_fail_count += 1
		print("  FAIL: %s" % label)


# --- Mirror of GameManager.roll_loot() for isolated testing ---
static func _roll_loot() -> String:
	var roll = randf()
	if roll < 0.05:
		return "artifact"
	elif roll < 0.25:
		return "equipment"
	else:
		return "gold"


# --- Mirror of GameManager.calculate_mission_success_chance() core formula ---
static func _calc_mission_chance(adventurer: Dictionary, mission: Dictionary) -> int:
	var base_chance = 50
	var success_factors = mission.get("success_factors", ["strength"])
	var stat_bonus = 0
	for factor in success_factors:
		match factor:
			"strength": stat_bonus += adventurer.get("strength", 0) * 3
			"dexterity": stat_bonus += adventurer.get("dexterity", 0) * 3
			"intelligence": stat_bonus += adventurer.get("intelligence", 0) * 3
			"endurance": stat_bonus += adventurer.get("endurance", 0) * 2
	var experience_bonus = adventurer.get("missions_completed", 0) * 2
	var danger_penalty = mission.get("danger", 1) * 8
	var final_chance = base_chance + stat_bonus + experience_bonus - danger_penalty
	return clampi(final_chance, 10, 95)


# --- Test 1: Save/Load Round-Trip ---
func test_save_load_round_trip() -> void:
	print("[Test 1] Save/Load Round-Trip")
	var test_data := {
		"current_day": 5,
		"gold": 1234,
		"beer_stock": 3,
		"adventurers": [{"name": "TestHero", "class": "Fighter"}],
		"flag": true,
		"ratio": 0.75,
		"nested": {"a": 1, "b": [2, 3]},
		"schema_version": 1,
	}

	var json_string = JSON.stringify(test_data, "\t")
	var json = JSON.new()
	var err = json.parse(json_string)
	check(err == OK, "JSON parse succeeds")

	var parsed: Dictionary = json.data
	check(int(parsed["current_day"]) == 5, "current_day == 5")
	check(int(parsed["gold"]) == 1234, "gold == 1234")
	check(int(parsed["beer_stock"]) == 3, "beer_stock == 3")
	check(parsed["flag"] == true, "flag is true")
	check(absf(parsed["ratio"] - 0.75) < 0.001, "ratio ~= 0.75")
	check(int(parsed["schema_version"]) == 1, "schema_version == 1")
	check(parsed["nested"] is Dictionary, "nested is Dictionary")
	check(parsed["adventurers"] is Array, "adventurers is Array")
	check((parsed["adventurers"] as Array).size() == 1, "adventurers has 1 entry")
	print("")


# --- Test 2: Loot RNG Distribution ---
func test_loot_rng_distribution() -> void:
	print("[Test 2] Loot RNG Distribution")
	var counts := {"gold": 0, "equipment": 0, "artifact": 0}
	var total := 1000

	for i in total:
		var result = _roll_loot()
		if counts.has(result):
			counts[result] += 1
		else:
			check(false, "roll_loot returned unknown category: %s" % result)

	var sum = counts["gold"] + counts["equipment"] + counts["artifact"]
	check(sum == total, "all %d rolls accounted for" % total)
	check(counts["gold"] >= 600 and counts["gold"] <= 850, "gold in [600, 850]: %d" % counts["gold"])
	check(counts["equipment"] >= 100 and counts["equipment"] <= 350, "equipment in [100, 350]: %d" % counts["equipment"])
	check(counts["artifact"] >= 5 and counts["artifact"] <= 120, "artifact in [5, 120]: %d" % counts["artifact"])
	print("")


# --- Test 3: Mission Success Formula ---
func test_mission_success_formula() -> void:
	print("[Test 3] Mission Success Formula (core formula, no trait modifiers)")

	var zero_adv := {"strength": 0, "dexterity": 0, "intelligence": 0, "endurance": 0, "missions_completed": 0}
	var zero_mission := {"success_factors": ["strength"], "danger": 0}
	var result_zero = _calc_mission_chance(zero_adv, zero_mission)
	check(result_zero == 50, "zero stats / zero danger => 50: got %d" % result_zero)

	var high_adv := {"strength": 10, "dexterity": 10, "intelligence": 10, "endurance": 10, "missions_completed": 20}
	var easy_mission := {"success_factors": ["strength", "dexterity"], "danger": 1}
	var result_high = _calc_mission_chance(high_adv, easy_mission)
	check(result_high == 95, "high stats / easy => capped 95: got %d" % result_high)

	var low_adv := {"strength": 1, "dexterity": 1, "intelligence": 1, "endurance": 1, "missions_completed": 0}
	var hard_mission := {"success_factors": ["strength"], "danger": 8}
	var result_low = _calc_mission_chance(low_adv, hard_mission)
	check(result_low == 10, "low stats / hard => capped 10: got %d" % result_low)
	print("")


# --- Test 4: AdventurerStatus Transitions ---
func test_adventurer_status_transitions() -> void:
	print("[Test 4] AdventurerStatus Transitions")

	check(AdventurerStatus.can_transition(AdventurerStatus.Status.READY, AdventurerStatus.Status.ON_MISSION), "READY -> ON_MISSION allowed")
	check(AdventurerStatus.can_transition(AdventurerStatus.Status.ON_MISSION, AdventurerStatus.Status.RESTING), "ON_MISSION -> RESTING allowed")
	check(AdventurerStatus.can_transition(AdventurerStatus.Status.ON_MISSION, AdventurerStatus.Status.DEAD), "ON_MISSION -> DEAD allowed")
	check(AdventurerStatus.can_transition(AdventurerStatus.Status.RESTING, AdventurerStatus.Status.READY), "RESTING -> READY allowed")
	check(AdventurerStatus.can_transition(AdventurerStatus.Status.WOUNDED, AdventurerStatus.Status.RESTING), "WOUNDED -> RESTING allowed")
	check(AdventurerStatus.can_transition(AdventurerStatus.Status.WOUNDED, AdventurerStatus.Status.DEAD), "WOUNDED -> DEAD allowed")

	check(not AdventurerStatus.can_transition(AdventurerStatus.Status.DEAD, AdventurerStatus.Status.READY), "DEAD -> READY blocked")
	check(not AdventurerStatus.can_transition(AdventurerStatus.Status.DEAD, AdventurerStatus.Status.RESTING), "DEAD -> RESTING blocked")
	check(AdventurerStatus.is_terminal(AdventurerStatus.Status.DEAD), "DEAD is terminal")
	check(not AdventurerStatus.is_terminal(AdventurerStatus.Status.READY), "READY is not terminal")
	print("")


# --- Test 5: Asset-Path Integrity (Epic 25 / Story 25.1) ---
# Every res:// string in data/**/*.json must exist on disk, unless allowlisted with a
# reason and an owner. Exact-path and invalid-JSON entries are stale-guarded: once the
# gap is fixed the test fails until the owning story removes its allowlist entry.
func test_asset_path_integrity() -> void:
	print("[Test 5] Asset-Path Integrity (data/*.json -> files on disk)")

	var allow = _read_json(ASSET_ALLOWLIST_PATH)
	var allow_ok: bool = allow is Dictionary and int(allow.get("schema_version", 0)) == 1
	check(allow_ok, "allowlist parses, schema_version == 1")
	if not allow_ok:
		print("")
		return

	var missing_paths: Array = allow.get("missing_paths", [])
	var missing_prefixes: Array = allow.get("missing_prefixes", [])
	var known_invalid: Array = allow.get("known_invalid_json", [])
	var allow_entries: Array = missing_paths + missing_prefixes + known_invalid
	var documented := allow_entries.all(func(e): return str(e.get("reason", "")) != "" and str(e.get("owner", "")) != "")
	check(documented, "every allowlist entry has a reason and an owner (%d entries)" % allow_entries.size())

	var exact_missing: Array = missing_paths.map(func(e): return str(e.get("path", "")))
	var prefixes: Array = missing_prefixes.map(func(e): return str(e.get("prefix", "")))
	var invalid_files: Array = known_invalid.map(func(e): return str(e.get("file", "")))

	var json_files: Array[String] = []
	_collect_json_files("res://data", json_files)
	var refs: Array[String] = []
	var parse_failures: Array[String] = []
	for file_path in json_files:
		var parsed = _read_json(file_path)
		if parsed == null:
			parse_failures.append(file_path)
		else:
			_collect_res_strings(parsed, refs)

	var unexpected_invalid: Array = parse_failures.filter(func(p): return not invalid_files.has(p))
	check(json_files.size() > 0 and unexpected_invalid.is_empty(),
		"%d data JSON files parse or are known-invalid; unexpected parse failures: %s" % [json_files.size(), unexpected_invalid])
	for invalid_file in invalid_files:
		check(parse_failures.has(invalid_file), "known-invalid JSON still fails to parse (else remove it from the allowlist): %s" % invalid_file)

	var found := 0
	var allowlisted := 0
	var unexpected_missing: Array[String] = []
	for ref in refs:
		if _res_exists(ref):
			found += 1
		elif exact_missing.has(ref) or prefixes.any(func(pre): return ref.begins_with(pre)):
			allowlisted += 1
		else:
			unexpected_missing.append(ref)
	check(unexpected_missing.is_empty(), "%d res:// refs: %d found, %d allowlisted, %d missing %s" % [
		refs.size(), found, allowlisted, unexpected_missing.size(), unexpected_missing.slice(0, 5)])
	for path in exact_missing:
		check(not _res_exists(path), "allowlisted path still missing (else remove it from the allowlist): %s" % path)
	print("")


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data


static func _collect_json_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect_json_files(dir_path.path_join(sub), out)
	for file_name in dir.get_files():
		if file_name.get_extension() == "json":
			out.append(dir_path.path_join(file_name))


static func _collect_res_strings(value: Variant, out: Array[String]) -> void:
	if value is Dictionary:
		for v in value.values():
			_collect_res_strings(v, out)
	elif value is Array:
		for v in value:
			_collect_res_strings(v, out)
	elif value is String and value.begins_with("res://"):
		out.append(value)


static func _res_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


# --- Test 6: Ruin Reservation, Mission Exclusion, World-Gen Drift Guard (Story 25.2) ---
# One land hex next to the tavern becomes the Prior Ruins (Story 6.2), picked from the seed
# without drawing from the RNG, so every other hex must match the pre-change baseline fixture.
func test_ruin_reservation() -> void:
	print("[Test 6] Ruin reservation + mission exclusion + world-gen drift guard")
	var gen_script = load("res://scripts/world/HexMapGenerator.gd")
	var wm_script = load("res://systems/WorldManager.gd")
	check(gen_script != null and wm_script != null, "HexMapGenerator.gd and WorldManager.gd load")
	if gen_script == null or wm_script == null:
		print("")
		return
	check(ResourceLoader.exists(RUIN_TOPPER_PATH), "D1 topper exists: %s" % RUIN_TOPPER_PATH)
	var has_eligible: bool = wm_script.get_script_method_list().any(func(m): return m.name == "is_mission_eligible")
	check(has_eligible, "WorldManager.is_mission_eligible() exists")

	var centre: Vector2i = gen_script.get_script_constant_map().get("CENTER_COORD", Vector2i.ZERO)
	for seed_value in [1, 12345, 987654]:
		var gen = gen_script.new()
		var recs := _generate_world(gen, seed_value)
		var ruins := recs.filter(func(r): return r.get("is_ruin", false))
		check(ruins.size() == 1, "seed %d: exactly one ruin hex (got %d)" % [seed_value, ruins.size()])
		if ruins.size() == 1:
			var ruin: Dictionary = ruins[0]
			check(gen._hex_distance(ruin.coord, centre) == 1 and ruin.biome != "sea" and not ruin.is_zone,
				"seed %d: ruin %s is a land hex next to the tavern (biome %s)" % [seed_value, ruin.id, ruin.biome])
			check(ruin.topper_paths == [RUIN_TOPPER_PATH] and ruin.get("ruin_discovered", true) == false,
				"seed %d: ruin uses the D1 topper and starts undiscovered" % seed_value)
			var again := _generate_world(gen, seed_value)
			var again_ruins := again.filter(func(r): return r.get("is_ruin", false))
			check(again_ruins.size() == 1 and again_ruins[0].id == ruin.id, "seed %d: same seed -> same ruin hex" % seed_value)
			if has_eligible:
				var land_neighbour = null
				var sea_hex = null
				for r in recs:
					if sea_hex == null and r.biome == "sea":
						sea_hex = r
					if land_neighbour == null and not r.get("is_ruin", false) and not r.is_center and not r.is_zone \
							and r.biome != "sea" and gen._hex_distance(r.coord, centre) == 1:
						land_neighbour = r
				check(not wm_script.is_mission_eligible(ruin), "seed %d: ruin hex is not mission-eligible" % seed_value)
				check(land_neighbour == null or wm_script.is_mission_eligible(land_neighbour),
					"seed %d: an ordinary land hex next to the tavern stays eligible" % seed_value)
				check(sea_hex == null or not wm_script.is_mission_eligible(sea_hex), "seed %d: sea stays ineligible" % seed_value)
		if seed_value == 12345:
			_check_worldgen_drift(recs)
		gen.free()
	_check_ruin_save_load(gen_script, wm_script, centre)
	print("")


# Review 2026-10-03: the ruin keys survive a save (through JSON, as SaveSystem writes it), and a save
# made before Story 25.2 gets its ruin on load by the generator's own rule (no RNG draw), skipping
# zones, the centre, locked hexes and hexes with an active mission.
func _check_ruin_save_load(gen_script, wm_script, centre: Vector2i) -> void:
	var has_rule: bool = gen_script.get_script_method_list().any(func(m): return m.name == "pick_ruin_hex")
	check(has_rule, "HexMapGenerator.pick_ruin_hex() exists (one ruin rule for generation and old saves)")
	var gen = gen_script.new()
	var recs := _generate_world(gen, 12345)
	gen.free()
	var centre_recs := recs.filter(func(r): return r.is_center)
	var ruin_recs := recs.filter(func(r): return r.get("is_ruin", false))
	if centre_recs.size() != 1 or ruin_recs.size() != 1:
		check(false, "seed 12345 world has one centre and one ruin for the save checks")
		return
	var wm = wm_script.new()
	wm.set_generated_world(recs, centre_recs[0])
	var wm2 = wm_script.new()
	wm2.load_save_data(JSON.parse_string(JSON.stringify(wm.get_save_data())))
	var back: Array = wm2.world_map.filter(func(r): return r.get("is_ruin", false))
	check(back.size() == 1 and back[0].id == ruin_recs[0].id and back[0].get("ruin_discovered", true) == false
		and back[0].topper_paths == [RUIN_TOPPER_PATH],
		"save/load round-trip keeps the ruin hex, ruin_discovered = false and the D1 topper %s" % [back.map(func(r): return r.id)])

	# A save from before 25.2: no ruin keys. Block every land hex next to the tavern but one
	# (one with an active mission, the rest locked); the reserved ruin must be the free one.
	var old: Dictionary = JSON.parse_string(JSON.stringify(wm.get_save_data()))
	var land: Array = []
	for r in old.world_map:
		r.erase("is_ruin")
		r.erase("ruin_discovered")
		if r.id == ruin_recs[0].id:
			r.topper_paths = []
		var c := Vector2i(int(r.coord[0]), int(r.coord[1]))
		if gen_script._hex_distance(c, centre) == 1 and not r.is_zone \
				and r.biome in ["grass", "forest", "mountain", "coast"]:
			land.append(r)
	check(land.size() >= 3, "seed 12345: %d land hexes next to the tavern (the old-save check needs 3+)" % land.size())
	if land.size() >= 3:
		var free_id: String = land[-1].id
		land[0]["active_mission"] = {"name": "Old Contract"}
		for i in range(1, land.size() - 1):
			land[i]["locked"] = true
		var picks := []
		for i in 2:
			var wm3 = wm_script.new()
			wm3.load_save_data(JSON.parse_string(JSON.stringify(old)))
			var got: Array = wm3.world_map.filter(func(r): return r.get("is_ruin", false))
			picks.append(got.map(func(r): return [r.id, r.get("ruin_discovered", true), r.topper_paths]))
			wm3.free()
		check(picks[0] == [[free_id, false, [RUIN_TOPPER_PATH]]],
			"old save: one ruin reserved on load, on the free land hex %s (not locked, no mission): %s" % [free_id, picks[0]])
		check(picks[0] == picks[1], "old save: the reserved ruin is deterministic (same hex on every load)")
	wm.free()
	wm2.free()


func _generate_world(gen: Node, seed_value: int) -> Array:
	gen.randomize_seed_on_generate = false
	gen.map_seed = seed_value
	gen._generate_records()
	return gen._records.duplicate(true)


# Every record must match the baseline fixture captured before Story 25.2 changed the
# generator; the ruin hex (25.2) and the tavern hex (25.8) may differ only in their toppers.
func _check_worldgen_drift(recs: Array) -> void:
	var fixture = _read_json(WORLDGEN_FIXTURE_PATH)
	if not fixture is Dictionary:
		check(false, "world-gen fixture readable: %s" % WORLDGEN_FIXTURE_PATH)
		return
	var expected: Dictionary = fixture.get("records", {})
	var mismatches: Array = []
	for rec in recs:
		var row = expected.get(rec.id)
		if row == null:
			mismatches.append(rec.id + " (missing from fixture)")
			continue
		var actual := [rec.biome, rec.base_path, rec.topper_paths, rec.is_zone, rec.get("zone_building", "")]
		if rec.get("is_ruin", false) or rec.get("is_center", false):
			actual[2] = row[2]   # the ruin's and the tavern hex's toppers are the intended changes
		if actual != row:
			mismatches.append(rec.id)
	check(recs.size() == int(fixture.get("record_count", -1)) and mismatches.is_empty(),
		"seed 12345: %d records match the pre-change baseline; mismatches: %s" % [recs.size(), mismatches.slice(0, 5)])
	var centre := recs.filter(func(r): return r.get("is_center", false))
	check(centre.size() == 1 and centre[0].topper_paths == [A2_PATH, C9_PATH],
		"seed 12345: the tavern hex carries the A2 miniature + C9 home marker (%s)" % [centre[0].topper_paths if centre.size() == 1 else "no centre"])


# --- Test 7: Tavern Shell (Story 25.3) ---
# Reads MainTavern.tscn through SceneState (no instancing, so no gameplay scripts run):
# the seven original architecture colliders must be unchanged (the navmesh is baked from
# static colliders), the new shell colliders must exist where the story puts them, and the
# B9/B10 kit files must exist.
func test_tavern_shell() -> void:
	print("[Test 7] Tavern shell: kit files, original colliders unchanged, new colliders placed")
	for id in SHELL_KIT:
		check(ResourceLoader.exists("res://assets/environment/custom/%s.gltf" % id), "kit piece exists: %s" % id)

	var aabbs := _scene_box_collider_aabbs(TAVERN_SCENE_PATH)
	var fixture = _read_json(TAVERN_COLLIDERS_FIXTURE)
	if not fixture is Dictionary:
		check(false, "tavern collider fixture readable")
		print("")
		return
	var expected = fixture.get("colliders", {})
	check(expected is Dictionary and expected.size() == 7, "collider fixture lists the seven original colliders (%d)" % [expected.size() if expected is Dictionary else -1])
	if not expected is Dictionary:
		expected = {}
	for name in expected:
		var key: String = ARCH_PATH + name + "/StaticBody3D/CollisionShape3D"
		check(aabbs.has(key) and _aabb_close(aabbs[key], expected[name]),
			"original collider unchanged: %s %s" % [name, aabbs.get(key, "MISSING")])
	for rel in SHELL_NEW_COLLIDERS:
		var key: String = ARCH_PATH + rel
		check(aabbs.has(key) and _aabb_close(aabbs[key], SHELL_NEW_COLLIDERS[rel]),
			"new shell collider in place: %s %s" % [rel.get_slice("/", 2), aabbs.get(key, "MISSING")])

	# Review 2026-10-03: the doorway joins the hall and the porch on the navmesh.
	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var nav := _tavern_navmesh()
	var th = tav.get(ARCH_PATH + DOOR_THRESHOLD)
	var body = tav.get((ARCH_PATH + DOOR_THRESHOLD).get_base_dir())
	var pts := PackedVector3Array()
	if th != null and th.props.get("shape") is ConvexPolygonShape3D:
		for q in (th.props.shape as ConvexPolygonShape3D).points:
			pts.append((th.world as Transform3D) * q)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for q in pts:
		lo = lo.min(q)
		hi = hi.max(q)
	var layer: int = int(body.props.get("collision_layer", 1)) if body != null else 0
	check(pts.size() >= 6 and body != null and body.type == "StaticBody3D"
		and absf(lo.x - DOORWAY_X[0]) < 0.01 and absf(hi.x - DOORWAY_X[1]) < 0.01
		and absf(hi.y - HALL_FLOOR_TOP) < 0.005 and absf(lo.y - PORCH_FLOOR_TOP) < 0.005
		and lo.z < 4.43 and hi.z > 4.72 and nav != null and (layer & nav.geometry_collision_mask) != 0,
		"DoorThreshold: a static wedge across the doorway x %s, from the hall floor's top (y %.2f) to the porch's (y %.2f), z %.2f..%.2f, on a layer the bake reads (%d)"
			% [DOORWAY_X, hi.y, lo.y, lo.z, hi.z, layer])
	check(not tav.keys().any(func(k): return str(k).begins_with(ARCH_PATH + "Shell/NearWalls/DoorThreshold/") and tav[k].type == "MeshInstance3D"),
		"DoorThreshold draws nothing (collider only)")
	if nav == null:
		check(false, "MainTavern's TavernNavigation has a navigation mesh")
		print("")
		return
	var door_polys := _nav_polys_at(nav, DOOR_CENTER.x, DOOR_CENTER.z).filter(func(i): return _nav_poly_top(nav, i) < 1.0)
	check(not door_polys.is_empty(), "navmesh: the doorway (%.1f, %.2f) is on the mesh at floor height" % [DOOR_CENTER.x, DOOR_CENTER.z])
	var comp := _nav_components(nav)
	var hall_polys := _nav_polys_at(nav, HALL_NAV_POINT.x, HALL_NAV_POINT.z)
	var porch_polys := _nav_polys_at(nav, PORCH_NAV_POINT.x, PORCH_NAV_POINT.z)
	var hall_piece: int = comp[hall_polys[0]] if hall_polys.size() == 1 else -2
	check(hall_piece >= 0 and porch_polys.size() == 1 and not door_polys.is_empty()
		and comp[porch_polys[0]] == hall_piece and comp[door_polys[0]] == hall_piece,
		"navmesh: the hall %s and the porch %s connect through the doorway (shared polygon edges)" % [HALL_NAV_POINT, PORCH_NAV_POINT])
	var cut_off := 0
	for i in comp.size():
		if comp[i] != hall_piece:
			cut_off += 1
	check(hall_piece >= 0 and cut_off == 0, "navmesh: every polygon connects to the hall, no islands (%d of %d cut off)" % [cut_off, comp.size()])
	print("")


## Test 7, runtime part (review 2026-10-03): a NavigationServer3D map holding MainTavern's baked mesh finds a
## path porch -> hall and hall -> porch, through the front doorway (it crosses the wall line between the gap colliders).
func test_doorway_path() -> void:
	print("[Test 7] Doorway: NavigationServer3D paths porch -> hall -> porch")
	var nav := _tavern_navmesh()
	if nav == null:
		check(false, "MainTavern's TavernNavigation has a navigation mesh")
		print("")
		return
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, nav.cell_size)
	NavigationServer3D.map_set_cell_height(map, nav.cell_height)
	NavigationServer3D.map_set_active(map, true)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, nav)
	for i in 30:
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			break
		await process_frame
	check(NavigationServer3D.map_get_iteration_id(map) > 0, "the navigation map synced")
	for leg in [[PORCH_NAV_POINT, HALL_NAV_POINT, "porch -> hall"], [HALL_NAV_POINT, PORCH_NAV_POINT, "hall -> porch"]]:
		var from: Vector3 = leg[0]
		var to: Vector3 = leg[1]
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		var cross := INF
		for i in range(1, path.size()):
			var a := path[i - 1]
			var b := path[i]
			if (a.z - DOOR_CENTER.z) * (b.z - DOOR_CENTER.z) <= 0.0 and a.z != b.z:
				cross = lerpf(a.x, b.x, (DOOR_CENTER.z - a.z) / (b.z - a.z))
		var ends_ok := path.size() >= 2 and Vector2(path[0].x - from.x, path[0].z - from.z).length() < 0.3 \
			and Vector2(path[-1].x - to.x, path[-1].z - to.z).length() < 0.3
		check(ends_ok and cross > DOORWAY_X[0] and cross < DOORWAY_X[1],
			"%s: a path from start to goal, through the doorway (crosses z %.2f at x %.2f; %d points)" % [leg[2], DOOR_CENTER.z, cross, path.size()])
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	print("")


## Test 7, runtime part (review 2026-10-03; runs at the end, it needs frames): close_delay 0 closes at
## once (Timer.start(0) used to fall back to the timer's 1 s wait_time), and a walker without a body
## freed while holding the door (no release_hold, no body ever in the trigger) no longer holds it forever.
func test_front_door_edges() -> void:
	print("[Test 7] Front door edges: close_delay 0, a holder freed without letting go")
	var world := Node3D.new()
	root.add_child(world)
	var door := _make_door()
	world.add_child(door)
	door.global_position = DOOR_CENTER + Vector3(0, -50, 0)   # out of every other test's way
	await process_frame
	var holder := Node.new()
	door.close_delay = 0.0
	door.hold_open(holder)
	var t0 := Time.get_ticks_msec()
	door.release_hold(holder)
	while door._is_open and Time.get_ticks_msec() - t0 < 2000:
		await process_frame
	var took := Time.get_ticks_msec() - t0
	check(not door._is_open and took < 300, "close_delay 0: the door closes at once on the last release (%d ms)" % took)
	door.close_delay = 0.2
	door.hold_open(holder)
	holder.free()
	t0 = Time.get_ticks_msec()
	while door._is_open and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	check(not door._is_open, "a holder freed without release_hold lets the door close (%d ms)" % (Time.get_ticks_msec() - t0))
	world.queue_free()
	await process_frame
	print("")


## World-space AABB ([x, y, z] ranges) of every BoxShape3D CollisionShape3D in a scene file,
## computed from SceneState transforms without instancing the scene.
static func _scene_box_collider_aabbs(scene_path: String) -> Dictionary:
	var state: SceneState = (load(scene_path) as PackedScene).get_state()
	var local := {}    # node path -> Transform3D
	var parents := {}  # node path -> parent path
	var shapes := {}   # node path -> BoxShape3D
	for i in state.get_node_count():
		var path := str(state.get_node_path(i)).trim_prefix("./")
		parents[path] = str(state.get_node_path(i, true)).trim_prefix("./")
		var tf := Transform3D.IDENTITY
		for p in state.get_node_property_count(i):
			var prop := state.get_node_property_name(i, p)
			if prop == "transform":
				tf = state.get_node_property_value(i, p)
			elif prop == "shape" and state.get_node_property_value(i, p) is BoxShape3D:
				shapes[path] = state.get_node_property_value(i, p)
		local[path] = tf
	var out := {}
	for path in shapes:
		var world := Transform3D.IDENTITY
		var cur: String = path
		while cur != "" and cur != "." and local.has(cur):
			world = local[cur] * world
			cur = parents[cur]
		var half: Vector3 = shapes[path].size * 0.5
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				for sz in [-1, 1]:
					var pt: Vector3 = world * Vector3(sx * half.x, sy * half.y, sz * half.z)
					lo = lo.min(pt)
					hi = hi.max(pt)
		out[path] = [[lo.x, hi.x], [lo.y, hi.y], [lo.z, hi.z]]
	return out


static func _aabb_close(a: Array, b: Array, tol := 0.011) -> bool:
	for axis in 3:
		for end in 2:
			if absf(float(a[axis][end]) - float(b[axis][end])) > tol:
				return false
	return true


# --- Test 8: Guild Tavern exterior + map miniature (Story 25.8) ---
# Map: the tavern hex carries A2 + C9, also for old saves (display mode). Exterior (SceneState only,
# nothing instanced): A1 replaces the stock tavern, the entrance zone and the "Press E" label sit at
# A1's door, the player arriving from the tavern lands in front of the door (outside the zone and
# outside A1's collision), and the exterior camera has the ink-outline quad (decision D2).
func test_tavern_exterior() -> void:
	print("[Test 8] Guild Tavern exterior (A1), map miniature (A2), home marker (C9)")
	for p in [A1_PATH, A2_PATH, C9_PATH]:
		check(ResourceLoader.exists(p), "asset exists: %s" % p.get_file())

	var gen_script = load("res://scripts/world/HexMapGenerator.gd")
	var consts: Dictionary = gen_script.get_script_constant_map() if gen_script else {}
	check(consts.get("TAVERN_TOPPER") == A2_PATH and consts.get("HOME_MARKER") == C9_PATH,
		"HexMapGenerator: TAVERN_TOPPER = A2, HOME_MARKER = C9")
	var has_helper: bool = gen_script != null and gen_script.get_script_method_list().any(
		func(m): return m.name == "home_toppers_for")
	check(has_helper, "HexMapGenerator.home_toppers_for() exists")
	if has_helper:
		var old_save := {"is_center": true, "topper_paths": [OLD_TAVERN_PATH]}
		var other := {"is_center": false, "topper_paths": ["res://assets/x.gltf"]}
		check(gen_script.home_toppers_for(old_save) == [A2_PATH, C9_PATH], "old save: the tavern hex renders A2 + C9")
		check(gen_script.home_toppers_for(other) == ["res://assets/x.gltf"], "old save: other hexes render what they stored")

	var ext := _scene_nodes(EXTERIOR_SCENE_PATH)
	check(not ext.values().any(func(n): return n.instance == OLD_TAVERN_PATH),
		"ExteriorWorld no longer instances building_tavern_blue")
	var a1_keys := ext.keys().filter(func(k): return ext[k].instance == A1_PATH)
	check(a1_keys.size() == 1, "ExteriorWorld instances A1 once %s" % [a1_keys])
	if a1_keys.size() != 1:
		print("")
		return
	var a1_xf: Transform3D = ext[a1_keys[0]].world
	var a1 := _scene_nodes(A1_PATH)
	var door := Vector3.INF
	var a1_boxes: Array = []   # world-space [[x0, x1], [z0, z1]] of A1's collision proxies
	for k in a1:
		if str(k).ends_with("interact_point"):
			door = a1_xf * (a1[k].world as Transform3D).origin
		var shape = a1[k].props.get("shape")
		if shape is ConvexPolygonShape3D:
			var lo := Vector3(INF, INF, INF)
			var hi := Vector3(-INF, -INF, -INF)
			for pt in (shape as ConvexPolygonShape3D).points:
				var w: Vector3 = a1_xf * ((a1[k].world as Transform3D) * pt)
				lo = lo.min(w)
				hi = hi.max(w)
			a1_boxes.append([[lo.x, hi.x], [lo.z, hi.z]])
	check(door != Vector3.INF, "A1 has its interact_point marker (door) %s" % [door])
	check(a1_boxes.size() >= 3, "A1 imports its collision proxies (%d convex shapes)" % a1_boxes.size())
	if door == Vector3.INF:
		print("")
		return

	var tavern := _scene_nodes(TAVERN_SCENE_PATH)
	var spawn = null
	for k in tavern:
		if str(k).ends_with("Interactive/ExitArea"):
			spawn = tavern[k].props.get("exterior_spawn_position")
	if spawn == null and ResourceLoader.exists(EXIT_ZONE_SCRIPT_PATH):
		spawn = load(EXIT_ZONE_SCRIPT_PATH).get_property_default_value("exterior_spawn_position")
	check(spawn is Vector3, "the tavern's ExitArea has an exterior spawn position (%s)" % [spawn])
	if not spawn is Vector3:
		print("")
		return
	var s2 := Vector2(spawn.x, spawn.z)
	var d2 := Vector2(door.x, door.z)
	check(s2.distance_to(d2) <= 3.0, "arrival spawn %s lands within 3 m of A1's door %s" % [spawn, door])
	check(not a1_boxes.any(func(b): return _circle_hits_rect(s2, PLAYER_RADIUS, b)),
		"arrival spawn is outside A1's collision")

	var zone_boxes := _scene_box_collider_aabbs(EXTERIOR_SCENE_PATH)
	var zone = zone_boxes.get("TavernEntranceZone/CollisionShape3D")
	check(zone != null, "TavernEntranceZone has a box shape")
	if zone != null:
		var zone_xz := [zone[0], zone[2]]
		check(_circle_hits_rect(d2, 0.6, zone_xz), "entrance zone sits at A1's door %s" % [zone_xz])
		check(not _circle_hits_rect(s2, PLAYER_RADIUS, zone_xz), "arriving player starts outside the entrance zone")

	var label = ext.get("TavernEntranceZone/InteractionPrompt")
	check(label != null and Vector2(label.world.origin.x, label.world.origin.z).distance_to(d2) <= 1.5,
		"'Press E' label floats at the door (D1) %s" % [label.world.origin if label else "missing"])
	# The full-screen ink quad (render_priority 0) repaints the screen from the opaque pass, so a
	# transparent Label3D must draw after it or it vanishes (seen in-scene, 2026-09-25).
	check(label != null and int(label.props.get("render_priority", 0)) > 0 and label.props.get("no_depth_test", false),
		"'Press E' label draws after the ink quad and through the wall")
	_check_entrance_prompt_toggle()
	var has_edge := ext.keys().any(func(k): return str(k).begins_with("Camera3D/") and \
		_is_edge_material(ext[k].props.get("surface_material_override/0")))
	check(has_edge, "exterior camera has the ink-outline quad (D2)")
	print("")


## Review 2026-10-03: the door's "Press E" label draws through walls and trees, so it may only show
## while the player stands in the entrance zone (the zone script syncs it; nothing enters the tree).
func _check_entrance_prompt_toggle() -> void:
	var zone := Area3D.new()
	zone.set_script(load(ENTRANCE_ZONE_SCRIPT_PATH))
	var label := Label3D.new()
	label.name = "InteractionPrompt"
	zone.add_child(label)
	var has_sync: bool = zone.has_method("_sync_prompt")
	check(has_sync, "entrance_zone_exterior.gd has _sync_prompt() (the label follows the zone)")
	if has_sync:
		var player := Node3D.new()
		player.name = "Player"
		var seen := []
		zone._sync_prompt()   # what _ready does
		seen.append(label.visible)
		zone._on_body_entered(player)
		seen.append(label.visible)
		zone._on_body_exited(player)
		seen.append(label.visible)
		check(seen == [false, true, false], "'Press E' label: hidden at start, shown in the zone, hidden on leaving %s" % [seen])
		player.free()
	zone.free()


## Every node of a scene file via SceneState (nothing instanced):
## path -> {world: Transform3D, instance: String, props: Dictionary}.
static func _scene_nodes(scene_path: String) -> Dictionary:
	var state: SceneState = (load(scene_path) as PackedScene).get_state()
	var nodes := {}
	var parents := {}
	for i in state.get_node_count():
		var path := str(state.get_node_path(i)).trim_prefix("./")
		parents[path] = str(state.get_node_path(i, true)).trim_prefix("./")
		var props := {}
		for p in state.get_node_property_count(i):
			props[state.get_node_property_name(i, p)] = state.get_node_property_value(i, p)
		var inst := state.get_node_instance(i)
		nodes[path] = {"local": props.get("transform", Transform3D.IDENTITY), "props": props,
			"instance": inst.resource_path if inst else "", "type": str(state.get_node_type(i)),
			"groups": Array(state.get_node_groups(i)).map(func(g): return str(g))}
	for path in nodes:
		var world := Transform3D.IDENTITY
		var cur: String = path
		while cur != "" and cur != "." and nodes.has(cur):
			world = nodes[cur].local * world
			cur = parents[cur]
		nodes[path]["world"] = world
	return nodes


static func _circle_hits_rect(c: Vector2, r: float, rect: Array) -> bool:
	var nearest := Vector2(clampf(c.x, rect[0][0], rect[0][1]), clampf(c.y, rect[1][0], rect[1][1]))
	return nearest.distance_to(c) < r


# --- Test 9: Exterior ground, forest and village (Story 25.29) ---
# The terrain is both the drawn and the walked ground (the old Ground box drew at y -0.11 but
# collided at +0.25, so everything floated). Every placed building, tree, rock and prop must sit on
# the terrain height (heightfield fixture exported with the terrain); trees stay off the path, the
# stream and the buildings; the bridge deck and the play-area bounds have collision.
func test_exterior_world() -> void:
	print("[Test 9] Exterior ground, forest and village")
	for p in [TERRAIN_PATH, BRIDGE_PATH]:
		check(ResourceLoader.exists(p), "asset exists: %s" % p.get_file())
	check(ResourceLoader.exists(TERRAIN_PATH) and _scene_has_shape(TERRAIN_PATH, "ConcavePolygonShape3D"),
		"terrain imports a trimesh collider")
	check(ResourceLoader.exists(BRIDGE_PATH) and _scene_has_shape(BRIDGE_PATH, "ConcavePolygonShape3D"),
		"bridge deck imports a trimesh collider")
	var hf = _read_json(HEIGHTFIELD_FIXTURE)
	if not hf is Dictionary:
		check(false, "heightfield fixture readable")
		print("")
		return
	var ext := _scene_nodes(EXTERIOR_SCENE_PATH)
	check(not ext.has("Ground"), "the old Ground box is gone")
	check(ext.values().any(func(n): return n.instance == TERRAIN_PATH), "ExteriorWorld instances the terrain")
	check(ext.values().any(func(n): return n.instance == BRIDGE_PATH), "ExteriorWorld instances the bridge")

	var floating := []
	var seated := 0
	var trees_bad := []
	var tree_count := 0
	var buildings := []
	# Keep-out footprints, world [[x0, x1], [z0, z1]] (review 2026-10-03; was a 2.5 m radius round each
	# building's origin): the village colliders, the Guild Tavern's (A1) collision proxies, the farm plots.
	var keep_out: Array = []
	var boxes := _scene_box_collider_aabbs(EXTERIOR_SCENE_PATH)
	for k in boxes:
		if str(k).begins_with("Village/") and str(k).contains("/Body/"):
			keep_out.append([boxes[k][0], boxes[k][2]])
	var village_boxes := keep_out.size()
	for k in ext:
		var key := str(k)
		if key.begins_with("Village/") and key.count("/") == 1 and ext[k].instance.contains("/blue/"):
			buildings.append((ext[k].world as Transform3D).origin)
		if ext[k].instance == A1_PATH:
			keep_out.append_array(_convex_rects(A1_PATH, ext[k].world))
		if key.begins_with("Props/FarmingPlot") and ext[k].props.get("mesh") is Mesh:
			var plot: AABB = (ext[k].world as Transform3D) * (ext[k].props.mesh as Mesh).get_aabb()
			keep_out.append([[plot.position.x, plot.end.x], [plot.position.z, plot.end.z]])
	check(village_boxes >= 7 and keep_out.size() >= village_boxes + 3 + 2,
		"keep-out footprints: %d village colliders, A1's proxies and the 2 farm plots (%d in all)" % [village_boxes, keep_out.size()])
	var stream_ok: bool = hf.get("stream") is Array and hf.stream.size() >= 2
	check(stream_ok, "heightfield fixture has a stream centre line")
	var square: Array = hf.get("square", [])
	for k in ext:
		var key := str(k)
		var n: Dictionary = ext[k]
		var grouped: bool = SEATED_GROUPS.any(func(g): return key.begins_with(g))
		var is_placed: bool = n.instance != "" or n.props.has("mesh")
		if not ((grouped and is_placed and key.count("/") <= 2) or key in SEATED_ROOT_NODES):
			continue
		var o: Vector3 = (n.world as Transform3D).origin
		var ground := _hf_height(hf, o.x, o.z)
		seated += 1
		# Floating is the bug (shadows detach); a little sinking is fine (the forest sits 0.05 in), but no
		# more than the AC's 0.12: three trees at the slope foot were 0.13-0.19 under (review 2026-10-03).
		if o.y - ground > 0.15 or ground - o.y > 0.12:
			floating.append("%s y=%.2f ground=%.2f" % [key, o.y, ground])
		if key.begins_with("Forest/"):
			tree_count += 1
			var o2 := Vector2(o.x, o.z)
			var on_path := _dist_to_polyline(o2, hf.path) < float(hf.path_half) + 0.3
			var in_stream := stream_ok and absf(o.x - _hf_stream_x(hf, o.z)) < float(hf.stream_half) + 0.3
			var in_footprint: bool = keep_out.any(func(b): return _circle_hits_rect(o2, 0.5, b))
			var in_square: bool = square.size() == 3 and o2.distance_to(Vector2(square[0], square[1])) < float(square[2])
			if on_path or in_stream or in_footprint or in_square:
				trees_bad.append(key)
	check(seated >= 50 and floating.is_empty(),
		"%d placed nodes sit on the terrain (≤ 0.15 m above, ≤ 0.12 m sunk); off: %s" % [seated, floating.slice(0, 4)])
	check(tree_count >= 100, "the forest has %d trees and rocks" % tree_count)
	check(trees_bad.is_empty(), "no tree or rock on the path, stream, square, a building, the tavern or a farm plot: %s" % [trees_bad.slice(0, 4)])
	check(buildings.size() >= 7, "the village has %d buildings" % buildings.size())
	# The walls must close the play rectangle (fixture "play": x0, x1, z0, z1) on all four sides and stand
	# taller than the player, not merely exist (review 2026-10-03).
	var play: Array = hf.get("play", [])
	var walls: Array = []
	for k in boxes:
		if str(k).begins_with("Bounds/"):
			walls.append(boxes[k])
	var open_sides := []
	if play.size() == 4:
		var sides := {"west": [Vector2(play[0], play[2]), Vector2(play[0], play[3])],
			"east": [Vector2(play[1], play[2]), Vector2(play[1], play[3])],
			"north": [Vector2(play[0], play[2]), Vector2(play[1], play[2])],
			"south": [Vector2(play[0], play[3]), Vector2(play[1], play[3])]}
		for side in sides:
			var closed := false
			for w in walls:
				var covers := float(w[1][1]) >= 2.0
				for p in sides[side]:
					covers = covers and p.x >= float(w[0][0]) - 0.1 and p.x <= float(w[0][1]) + 0.1 \
						and p.y >= float(w[2][0]) - 0.1 and p.y <= float(w[2][1]) + 0.1
				closed = closed or covers
			if not closed:
				open_sides.append(side)
	check(play.size() == 4 and walls.size() >= 4 and open_sides.is_empty(),
		"play-area bounds: %d walls close the play rectangle %s; open sides: %s" % [walls.size(), play, open_sides])
	# Review 2026-10-03: the KayKit trees, rocks and props import no collision (no -col / -colonly nodes), so the
	# player walked through them. Every one he can reach (its footprint within his radius of the play rectangle)
	# carries its own StaticBody3D, and none of those bodies reaches into the path.
	var needs := 0
	var bodiless := []
	var on_path := []
	var own_col := {}
	for k in ext:
		var key := str(k)
		var parent := key.get_base_dir()
		if not parent in ["Forest", "Village/Street", "Yard", "Scatter"] or ext[k].instance == "":
			continue
		var inst: String = ext[k].instance
		if not own_col.has(inst):
			own_col[inst] = _scene_nodes(inst).values().any(func(n): return n.props.get("shape") is Shape3D)
		if own_col[inst]:
			continue
		var xf: Transform3D = ext[k].world
		var foot := _instance_footprint(inst, xf)
		if play.size() != 4 or not _circle_hits_rect(Vector2(xf.origin.x, xf.origin.z), foot + PLAYER_RADIUS, [[play[0], play[1]], [play[2], play[3]]]):
			continue
		needs += 1
		var shape_key := key + "/Body/CollisionShape3D"
		if not (ext.has(shape_key) and ext[shape_key].props.get("shape") is Shape3D):
			bodiless.append(key)
			continue
		var c: Vector3 = (ext[shape_key].world as Transform3D).origin
		var sh: Shape3D = ext[shape_key].props.shape
		var r := 0.0
		if sh is CylinderShape3D:
			r = (sh as CylinderShape3D).radius
		elif sh is BoxShape3D:
			r = Vector2((sh as BoxShape3D).size.x, (sh as BoxShape3D).size.z).length() * 0.5
		r *= (ext[shape_key].world as Transform3D).basis.get_scale().x
		if _dist_to_polyline(Vector2(c.x, c.z), hf.path) < float(hf.path_half) + r:
			on_path.append(key)
	check(needs >= 50 and bodiless.is_empty(), "%d reachable trees, rocks and props have a collider (none: %s)" % [needs, bodiless.slice(0, 4)])
	check(on_path.is_empty(), "no new collider reaches into the path %s" % [on_path.slice(0, 4)])
	_check_exterior_spawn_fallback(play)
	print("")


## The flat radius of an instanced scene's meshes (their AABB corners) about the instance origin, placed by `xf`.
static func _instance_footprint(scene_path: String, xf: Transform3D) -> float:
	var r := 0.0
	var nodes := _scene_nodes(scene_path)
	for k in nodes:
		var mesh = nodes[k].props.get("mesh")
		if not mesh is Mesh:
			continue
		var box: AABB = (nodes[k].world as Transform3D) * (mesh as Mesh).get_aabb()
		for cx in [box.position.x, box.end.x]:
			for cz in [box.position.z, box.end.z]:
				var w: Vector3 = xf.basis * Vector3(cx, 0, cz)
				r = maxf(r, Vector2(w.x, w.z).length())
	return r


## World [[x0, x1], [z0, z1]] of every convex collision proxy in a scene file, placed by `xf`.
static func _convex_rects(scene_path: String, xf: Transform3D) -> Array:
	var out: Array = []
	var nodes := _scene_nodes(scene_path)
	for k in nodes:
		var shape = nodes[k].props.get("shape")
		if shape is ConvexPolygonShape3D:
			var lo := Vector3(INF, INF, INF)
			var hi := Vector3(-INF, -INF, -INF)
			for pt in (shape as ConvexPolygonShape3D).points:
				var w: Vector3 = xf * ((nodes[k].world as Transform3D) * pt)
				lo = lo.min(w)
				hi = hi.max(w)
			out.append([[lo.x, hi.x], [lo.z, hi.z]])
	return out


## Review 2026-10-03: an exterior save from before 25.29's re-layout can hold a position outside the
## new walls or off the terrain; PlayerManager must refuse it (and use PlayerSpawnPoint), and must
## accept the spawn point and ordinary spots inside the play area.
func _check_exterior_spawn_fallback(play: Array) -> void:
	var pm = load(PLAYER_MANAGER_PATH)
	var has_fn: bool = pm != null and pm.get_script_method_list().any(func(m): return m.name == "spawn_reject_reason")
	check(has_fn, "PlayerManager.spawn_reject_reason() exists (old exterior saves fall back to PlayerSpawnPoint)")
	if not has_fn or play.size() != 4:
		return
	var world: Node = (load(EXTERIOR_SCENE_PATH) as PackedScene).instantiate()
	var sp := world.get_node_or_null("PlayerSpawnPoint") as Node3D
	var mid_z := (float(play[2]) + float(play[3])) * 0.5
	var bad := {
		"beyond the west wall": Vector3(float(play[0]) - 6.0, 1.0, mid_z),
		"inside the east wall": Vector3(float(play[1]) + 1.0, 1.0, mid_z),
		"far off the map": Vector3(500.0, 1.0, 500.0),
		"under the terrain": Vector3(sp.position.x, -60.0, sp.position.z) if sp else Vector3(0, -60, 0),
	}
	var good := {"PlayerSpawnPoint": sp.position if sp else Vector3.INF, "the village square": Vector3(17.5, -2.0, 8.0)}
	var wrong := []
	for label in bad:
		if pm.spawn_reject_reason(world, bad[label]) == "":
			wrong.append("accepted " + label)
	for label in good:
		var why: String = pm.spawn_reject_reason(world, good[label])
		if why != "":
			wrong.append("refused %s (%s)" % [label, why])
	check(sp != null and wrong.is_empty(), "saved exterior positions: outside the walls / off or under the terrain refused, the spawn point and the square accepted %s" % [wrong])
	world.free()


# --- Test 10: The Hourglass Pillar (Story 25.4) ---
# Segments and glow materials in the asset, the stage -> segments mapping (pure static function),
# the demo stage in game_config.json, the placement at the round bar's centre, the collider and hum
# anchor in the pillar scene, and the re-baked navmesh routing around the pillar.
func test_hourglass_pillar() -> void:
	print("[Test 10] The Hourglass Pillar")
	var has_asset := ResourceLoader.exists(PILLAR_PATH)
	check(has_asset, "asset exists: %s" % PILLAR_PATH.get_file())
	var nodes := _scene_nodes(PILLAR_PATH) if has_asset else {}
	for seg in PILLAR_STAGES[4] + ["pillar_stub"]:
		check(nodes.keys().any(func(k): return str(k).ends_with(seg)), "segment present: %s" % seg)
	var wrong := []
	var glow := 0
	for k in nodes:
		var mesh = nodes[k].props.get("mesh")
		if not mesh is Mesh:
			continue
		for s in (mesh as Mesh).get_surface_count():
			var m := (mesh as Mesh).surface_get_material(s) as StandardMaterial3D
			if m == null:
				continue
			if m.emission_enabled:
				glow += 1
			if (m.emission_enabled and m.roughness != 0.0) or (not m.emission_enabled and m.roughness <= 0.0):
				wrong.append("%s/%s r=%.2f" % [str(k).get_file(), m.resource_name, m.roughness])
	check(glow >= 3 and wrong.is_empty(), "glow surfaces at roughness 0, the rest > 0 (%d glow; wrong: %s)" % [glow, wrong])

	var script = load(PILLAR_SCRIPT_PATH) if ResourceLoader.exists(PILLAR_SCRIPT_PATH) else null
	var has_map: bool = script != null and script.get_script_method_list().any(func(m): return m.name == "segments_for_stage")
	check(has_map, "hourglass_pillar.gd has segments_for_stage()")
	if has_map:
		for stage in PILLAR_STAGES:
			check(Array(script.segments_for_stage(stage)) == PILLAR_STAGES[stage], "stage %d shows %s" % [stage, PILLAR_STAGES[stage]])
		check(Array(script.segments_for_stage(-1)) == PILLAR_STAGES[0] and Array(script.segments_for_stage(99)) == PILLAR_STAGES[4],
			"out-of-range stages clamp to 0 and 4")
	var cfg = _read_json(GAME_CONFIG_PATH)
	var demo_stage = cfg.get("pillar_reveal_stage") if cfg is Dictionary else null
	check((demo_stage is float or demo_stage is int) and int(demo_stage) >= 0 and int(demo_stage) <= 4,
		"game_config pillar_reveal_stage = %s (a number 0..4)" % [demo_stage])
	# Review 2026-10-03: a missing or non-numeric config value must not break _ready or silently show stage 0.
	var has_parse: bool = script != null and script.get_script_method_list().any(func(m): return m.name == "stage_from_config")
	check(has_parse, "hourglass_pillar.gd has stage_from_config()")
	if has_parse:
		var got := [null, "two", true, 2.0, 3, -5, 9.7].map(func(v): return script.stage_from_config(v))
		check(got == [4, 4, 4, 2, 3, 0, 4], "config stage: null / text / bool -> 4 (the full pillar), numbers clamp %s" % [got])

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var hits := tav.keys().filter(func(k): return tav[k].instance == PILLAR_SCENE_PATH)
	check(hits.size() == 1 and (tav[hits[0]].world as Transform3D).origin.distance_to(PILLAR_RING_CENTRE) < 0.05,
		"MainTavern has the pillar at the round bar's centre %s" % [hits])
	var ps := _scene_nodes(PILLAR_SCENE_PATH) if ResourceLoader.exists(PILLAR_SCENE_PATH) else {}
	check(ps.values().any(func(n): return n.props.get("shape") is CylinderShape3D), "pillar scene has a cylinder collider")
	check(ps.keys().any(func(k): return str(k).ends_with("HumAnchor")), "pillar scene has a HumAnchor for the hum (25.24)")
	var nav = null
	for k in tav:
		if str(k).ends_with("TavernNavigation"):
			nav = tav[k].props.get("navigation_mesh")
	# AC 6, literally: no polygon at ANY height covers the pillar centre (review 2026-10-03: the bake used to leave
	# an unreachable island on the pillar's top at y 5.17; region_min_size 8 now drops cut-off bits like it).
	# The on-mesh point is 4.3 m out: since Story 25.6 the round bar's counter covers r 2.4..3.1.
	check(nav is NavigationMesh and _nav_polys_at(nav, PILLAR_RING_CENTRE.x, PILLAR_RING_CENTRE.z).is_empty()
		and _nav_contains(nav, PILLAR_RING_CENTRE.x + 4.3, PILLAR_RING_CENTRE.z),
		"navmesh routes around the pillar (no polygon covers the centre at any height; 4.3 m away is on)")
	print("")


## Review 2026-10-03 (AC 3): glow_energy scales the emissive materials at runtime, so assigning the
## property (an AnimationPlayer, the day-phase lighting) must do what set_glow_energy() does.
## Called after the autoload frame: during _initialize() the root is not in the tree and _ready would not run.
func _check_pillar_glow_setter() -> void:
	if not ResourceLoader.exists(PILLAR_SCENE_PATH):
		return
	var p: Node3D = (load(PILLAR_SCENE_PATH) as PackedScene).instantiate()
	p.reveal_stage_override = 4   # no config read
	root.add_child(p)
	var glow: Array = p._glow
	p.glow_energy = 2.5
	var scaled := glow.size() >= 3 and glow.all(func(pair): return is_equal_approx(
		(pair[0] as StandardMaterial3D).emission_energy_multiplier, float(pair[1]) * 2.5))
	p.glow_energy = -1.0
	var floored: bool = p.glow_energy == 0.0 and glow.all(func(pair): return (pair[0] as StandardMaterial3D).emission_energy_multiplier == 0.0)
	check(scaled and floored, "pillar: setting glow_energy scales its %d emissive materials (2.5x), negatives floor at 0" % glow.size())
	p.free()
	# Story 25.23: the hall's lighting may set the glow before the pillar is ready (node order); it must be kept.
	var q: Node3D = (load(PILLAR_SCENE_PATH) as PackedScene).instantiate()
	q.reveal_stage_override = 4
	q.glow_energy = 1.7
	root.add_child(q)
	var early: bool = q._glow.size() >= 3 and q._glow.all(func(pair): return is_equal_approx(
		(pair[0] as StandardMaterial3D).emission_energy_multiplier, float(pair[1]) * 1.7))
	check(early, "pillar: a glow_energy set before its _ready is applied when it readies (Story 25.23's lighting may come first)")
	q.free()


# --- Test 11: The Hearth and firewood (Story 25.5) ---
# B1 objects, markers and collision proxies; the tri budgets and the glow rule for B1 and H3; the fire
# look (pure static functions in hearth.gd, bands identical to fireplace_zone.gd); the Hearth scene
# (group, light, particles WITH draw passes, log pile, wood store, sit point); the zone and minigame
# wiring; and the hall: grey boxes gone, the hearth at its spot facing the room, the prompt zone
# reachable, the navmesh routed round the apron.
func test_hearth() -> void:
	print("[Test 11] The Hearth and firewood")
	for p in [HEARTH_PATH, FIREWOOD_LOG_PATH, FIREWOOD_BUNDLE_PATH]:
		check(ResourceLoader.exists(p), "asset exists: %s" % p.get_file())
	var nodes := _scene_nodes(HEARTH_PATH) if ResourceLoader.exists(HEARTH_PATH) else {}
	var names := nodes.keys().map(func(k): return str(k).get_file())
	var wanted: Array = HEARTH_OBJECTS + HEARTH_MARKERS
	for i in 5:
		wanted.append("log_slot_%d" % (i + 1))
	for i in 10:
		wanted.append("store_slot_%02d" % (i + 1))
	var missing := wanted.filter(func(n): return not n in names)
	check(not nodes.is_empty() and missing.is_empty(), "B1 objects and markers present (missing: %s)" % [missing])
	var convex := nodes.values().filter(func(n): return n.props.get("shape") is ConvexPolygonShape3D).size()
	check(convex >= 3, "B1 has %d convex collision proxies (body, apron, seat)" % convex)
	for spec in [[HEARTH_PATH, 5000, 3], [FIREWOOD_LOG_PATH, 300, 0], [FIREWOOD_BUNDLE_PATH, 300, 0]]:
		var st := _mesh_stats(spec[0]) if ResourceLoader.exists(spec[0]) else {"tris": 0, "glow": 0, "wrong": ["missing"]}
		check(st.tris > 0 and st.tris <= spec[1], "%s: %d tris (budget %d)" % [str(spec[0]).get_file(), st.tris, spec[1]])
		check(st.glow >= spec[2] and st.wrong.is_empty(),
			"%s: glow surfaces at roughness 0, the rest > 0 (%d glow; wrong: %s)" % [str(spec[0]).get_file(), st.glow, st.wrong])

	var hs = load(HEARTH_SCRIPT_PATH) if ResourceLoader.exists(HEARTH_SCRIPT_PATH) else null
	var has_look: bool = hs != null and hs.get_script_method_list().any(func(m): return m.name == "fire_look")
	check(has_look, "hearth.gd has fire_look()")
	if has_look:
		var zc: Dictionary = (load(FIRE_ZONE_SCRIPT_PATH) as Script).get_script_constant_map()
		# The zone's own floors, never a fallback copy of the hearth's numbers (review 2026-10-03).
		var floors_ok: bool = (zc.get("FUEL_HIGH_FLOOR") is float or zc.get("FUEL_HIGH_FLOOR") is int) \
			and (zc.get("FUEL_LOW_FLOOR") is float or zc.get("FUEL_LOW_FLOOR") is int)
		check(floors_ok, "fireplace_zone.gd defines FUEL_HIGH_FLOOR and FUEL_LOW_FLOOR")
		var hi := float(zc.get("FUEL_HIGH_FLOOR", NAN))
		var lo := float(zc.get("FUEL_LOW_FLOOR", NAN))
		var bands := [[0.0, "out"], [0.5, "dying"], [lo, "dying"], [lo + 0.5, "low"], [hi, "low"], [hi + 0.5, "high"], [100.0, "high"]]
		for b in bands:
			check(hs.fire_look(b[0]).band == b[1], "fuel %.1f reads %s (zone floors %d / %d)" % [b[0], b[1], hi, lo])
		var o: Dictionary = hs.fire_look(0.0)
		check(o.light == 0.0 and o.flames == 0.0 and o.sparks == 0.0 and o.ember_glow == 0.0 and o.smoke == 0.0 and o.logs == 0,
			"out is dark: no light, flames, sparks, glow, smoke or logs %s" % [o])
		var d: Dictionary = hs.fire_look(10.0)
		var l: Dictionary = hs.fire_look(35.0)
		var h: Dictionary = hs.fire_look(80.0)
		for key in ["light", "flame_size", "flames", "ember_glow"]:
			check(h[key] > l[key] and l[key] > d[key] and d[key] > 0.0,
				"%s ranks high > low > dying > out (%.2f / %.2f / %.2f)" % [key, h[key], l[key], d[key]])
		check(d.smoke > h.smoke and h.smoke > 0.0, "a dying fire smoulders more than a high one (%.2f > %.2f)" % [d.smoke, h.smoke])
		check(d.logs == 1 and l.logs >= 2 and l.logs <= 3 and h.logs >= 3 and h.logs <= 5,
			"logs on the andirons: dying 1, low 2-3, high 3-5 (%d / %d / %d)" % [d.logs, l.logs, h.logs])
		check(hs.logs_shown(0.0, 0) == 0 and hs.logs_shown(0.0, 2) == 2 and hs.logs_shown(10.0, 0) == 1 and hs.logs_shown(80.0, 4) == 5,
			"logs_shown adds the placed logs to the burning ones, capped at 5")
		check(hs.store_shown(-3) == 0 and hs.store_shown(0) == 0 and hs.store_shown(4) == 4 and hs.store_shown(25) == 10,
			"store_shown shows one log per unit of stock, 0..10")

	var hsn := _scene_nodes(HEARTH_SCENE_PATH) if ResourceLoader.exists(HEARTH_SCENE_PATH) else {}
	var hstate: SceneState = (load(HEARTH_SCENE_PATH) as PackedScene).get_state() if not hsn.is_empty() else null
	check(hstate != null and "hearth" in Array(hstate.get_node_groups(0)), "Hearth.tscn root is in group 'hearth'")
	check(hsn.values().any(func(n): return n.instance == HEARTH_PATH), "Hearth.tscn instances the B1 model")
	check(hsn.has("FireLight") and hsn.FireLight.type == "OmniLight3D", "Hearth.tscn has the FireLight")
	for pn in ["FireParticles", "Embers", "Smoke"]:
		check(hsn.has(pn) and hsn[pn].type == "GPUParticles3D" and hsn[pn].props.get("draw_pass_1") is Mesh
			and hsn[pn].props.get("process_material") is ParticleProcessMaterial,
			"%s is a GPUParticles3D with a draw pass and a process material" % pn)
	var pile := hsn.keys().filter(func(k): return str(k).begins_with("LogPile/") and hsn[k].instance == FIREWOOD_LOG_PATH)
	var store := hsn.keys().filter(func(k): return str(k).begins_with("WoodStore/") and hsn[k].instance == FIREWOOD_LOG_PATH)
	check(pile.size() == 5 and store.size() == 10, "LogPile has %d H3 logs (5), WoodStore %d (10)" % [pile.size(), store.size()])
	check(hsn.has("SitPoint") and hsn.SitPoint.type == "Marker3D", "Hearth.tscn reserves a SitPoint for Den Fa (25.10)")

	var mg = load(MINIGAME_SCRIPT_PATH) as Script
	check(mg != null and mg.get_script_signal_list().any(func(sg): return sg.name == "log_placed"),
		"FireplaceMinigamePanel has signal log_placed")
	var zsrc := (load(FIRE_ZONE_SCRIPT_PATH) as GDScript).source_code
	check(zsrc.contains('get_first_node_in_group("hearth")') and not zsrc.contains("../../../Furniture"),
		"fireplace_zone.gd finds the hearth by group (the old ../../../Furniture path resolved to null)")

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var boxes := tav.keys().filter(func(k): return str(k).get_file() in ["FireplaceBack", "FireplaceBase", "Mantel"])
	check(boxes.is_empty(), "the fireplace grey boxes are gone %s" % [boxes])
	var hits := tav.keys().filter(func(k): return tav[k].instance == HEARTH_SCENE_PATH)
	var placed: bool = hits.size() == 1 and (tav[hits[0]].world as Transform3D).origin.distance_to(HEARTH_SPOT) < 0.05
	var facing: bool = hits.size() == 1 and (tav[hits[0]].world as Transform3D).basis.z.normalized().dot(Vector3.RIGHT) > 0.99
	check(placed and facing, "MainTavern has one hearth at %s facing +x into the room %s" % [HEARTH_SPOT, hits])
	var w5 := tav.keys().filter(func(k): return str(k).ends_with("FarWalls/West_5"))
	check(w5.size() == 1 and str(tav[w5[0]].instance).ends_with("b9_wall_full.gltf"), "West_5 behind the chimney is a full wall panel")
	var zone_box := AABB()
	for k in tav:
		if str(k).ends_with("Interactive/FireplaceArea/CollisionShape3D") and tav[k].props.get("shape") is BoxShape3D:
			var size: Vector3 = (tav[k].props.shape as BoxShape3D).size
			zone_box = (tav[k].world as Transform3D) * AABB(-size / 2, size)
	var nav = null
	for k in tav:
		if str(k).ends_with("TavernNavigation"):
			nav = tav[k].props.get("navigation_mesh")
	check(zone_box.has_point(HEARTH_APPROACH) and nav is NavigationMesh and _nav_contains(nav, HEARTH_APPROACH.x, HEARTH_APPROACH.z),
		"the Tend Fire zone %s covers a reachable spot in front of the apron" % [zone_box])
	check(nav is NavigationMesh and not _nav_contains(nav, HEARTH_BLOCKED.x, HEARTH_BLOCKED.y),
		"navmesh routes round the hearth's chimney body (%s is off the mesh)" % [HEARTH_BLOCKED])
	_check_fire_zone_bands()
	print("")


## Review 2026-10-03: the zone may push to the hearth before the hearth's _ready (node order), and a
## flash asked for while the light is hidden must not fire later. Called after the autoload frame (see above).
func _check_hearth_early_calls() -> void:
	if not ResourceLoader.exists(HEARTH_SCENE_PATH):
		return
	var h: Node3D = (load(HEARTH_SCENE_PATH) as PackedScene).instantiate()
	h.set_fire_level(70.0)        # before _ready: nothing is wired yet
	h.set_placed_logs(2)
	h.set_stock(3)
	h.play_ignition()
	root.add_child(h)             # _ready applies what was pushed
	var light := h.get_node("FireLight") as OmniLight3D
	check(h.fuel == 70.0 and light.visible and h._look.get("band") == "high" and h.placed_logs == 2,
		"hearth: a fuel push before its _ready is applied when it readies (fuel %.0f, band %s)" % [h.fuel, h._look.get("band")])
	h.set_fire_level(0.0)
	h.play_ignition()
	h._process(1.0)               # hidden light: the flash still fades
	var faded: bool = h._flash == 0.0
	h.set_fire_level(70.0)
	check(faded, "hearth: an ignition flash fades while the light is hidden (no stale flash when it relights)")
	h.free()
	# Story 25.23: light_scale (the hall's mood and phase) multiplies the fire's light only; set before _ready it is kept.
	var g: Node3D = (load(HEARTH_SCENE_PATH) as PackedScene).instantiate()
	var has_scale: bool = "light_scale" in g
	if not has_scale:
		check(false, "hearth.gd has light_scale (Story 25.23)")
		g.free()
		return
	g.light_scale = 1.6
	g.set_fire_level(70.0)
	root.add_child(g)
	var gl := g.get_node("FireLight") as OmniLight3D
	var look70: Dictionary = g.fire_look(70.0)
	var col_ok: bool = gl.light_color == look70.color
	var e1: float = gl.light_energy
	check(g.light_scale == 1.6 and is_equal_approx(e1, float(look70.light) * 1.6) and col_ok,
		"hearth: a light_scale set before _ready is kept and multiplies the light (%.3f = %.3f x 1.6), the colour as the band's" % [e1, look70.light])
	g._flash = 0.0
	g._t = 0.0
	g._process(0.0)
	var flick: float = 1.0 + 0.07 * sin(0.0) + 0.04 * sin(1.3)
	var proc_ok: bool = is_equal_approx(gl.light_energy, float(look70.light) * flick * 1.6)
	var flames := g.get_node("FireParticles") as GPUParticles3D
	var ratio := flames.amount_ratio
	var logs := (g.get_node("LogPile") as Node3D).get_children().filter(func(n): return n.visible).size()
	g.light_scale = 0.5
	var after_ok: bool = is_equal_approx(gl.light_energy, float(look70.light) * 0.5) and flames.amount_ratio == ratio \
		and (g.get_node("LogPile") as Node3D).get_children().filter(func(n): return n.visible).size() == logs and gl.light_color == look70.color
	g.light_scale = -2.0
	var floored: bool = g.light_scale == 0.0
	g.light_scale = NAN
	var nan_ok: bool = g.light_scale == 1.0
	g.light_scale = 3.0
	g.set_fire_level(0.0)
	g._process(0.1)
	check(proc_ok and after_ok and floored and nan_ok and not gl.visible and gl.light_energy == 0.0,
		"hearth: the flicker carries light_scale; assigning it changes only the light (flames, logs, colour untouched); negatives floor at 0, NaN -> 1; a fire that is out stays dark at any scale")
	g.free()


## Review 2026-10-03: the zone's fire state comes from a fuel level with the state machine's own bands,
## so a re-entered scene or a loaded save starts burning (and decaying) instead of DORMANT.
func _check_fire_zone_bands() -> void:
	var zs := load(FIRE_ZONE_SCRIPT_PATH) as Script
	var has_sync: bool = zs.get_script_method_list().any(func(m): return m.name == "sync_from_fuel")
	check(has_sync, "fireplace_zone.gd has sync_from_fuel()")
	if not has_sync:
		return
	var st: Dictionary = zs.get_script_constant_map().get("FireplaceState", {})
	var z := Area3D.new()
	z.set_script(zs)
	var got := []
	for f in [80.0, 35.0, 10.0, 0.0]:
		z.sync_from_fuel(f)
		got.append([z.current_state, z.fire_quality])
	z.free()
	var want := [[st.get("BURNING_HIGH"), 80.0], [st.get("BURNING_LOW"), 35.0], [st.get("DYING"), 10.0], [st.get("DORMANT"), 0.0]]
	check(got == want, "fire zone from fuel 80 / 35 / 10 / 0: high, low, dying, dormant %s" % [got])


## Test 11, runtime part (review 2026-10-03; needs GameManager): a fire zone that enters the tree while
## GameManager has fuel (a re-entered hall, a loaded save) shows it and burns it down.
func test_fire_resume() -> void:
	print("[Test 11] The fire resumes from GameManager's fuel")
	var gm = root.get_node_or_null("GameManager")
	if gm == null:
		check(false, "GameManager autoload present")
		return
	var old_fuel: float = gm.get_fireplace_fuel()
	gm.set_fireplace_fuel(65.0)
	var z := Area3D.new()
	z.set_script(load(FIRE_ZONE_SCRIPT_PATH))
	root.add_child(z)
	var st: Dictionary = (z.get_script() as Script).get_script_constant_map().get("FireplaceState", {})
	var state_at_ready = z.current_state
	var q0: float = z.fire_quality
	for i in 5:
		await process_frame
	var q1: float = z.fire_quality
	check(state_at_ready == st.get("BURNING_HIGH") and q0 == 65.0, "the zone starts BURNING_HIGH at GameManager's 65 (state %s, fuel %.1f)" % [state_at_ready, q0])
	check(q1 < q0 and q1 > 60.0, "and the fire decays from there (%.3f -> %.3f)" % [q0, q1])
	z.queue_free()
	await process_frame
	gm.set_fireplace_fuel(old_fuel)
	print("")


## Tri count and the ink/glow rule over every mesh in a scene file: emissive surfaces at roughness 0,
## everything else above 0.
static func _mesh_stats(scene_path: String) -> Dictionary:
	var tris := 0
	var glow := 0
	var wrong := []
	var nodes := _scene_nodes(scene_path)
	for k in nodes:
		var mesh = nodes[k].props.get("mesh")
		if not mesh is Mesh:
			continue
		for s in (mesh as Mesh).get_surface_count():
			tris += ((mesh as Mesh).surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			var m := (mesh as Mesh).surface_get_material(s) as StandardMaterial3D
			if m == null:
				continue
			if m.emission_enabled:
				glow += 1
			if (m.emission_enabled and m.roughness != 0.0) or (not m.emission_enabled and m.roughness <= 0.0):
				wrong.append("%s/%s r=%.2f" % [str(k).get_file(), m.resource_name, m.roughness])
	return {"tris": tris, "glow": glow, "wrong": wrong}


# --- Test 12: The Round Bar and drinks service (Story 25.6) ---
# B2 ring, bar stool, B12 back-bar island and H1 tankards (budgets, glow rule, objects, markers,
# trimesh colliders, the walkway between island and counter); the BarStool / RoundBar scenes (seat
# group, 12 stools facing the centre, serve points); seats from the scene (PatronSpawner.build_seats,
# RealisticPatron.seat_root, the tankard props); and the hall: old bar pieces gone, the bar at the
# pillar, navmesh round the counter with every stool reachable.
func test_round_bar() -> void:
	print("[Test 12] The Round Bar and drinks service")
	for spec in [[ROUND_BAR_PATH, 6000, 1], [BAR_STOOL_PATH, 150, 0], [BACK_BAR_PATH, 3000, 0],
			[TANKARD_FULL_PATH, 300, 0], [TANKARD_EMPTY_PATH, 300, 0]]:
		var ok := ResourceLoader.exists(spec[0])
		check(ok, "asset exists: %s" % str(spec[0]).get_file())
		var st := _mesh_stats(spec[0]) if ok else {"tris": 0, "glow": 0, "wrong": ["missing"]}
		check(st.tris > 0 and st.tris <= spec[1] and st.glow >= spec[2] and st.wrong.is_empty(),
			"%s: %d tris (budget %d), glow rule (%d glow; wrong: %s)" % [str(spec[0]).get_file(), st.tris, spec[1], st.glow, st.wrong])
	var bar := _scene_nodes(ROUND_BAR_PATH) if ResourceLoader.exists(ROUND_BAR_PATH) else {}
	var bar_names := bar.keys().map(func(k): return str(k).get_file())
	var want := ["bar_ring", "bar_flap", "bar_runes", "foot_rail", "flap_point"]
	for i in 5:
		want.append("serve_point_%02d" % (i + 1))
	check(not bar.is_empty() and want.all(func(n): return n in bar_names), "B2 objects and markers present")
	var island := _scene_nodes(BACK_BAR_PATH) if ResourceLoader.exists(BACK_BAR_PATH) else {}
	var island_names := island.keys().map(func(k): return str(k).get_file())
	check(not island.is_empty() and ["back_shelf", "keg_rack", "keg_beer", "keg_mead", "work_point", "tap_beer", "tap_mead"].all(
		func(n): return n in island_names), "B12 island objects (shelf, rack, beer and mead kegs) and markers present")
	var counter_in := _shape_radius(bar, true)
	var island_out := _shape_radius(island, false)
	check(counter_in > 0.0 and island_out > 0.0 and counter_in - island_out >= 1.0,
		"trimesh colliders; the Bartender's walkway is %.2f m (counter r %.2f - island r %.2f, need >= 1.0)" % [counter_in - island_out, counter_in, island_out])
	var stool := _scene_nodes(BAR_STOOL_PATH) if ResourceLoader.exists(BAR_STOOL_PATH) else {}
	var seat_y := -1.0
	for k in stool:
		if str(k).get_file() == "seat_point":
			seat_y = (stool[k].world as Transform3D).origin.y
	# Story 25.31 S2.0 (R-5): bar height. The seat is set so the seated realistic elbows (0.39 / 0.36 above the seat on
	# REAL-1 / REAL-2) meet the 1.10 m counter top; RealisticPatron seats patrons at its height and lifts the body
	# by seat - the clip's 0.45 m seat, so the soles land on the foot ring / footrest 0.45 m under the seat.
	var rp_c: Dictionary = (load(PATRON_SCRIPT_PATH) as Script).get_script_constant_map() if ResourceLoader.exists(PATRON_SCRIPT_PATH) else {}
	var stool_seat := float(rp_c.get("BAR_STOOL_SEAT", -1.0))
	check(seat_y >= 0.70 and seat_y <= 0.78 and absf(seat_y - stool_seat) < 0.005,
		"the stool's seat_point is at %.2f m (bar height 0.70-0.78; RealisticPatron.BAR_STOOL_SEAT %.2f)" % [seat_y, stool_seat])
	var lift := float(rp_c.get("SIT_LIFT", -1.0))
	check(absf(lift - (seat_y - float(rp_c.get("SIT_CLIP_SEAT", 0.0)))) < 0.005 and absf(float(rp_c.get("SIT_CLIP_SEAT", 0.0)) - 0.45) < 0.011
		and absf(float(rp_c.get("SIT_HIP_BACK", 0.0)) - 0.397) < 0.01,
		"RealisticPatron: SIT_LIFT %.2f = the seat - the sit clips' seat (SIT_CLIP_SEAT 0.45), SIT_HIP_BACK %.3f (0.397, measured)" % [lift, float(rp_c.get("SIT_HIP_BACK", 0.0))])
	# The footrest: the highest mesh point ahead of the legs (z > 0.25 in the stool's frame: the sitter faces +Z) is the
	# crossbar's top, at the soles' height (seat - 0.45) and spanning the soles of both bases.
	var rest_top := -1.0
	var rest_z := Vector2(INF, -INF)
	var leg_r := 0.0
	for k in stool:
		var mesh = stool[k].props.get("mesh")
		if not mesh is Mesh:
			continue
		for s in (mesh as Mesh).get_surface_count():
			for v in ((mesh as Mesh).surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var w: Vector3 = (stool[k].world as Transform3D) * v
				if w.z > 0.25:
					rest_top = maxf(rest_top, w.y)
					rest_z = Vector2(minf(rest_z.x, w.z), maxf(rest_z.y, w.z))
				if w.y < 0.01:
					leg_r = maxf(leg_r, Vector2(w.x, w.z).length())
	check(absf(rest_top - (seat_y - 0.45)) <= 0.01 and rest_z.x <= SIT_SOLES_AHEAD.y and rest_z.y >= SIT_SOLES_AHEAD.x,
		"the footrest's top is at %.2f m (seat - 0.45 = %.2f), %.2f-%.2f m ahead (the soles %.2f-%.2f)" % [rest_top, seat_y - 0.45, rest_z.x, rest_z.y, SIT_SOLES_AHEAD.x, SIT_SOLES_AHEAD.y])
	check(leg_r > 0.0 and leg_r <= 0.27, "the stool's floor footprint stays 25.6's (legs within r %.2f of its centre)" % leg_r)

	var bs := _scene_nodes(BAR_STOOL_SCENE_PATH) if ResourceLoader.exists(BAR_STOOL_SCENE_PATH) else {}
	var seat_local := Transform3D.IDENTITY
	var seat_ok := false
	for k in bs:
		if "patron_seat" in bs[k].groups and bs[k].type == "Marker3D":
			seat_ok = true
			seat_local = bs[k].world
	check(seat_ok, "BarStool.tscn has a Marker3D in group patron_seat")
	var rb := _scene_nodes(ROUND_BAR_SCENE_PATH) if ResourceLoader.exists(ROUND_BAR_SCENE_PATH) else {}
	var stools := rb.keys().filter(func(k): return rb[k].instance == BAR_STOOL_SCENE_PATH)
	var facing_ok := true
	for k in stools:
		var t: Transform3D = rb[k].world
		var r := Vector2(t.origin.x, t.origin.z).length()
		var inward := Vector3(-t.origin.x, 0, -t.origin.z).normalized()
		if absf(r - 3.95) >= 0.05 or t.basis.z.normalized().dot(inward) <= 0.99:
			facing_ok = false
	check(stools.size() == 12 and facing_ok, "RoundBar has %d stools (12) at r 3.95 facing the bar" % stools.size())
	var serves := rb.keys().filter(func(k): return rb[k].type == "Marker3D" and "serve_point" in rb[k].groups)
	check(serves.size() == 5, "RoundBar has %d serve points for the Bartender (5)" % serves.size())
	check(rb.values().any(func(n): return n.instance == BACK_BAR_PATH), "RoundBar instances the B12 island")

	var sp = load(SPAWNER_SCRIPT_PATH) as Script
	var rp = load(PATRON_SCRIPT_PATH) as Script
	var has_api: bool = sp != null and rp != null and sp.get_script_method_list().any(func(m): return m.name == "build_seats") \
		and rp.get_script_method_list().any(func(m): return m.name == "seat_root")
	check(has_api, "PatronSpawner.build_seats() and RealisticPatron.seat_root() exist")
	if has_api:
		var seat_t := Transform3D(Basis.looking_at(Vector3(0, 0, 1), Vector3.UP, true), Vector3(0, 0.1 + float(rp_c.get("BAR_STOOL_SEAT", 0.44)), -3.95))   # +Z toward the centre
		var root: Vector3 = rp.seat_root(seat_t)
		check(root.distance_to(Vector3(0, 0.1, -3.553)) < 0.02, "seat_root: 0.397 m in front of the seat, on the floor (%s)" % root)
		var far := Vector3(-3.0, 0, -1.0)
		var near := Vector3(0.1, 0, -3.5)
		var only_tables: Array = sp.build_seats([], [far, near])
		check(only_tables.size() == 2 and only_tables.all(func(s): return s.sit == null) and only_tables[0].approach == far,
			"build_seats with no scene seats is the old table list")
		var mixed: Array = sp.build_seats([seat_t], [far, near])
		# The nav target sits SEAT_APPROACH_BACK behind the sit root (away from the bar), where the navmesh
		# is: the root itself is inside the counter's agent margin (review 2026-10-03). The patron walks
		# to the approach and slides onto the root when he sits.
		var back := float(sp.get_script_constant_map().get("SEAT_APPROACH_BACK", 0.0))
		var want_app := root - Vector3(0, 0, 1) * back
		check(back >= 0.25 and mixed.size() == 2 and mixed[0].sit is Transform3D and mixed[0].approach.distance_to(want_app) < 0.01
			and mixed[1].approach == far,
			"build_seats: scene seats first (approach %.2f m behind the sit root), table spots kept unless within 0.8 m of a seat" % back)
		# Elbow room (found in the 2026-09-25 playtest: neighbours on adjacent stools look crowded).
		var row := []
		var tables := []
		# Story 25.31 S2 (AC 12): SEAT_ELBOW_ROOM from the realistic townsfolk seated (widest half-width 0.434 m with
		# elbows, hats and packs, + a 0.30 m gap): the round bar's adjacent stools (sit roots 1.23 m apart) are usable
		var room := float(sp.get_script_constant_map().get("SEAT_ELBOW_ROOM", 0.0))
		var adjacent := 2.0 * (3.95 - float(rp_c.get("SIT_HIP_BACK", 0.4))) * sin(deg_to_rad(10.0))
		check(room >= 2.0 * 0.434 + 0.25 and room <= adjacent,
			"SEAT_ELBOW_ROOM %.2f: two seated realistic townsfolk keep a gap (>= %.2f) and adjacent bar stools (%.2f m) are usable" % [room, 2.0 * 0.434 + 0.25, adjacent])
		for i in 4:
			row.append({"approach": Vector3(1.0 * i, 0, -0.3), "sit": Transform3D(Basis.IDENTITY, Vector3(1.0 * i, 0.54, 0))})
			tables.append({"approach": Vector3(1.0 * i, 0, 0), "sit": null})
		var has_pick: bool = sp.get_script_method_list().any(func(m): return m.name == "pick_seat")
		var picks: Array = [sp.pick_seat(row, [0], 0.0), sp.pick_seat(row, [0], 0.99), sp.pick_seat(row, [0, 2], 0.0),
			sp.pick_seat(row, [0, 1, 2, 3], 0.5)] if has_pick else []
		check(has_pick and picks[0] == 2 and picks[1] == 3 and picks[2] in [1, 3] and picks[3] == -1,
			"pick_seat keeps elbow room between stools (next to 0: 2 or 3, never 1, never the taken seat), packs in only when full %s" % [picks])
		var tpick: Array = [sp.pick_seat(tables, [0], 0.0), sp.pick_seat(tables, [0, 1, 2], 0.0)] if has_pick else []
		check(has_pick and tpick == [1, 3], "table spots share a table: no elbow room between them %s" % [tpick])
	var tank_ok: bool = rp != null and ResourceLoader.exists(str(rp.get_script_constant_map().get("TANKARD_FULL", ""))) \
		and ResourceLoader.exists(str(rp.get_script_constant_map().get("TANKARD_EMPTY", "")))
	check(tank_ok, "RealisticPatron's tankard props point at the H1 files")

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var gone := tav.keys().filter(func(k): return OLD_BAR_NODES.any(func(p): return str(k).ends_with("TavernNavigation/" + p)))
	check(gone.is_empty(), "the old bar pieces are gone %s" % [gone])
	var tscn_text := FileAccess.get_file_as_string(TAVERN_SCENE_PATH)
	check(not tscn_text.contains("TavernCounterCircular.glb"), "MainTavern no longer needs the gitignored TavernCounterCircular.glb")
	var hits := tav.keys().filter(func(k): return tav[k].instance == ROUND_BAR_SCENE_PATH)
	check(hits.size() == 1 and (tav[hits[0]].world as Transform3D).origin.distance_to(PILLAR_RING_CENTRE) < 0.05,
		"MainTavern has the round bar at the pillar %s" % [hits])
	var nav = null
	for k in tav:
		if str(k).ends_with("TavernNavigation"):
			nav = tav[k].props.get("navigation_mesh")
	if hits.size() == 1 and nav is NavigationMesh:
		var t_bar: Transform3D = tav[hits[0]].world
		var c := t_bar.origin
		check(not _nav_contains(nav, c.x, c.z + 2.7), "navmesh: the counter is solid (r 2.7 in front is off)")
		check(_nav_contains(nav, c.x, c.z - 3.7), "navmesh: the flap entrance (r 3.7 behind) is on")
		var off := []
		for k in stools:
			var seat_w: Transform3D = t_bar * (rb[k].world as Transform3D) * seat_local
			# The point the patron is actually sent to (build_seats' approach), not a nudged copy of it.
			var p: Vector3 = sp.build_seats([seat_w], [])[0].approach if has_api else seat_w.origin
			if not _nav_contains(nav, p.x, p.z):
				off.append("(%.2f, %.2f)" % [p.x, p.z])
		check(stools.size() == 12 and off.is_empty(), "navmesh: every stool's approach (the nav target) is on the mesh (off: %s)" % [off])
	else:
		check(false, "navmesh checks need the bar in MainTavern")
	print("")


## Test 12, runtime part (review 2026-10-03; needs frames): the held tankard turns upright a couple of
## frames after it is attached, and a patron that leaves the tree meanwhile is simply skipped (the
## old coroutine called get_tree() after its awaits and hit a null tree).
func test_tankard_upright() -> void:
	print("[Test 12] The held tankard: upright after two frames, safe when the patron leaves the tree")
	var world := Node3D.new()
	root.add_child(world)
	var p = (load("res://scenes/npcs/RealisticPatron.tscn") as PackedScene).instantiate()
	p.set_physics_process(false)
	world.add_child(p)
	p.set_physics_process(false)
	await process_frame
	if p.animation_player:
		p.animation_player.pause()   # hold the hand still, so the turned tankard can be compared exactly
	p._hold_tankard(true)
	var slot = p._tankard
	var mug: Node3D = slot.get_child(0) if slot and slot.get_child_count() > 0 else null
	var local0: Basis = mug.transform.basis if mug else Basis()
	await process_frame
	var turned_early: bool = mug != null and not mug.transform.basis.is_equal_approx(local0)
	for i in 2:
		await process_frame
	# Story 25.31 S2: the held size is the body's (its entry's tankard_scale on a realistic body, KayKit's 1.8 otherwise)
	var want_scale: float = float(p.body_variant.get("tankard_scale", p.TANKARD_HELD_SCALE)) if not p.using_fallback else float(p.TANKARD_HELD_SCALE)
	check(absf(float(p.tankard_scale) - want_scale) < 0.001, "the held tankard is drawn x%.2f on this body (%s)" % [float(p.tankard_scale), p.body_path.get_file()])
	var want: Basis = Basis(p.patron_body_mesh.global_basis.get_rotation_quaternion()).scaled(Vector3.ONE * float(p.tankard_scale)) if p.patron_body_mesh else Basis()
	var off := 0.0
	if mug:
		for col in 3:
			off = maxf(off, (mug.global_basis[col] - want[col]).length())
	check(mug != null and not turned_early and off < 0.01,
		"the tankard stands upright in the patron's frame two frames after it is attached (off %.4f, early %s)" % [off, turned_early])
	p._hold_tankard(false)
	var mug2: Node3D = p._tankard.get_child(0) if p._tankard and p._tankard.get_child_count() > 0 else null
	var before: Basis = mug2.transform.basis if mug2 else Basis()
	world.remove_child(p)          # leaves the tree before the two frames are up
	for i in 3:
		await process_frame
	check(is_instance_valid(p) and mug2 != null and mug2.transform.basis.is_equal_approx(before),
		"a patron out of the tree is skipped (no turn, no null-tree call)")
	p.free()
	world.queue_free()
	await process_frame
	print("")



# --- Test 13: The guild desk and mission board (Story 25.7) ---
# B3 desk and B4 board (budgets, glow rule, objects, markers: the Quest Dealer's work_point at seat
# height facing the customer side; the 8 notices); notices_shown (the board shows today's contracts);
# the scenes (DeskLight, work_point group, the board in group notice_board and never in the UI's
# mission_board group); and the hall: old pieces gone, desk and board placed facing the room, each
# prompt zone covering its interact point on the navmesh, the desk solid.
func test_desk_and_board() -> void:
	print("[Test 13] The guild desk and mission board")
	for spec in [[DESK_PATH, 2500, 1], [BOARD_PATH, 2500, 1]]:
		var ok := ResourceLoader.exists(spec[0])
		check(ok, "asset exists: %s" % str(spec[0]).get_file())
		var st := _mesh_stats(spec[0]) if ok else {"tris": 0, "glow": 0, "wrong": ["missing"]}
		check(st.tris > 0 and st.tris <= spec[1] and st.glow >= spec[2] and st.wrong.is_empty(),
			"%s: %d tris (budget %d), glow rule (%d glow; wrong: %s)" % [str(spec[0]).get_file(), st.tris, spec[1], st.glow, st.wrong])
	var desk := _scene_nodes(DESK_PATH) if ResourceLoader.exists(DESK_PATH) else {}
	var dn := {}
	for k in desk:
		dn[str(k).get_file()] = desk[k]
	check(["desk", "desk_dressing", "desk_stool", "work_point", "chronicle_point", "candle_point", "interact_point"].all(func(n): return dn.has(n)),
		"B3 objects and markers present")
	var wp: Transform3D = dn.work_point.world if dn.has("work_point") else Transform3D()
	check(absf(wp.origin.y - 0.44) <= 0.05 and wp.basis.z.normalized().dot(Vector3.BACK) > 0.99,
		"the Quest Dealer's work_point sits at %.2f m facing the customer side" % wp.origin.y)
	check(desk.values().any(func(n): return n.props.get("shape") is ConcavePolygonShape3D), "B3 has its trimesh collider")
	var board := _scene_nodes(BOARD_PATH) if ResourceLoader.exists(BOARD_PATH) else {}
	var bnames := board.keys().map(func(k): return str(k).get_file())
	# notice_board.gd finds exactly notice_01..notice_08 (review 2026-10-03: any "notice_" name used to pass).
	var missing_notices := range(1, 9).map(func(i): return "notice_%02d" % i).filter(func(n): return not n in bnames)
	check(missing_notices.is_empty() and "interact_point" in bnames,
		"B4 has notice_01..notice_08 and an interact_point (missing: %s)" % [missing_notices])

	var nb = load(NOTICE_SCRIPT_PATH) if ResourceLoader.exists(NOTICE_SCRIPT_PATH) else null
	var has_fn: bool = nb != null and nb.get_script_method_list().any(func(m): return m.name == "notices_shown")
	check(has_fn and nb.notices_shown(-1) == 0 and nb.notices_shown(0) == 0 and nb.notices_shown(3) == 3
		and nb.notices_shown(8) == 8 and nb.notices_shown(12) == 8, "notices_shown: one per available contract, 0..8")
	if has_fn:
		var a := {"name": "Wolves"}
		var b := {"name": "Bandits"}
		check(nb.open_contracts([a, b], []) == 2 and nb.open_contracts([a, b], [{"mission": a, "days_remaining": 2}]) == 1
			and nb.open_contracts([], [{"mission": a}]) == 0, "open_contracts: today's pool minus the contracts already taken")
		# Review 2026-10-03: two identical contracts, one taken, leave one open; a taken contract whose
		# copy changed (a loaded save, an edited description) still counts as taken, once.
		var twin := a.duplicate()
		var edited := {"name": "Bandits", "description": "Bandits [URGENT]"}
		var counts := [nb.open_contracts([a, twin], [{"mission": a}]), nb.open_contracts([a, twin], [{"mission": twin.duplicate()}]),
			nb.open_contracts([a, b], [{"mission": edited}]), nb.open_contracts([a], [{"mission": a}, {"mission": a.duplicate()}])]
		check(counts == [1, 1, 1, 0], "open_contracts: each taken contract claims one notice (twins, edited copies) %s" % [counts])
	var gd := _scene_nodes(DESK_SCENE_PATH) if ResourceLoader.exists(DESK_SCENE_PATH) else {}
	check(gd.has("DeskLight") and gd.DeskLight.type == "OmniLight3D"
		and gd.values().any(func(n): return n.type == "Marker3D" and "work_point" in n.groups),
		"GuildDesk.tscn has its DeskLight and a work_point marker (group work_point)")
	var nbs := _scene_nodes(NOTICE_SCENE_PATH) if ResourceLoader.exists(NOTICE_SCENE_PATH) else {}
	var root_groups: Array = nbs.get(".", {}).get("groups", [])
	check(nbs.values().any(func(n): return n.instance == BOARD_PATH) and "notice_board" in root_groups and not "mission_board" in root_groups,
		"GuildNoticeBoard.tscn: the B4 model, group notice_board, never the UI's mission_board group")

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var gone := tav.keys().filter(func(k): return OLD_DESK_NODES.any(func(p): return str(k).ends_with("TavernNavigation/" + p)))
	check(gone.is_empty(), "the old desk box, its chair and light, and the board box are gone %s" % [gone])
	var nav = null
	for k in tav:
		if str(k).ends_with("TavernNavigation"):
			nav = tav[k].props.get("navigation_mesh")
	for spec in [[DESK_SCENE_PATH, DESK_SPOT, "RecruitmentDesk", desk], [NOTICE_SCENE_PATH, BOARD_SPOT, "MissionBoard", board]]:
		var hits := tav.keys().filter(func(k): return tav[k].instance == spec[0])
		var placed: bool = hits.size() == 1 and (tav[hits[0]].world as Transform3D).origin.distance_to(spec[1]) < 0.05 \
			and (tav[hits[0]].world as Transform3D).basis.z.normalized().dot(Vector3.BACK) > 0.99
		check(placed, "MainTavern has %s at %s facing the room %s" % [str(spec[0]).get_file(), spec[1], hits])
		if not placed:
			continue
		var ip := Vector3.ZERO
		for k in spec[3]:
			if str(k).get_file() == "interact_point":
				ip = (tav[hits[0]].world as Transform3D) * (spec[3][k].world as Transform3D).origin
		var zone := AABB()
		for k in tav:
			if str(k).ends_with("Interactive/%s/CollisionShape3D" % spec[2]) and tav[k].props.get("shape") is BoxShape3D:
				var size: Vector3 = (tav[k].props.shape as BoxShape3D).size
				zone = (tav[k].world as Transform3D) * AABB(-size / 2, size)
		check(zone.has_point(ip + Vector3(0, 1.0, 0)) and nav is NavigationMesh and _nav_contains(nav, ip.x, ip.z),
			"the %s zone %s covers its interact point %s, which is on the navmesh" % [spec[2], zone, ip])
	check(nav is NavigationMesh and not _nav_contains(nav, DESK_SPOT.x, DESK_SPOT.z + 0.35), "navmesh: the desk front is solid")
	print("")


## Test 13, runtime part (review 2026-10-03; needs the autoloads): the hall's board recounts from the
## buses on a new day (a mission that resolves on a day without a contract refresh), on the morning
## briefing, on load and on reset (both emit day_changed), not only when the pool is refreshed.
func test_notice_board_live() -> void:
	print("[Test 13] The board recounts on a new day, the briefing, load and reset")
	var gm = root.get_node_or_null("GameManager")
	var gbus = root.get_node_or_null("GameBus")
	var abus = root.get_node_or_null("AdventurerBus")
	if gm == null or gbus == null or abus == null or not ResourceLoader.exists(NOTICE_SCENE_PATH):
		check(false, "GameManager, GameBus, AdventurerBus and GuildNoticeBoard.tscn present")
		return
	var saved_available: Array = gm.available_missions
	var saved_active: Array = gm.active_missions
	var a := {"name": "Wolves"}
	var b := {"name": "Bandits"}
	var c := {"name": "Rats"}
	gm.available_missions = [a, b, c]
	gm.active_missions = [{"mission": a, "days_remaining": 1}]
	var board: Node3D = (load(NOTICE_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(board)
	var seen := [board._notices.filter(func(n): return n.visible).size()]
	gm.active_missions = []                   # the party is back on a day with no new contracts
	gbus.day_changed.emit(int(gm.current_day))
	await process_frame
	seen.append(board._notices.filter(func(n): return n.visible).size())
	gm.available_missions = [a]
	gbus.morning_briefing_ready.emit([])
	await process_frame
	seen.append(board._notices.filter(func(n): return n.visible).size())
	gm.available_missions = [a, b]
	abus.missions_resolved.emit([])
	await process_frame
	seen.append(board._notices.filter(func(n): return n.visible).size())
	check(seen == [2, 3, 1, 2], "board notices: 2 open, 3 after a day change, 1 after the briefing, 2 after a resolution %s" % [seen])
	board.free()
	gm.available_missions = saved_available
	gm.active_missions = saved_active
	print("")


# --- Test 14: Mission payout = log line = morning report (playtest 2026-09-25) ---
# A solo run logged "earned 10 gold" while the Morning Briefing said 11: the loot roll's gold tier
# was paid after the SUCCESS line had been written. Drives GameManager._resolve_mission() and, per
# resolution, compares the gold GameManager actually gained, the amount in the SUCCESS line and the
# report's `reward` (what the briefing shows): solo, solo with the Lucky trait, and a party.
# Nothing here may reach user://: artifacts are emptied for the run (the artifact tier writes
# codex.dat), solo entries succeed at 100 %, and danger -3 puts the death chance at or below 0
# (a death writes codex.dat), checked with GameManager's own formula before any party is sent.
func test_mission_payout_report() -> void:
	print("[Test 14] Mission payout: gold paid = log line = morning report")
	var gm = root.get_node_or_null("GameManager")
	var dm = root.get_node_or_null("DataManager")
	var ss = root.get_node_or_null("SaveSystem")
	check(gm != null and dm != null and ss != null and not dm.character_traits.is_empty(),
		"GameManager, DataManager (data loaded) and SaveSystem are up")
	if gm == null or dm == null or ss == null:
		return
	var codex_before := [ss.codex_data.get("fallen_heroes", []).size(), ss.codex_data.get("artifacts_found", []).size()]
	var saved_artifacts: Dictionary = dm.artifacts
	dm.artifacts = {}
	var capture_script := GDScript.new()
	capture_script.source_code = "extends Node\nvar lines: Array[String] = []\nfunc log_message(m: String) -> void:\n\tlines.append(m)\n"
	capture_script.reload()
	var capture = Node.new()
	capture.name = "PayoutLogCapture"
	capture.set_script(capture_script)
	root.add_child(capture)
	current_scene = capture  # GameManager.log_message() forwards to current_scene.log_message()
	seed(20260925)

	var success_line := RegEx.create_from_string("^(PARTY )?SUCCESS!.* earned (\\d+) gold")
	var mission := {"name": "Payout Drill", "reward_range": [40, 40], "danger": -3, "category": "delivery"}
	var death_chance: float = gm.calculate_death_chance(1, mission.danger)
	check(death_chance <= 0.0, "fixture: danger %d gives a level-1 death chance <= 0 (%.2f)" % [mission.danger, death_chance])
	# [label, personality, least a success pays before loot: 40 base, 48 with Lucky's +20 %]
	for case in [["solo", "", 40], ["solo, Lucky", "lucky", 48], ["party of 2", "", 40]]:
		var party: bool = case[0].begins_with("party")
		if party and death_chance > 0.0:
			continue
		var runs := 12
		var report_ok := 0
		var log_ok := 0
		var successes := 0
		var looted := 0
		var short := 0
		for i in runs:
			var entry := {"mission": mission.duplicate(true), "total_duration": 1, "days_remaining": 0}
			if party:
				entry["is_party_mission"] = true
				entry["party"] = [_payout_adventurer("Ada", ""), _payout_adventurer("Bram", "")]
			else:
				entry["adventurer"] = _payout_adventurer("Cole", case[1])
				entry["success_chance"] = 100
			capture.lines.clear()
			var before: int = gm.gold
			var report: Dictionary = gm._resolve_mission(entry)
			var paid: int = gm.gold - before
			if int(report.get("reward", -1)) == paid:
				report_ok += 1
			var logged := []
			for line in capture.lines:
				var m := success_line.search(line)
				if m:
					logged.append(int(m.get_string(2)))
			if report.get("success", false):
				successes += 1
				if logged == [paid]:
					log_ok += 1
				if paid > case[2]:
					looted += 1
				elif paid < case[2]:
					short += 1
			elif logged.is_empty() and paid == 0:
				log_ok += 1
		check(report_ok == runs, "%s: report.reward == the gold actually paid (%d/%d runs)" % [case[0], report_ok, runs])
		check(log_ok == runs, "%s: the log's SUCCESS line names that same amount (%d/%d runs)" % [case[0], log_ok, runs])
		check(successes > 0 and looted > 0 and short == 0,
			"%s: every success paid at least %d; the loot roll's gold tier joined the reward in %d of %d successes"
			% [case[0], case[2], looted, successes])

	dm.artifacts = saved_artifacts
	current_scene = null
	capture.free()
	var codex_after := [ss.codex_data.get("fallen_heroes", []).size(), ss.codex_data.get("artifacts_found", []).size()]
	check(codex_after == codex_before, "codex untouched (fallen heroes, artifacts found: %s)" % [codex_after])
	print("")


static func _payout_adventurer(adv_name: String, personality: String) -> Dictionary:
	return {"name": adv_name, "id": adv_name.to_lower(), "class": "Fighter", "portrait": "", "personality": personality,
		"strength": 3, "dexterity": 3, "intelligence": 3, "endurance": 3, "status": AdventurerStatus.Status.ON_MISSION,
		"missions_completed": 0, "missions_failed": 0, "gold_earned": 0}


# --- Test 15: One class list, every class a body and a portrait (Story 25.9) ---
# D-3's six demo classes, identical across the four data files (no stray Cleric); every class
# model exists and carries the KayKit rig with the clips patrons and the player use; the new Healer
# and Ranger bodies pass the glow rule and hang their props from the right bone slots; every class
# resolves a portrait PNG; each class gets its recruit stat bonus; the Cleric gap is off the allowlist.
func test_class_roster() -> void:
	print("[Test 15] One class list, every class a body and a portrait")
	var want: Array = DEMO_CLASSES.duplicate()
	want.sort()
	var classes = _read_json(CLASSES_PATH)
	var cfg = _read_json(GAME_CONFIG_PATH)
	var colors = _read_json(CLASS_COLORS_PATH)
	var flavor = _read_json(FLAVOR_LINES_PATH)
	var lists := {
		"classes.json": classes.keys() if classes is Dictionary else [],
		"game_config adventurer_classes": cfg.get("adventurer_classes", []) if cfg is Dictionary else [],
		"class_colors.json": colors.get("classes", {}).keys() if colors is Dictionary else [],
		"flavor_lines.json": (flavor.get("lines", {}).keys() if flavor is Dictionary else []).map(func(k): return str(k).capitalize()),
	}
	for name in lists:
		var got: Array = Array(lists[name]).duplicate()
		got.sort()
		check(got == want, "%s lists exactly the six demo classes %s" % [name, got])

	for cls in DEMO_CLASSES:
		var path: String = str(classes.get(cls, {}).get("model_path", "")) if classes is Dictionary else ""
		var ok := path != "" and ResourceLoader.exists(path)
		var bones := 0
		var missing_clips := []
		if ok:
			var inst := (load(path) as PackedScene).instantiate()
			var sk := inst.find_children("*", "Skeleton3D", true, false)
			bones = (sk[0] as Skeleton3D).get_bone_count() if not sk.is_empty() else 0
			var ap := inst.find_children("*", "AnimationPlayer", true, false)
			var clips: PackedStringArray = (ap[0] as AnimationPlayer).get_animation_list() if not ap.is_empty() else PackedStringArray()
			missing_clips = CAST_CLIPS.filter(func(c): return not c in clips)
			inst.free()
		check(ok and bones >= 41 and missing_clips.is_empty(),
			"%s body %s: %d bones, clips missing %s" % [cls, path.get_file(), bones, missing_clips])

	for spec in [[HEALER_MODEL_PATH, {"Healer_Hood": "head", "Healer_Staff": "handslot.r"}],
			[RANGER_MODEL_PATH, {"Ranger_Bow": "handslot.l", "Ranger_Quiver": "chest"}]]:
		var ok := ResourceLoader.exists(spec[0])
		var st := _mesh_stats(spec[0]) if ok else {"tris": 0, "glow": 0, "wrong": ["missing"]}
		check(ok and st.tris > 0 and st.tris <= 7000 and st.wrong.is_empty(),
			"%s: %d tris (≤ 7,000), glow rule (wrong: %s)" % [str(spec[0]).get_file(), st.tris, st.wrong])
		var slots_ok := ok
		var found := {}
		var clip_n := 0
		if ok:
			var inst := (load(spec[0]) as PackedScene).instantiate()
			var sks := inst.find_children("*", "Skeleton3D", true, false)
			var sk := sks[0] as Skeleton3D if not sks.is_empty() else null   # no skeleton: fail, don't crash
			slots_ok = sk != null
			for prop in spec[1]:
				var b := sk.find_bone(prop) if sk else -1
				var parent := sk.get_bone_name(sk.get_bone_parent(b)) if b >= 0 and sk.get_bone_parent(b) >= 0 else ""
				found[prop] = parent
				if parent != spec[1][prop]:
					slots_ok = false
			var aps := inst.find_children("*", "AnimationPlayer", true, false)
			clip_n = (aps[0] as AnimationPlayer).get_animation_list().size() if not aps.is_empty() else 0
			inst.free()
		check(slots_ok, "%s props hang from their slots %s" % [str(spec[0]).get_file(), found])
		# Review 2026-10-03: the custom bodies carry all 76 KayKit clips (AC), and the Healer's staff crystal glows.
		check(clip_n >= 76, "%s carries all 76 KayKit clips (%d)" % [str(spec[0]).get_file(), clip_n])
		if spec[0] == HEALER_MODEL_PATH:
			check(st.glow >= 1, "healer.glb: the staff crystal glows (%d emissive surfaces)" % st.glow)
	var gm = load(GAME_MANAGER_PATH) as Script
	var has_bonus: bool = gm != null and gm.get_script_method_list().any(func(m): return m.name == "recruit_class_bonus")
	check(has_bonus and DEMO_CLASSES.all(func(c): return not gm.recruit_class_bonus(c).is_empty())
		and gm.recruit_class_bonus("Barbarian").get("strength", 0) == 3 and gm.recruit_class_bonus("Ranger").get("dexterity", 0) == 2
		and gm.recruit_class_bonus("Fighter") == {"strength": 2, "endurance": 1},
		"every class gets its recruit stat bonus (Fighter unchanged, Barbarian str +3, Ranger dex +2)")
	_check_class_review_fixes(gm)
	var no_portrait := DEMO_CLASSES.filter(func(c): return not ResourceLoader.exists("res://assets/portraits/%s.png" % str(c).to_lower()))
	check(no_portrait.is_empty(), "every class has a portrait PNG (missing: %s)" % [no_portrait])
	var allow := FileAccess.get_file_as_string(ASSET_ALLOWLIST_PATH)
	check(not allow.contains("Cleric.glb"), "the Cleric.glb gap is off the Test 5 allowlist")
	# Since Story 25.14 the pool comes from data/characters/townsfolk.json (decision E1: the class
	# bodies stay in it as travelling adventurers)
	var rp = load(PATRON_SCRIPT_PATH) as Script
	var has_pool: bool = rp != null and rp.get_script_method_list().any(func(m): return m.name == "townsfolk_pool")
	var entries: Array = rp.townsfolk_pool() if has_pool else []
	var pool: Array = entries.map(func(v): return str(v.get("model_path", "")))
	var class_w := 0.0
	var all_w := 0.0
	for v in entries:
		all_w += float(v.get("weight", 1.0))
		if str(v.get("role", "")) == "adventurer":
			class_w += float(v.get("weight", 1.0))
	check(HEALER_MODEL_PATH in pool and RANGER_MODEL_PATH in pool and pool.all(func(p): return ResourceLoader.exists(p))
		and all_w > 0.0 and class_w / all_w < 0.25,
		"the patron pool still seats Healers and Rangers, as a minority of travelling adventurers (%.0f%%), and every pool model exists"
		% (100.0 * class_w / maxf(all_w, 0.001)))
	print("")


## Review 2026-10-03 (Story 25.9): the hire pool survives an empty or malformed class list; the
## recruitment popup's Barbarian matches classes.json (int -1); old saves and the codex turn Cleric
## adventurers into Healers (SaveSystem's schema migration; the codex in memory only).
func _check_class_review_fixes(gm_script) -> void:
	var has_valid: bool = gm_script != null and gm_script.get_script_method_list().any(func(m): return m.name == "valid_class_list")
	check(has_valid, "GameManager.valid_class_list() exists")
	if has_valid:
		var good := ["Fighter", "Ranger"]
		var bad := [[], "Fighter", [1, null], ["Fighter", ""], null]
		var fell_back := true
		for v in bad:
			var got: Array = gm_script.valid_class_list(v)
			fell_back = fell_back and not got.is_empty() and got.all(func(c): return c is String and c != "")
		check(gm_script.valid_class_list(good) == good and fell_back,
			"adventurer_classes: a good list is kept, an empty / non-list / malformed one falls back to the defaults")

	var popup_script = load("res://scripts/ui/recruitment_popup.gd")
	var popup = popup_script.new() if popup_script else null
	var barbs := []
	if popup:
		for i in 600:
			var a: Dictionary = popup.create_adventurer()
			if a.get("class") == "Barbarian":
				barbs.append(a)
		popup.free()
	var int_range := [barbs.map(func(a): return int(a.intelligence)).min(), barbs.map(func(a): return int(a.intelligence)).max()] if not barbs.is_empty() else []
	check(barbs.size() >= 20 and barbs.all(func(a): return a.intelligence >= 0 and a.intelligence <= 5 and a.strength >= 4 and a.strength <= 9),
		"recruitment popup: Barbarian int 1d6 - 1, str 1d6 + 3, as classes.json (%d Barbarians, int %s)" % [barbs.size(), int_range])

	var ss = root.get_node_or_null("SaveSystem")
	var has_rename: bool = ss != null and ss.has_method("rename_classes")
	check(has_rename, "SaveSystem.rename_classes() exists")
	if not has_rename:
		return
	var old := {"schema_version": 1, "current_day": 3, "gold": 10, "beer_stock": 5,
		"adventurers": [{"name": "Ana", "class": "Cleric"}, {"name": "Bo", "class": "Rogue"}],
		"daily_recruits": [{"name": "Cy", "class": "Cleric"}],
		"active_missions": [{"adventurer": {"name": "Di", "class": "Cleric"}, "mission": {"name": "Wolves"}},
			{"party": [{"name": "Ed", "class": "Cleric"}, {"name": "Fa", "class": "Mage"}], "is_party_mission": true}],
		"pending_reports": [{"adventurer_class": "Cleric"}]}
	var out: Dictionary = ss._migrate_save_data(old)
	var flat := JSON.stringify(out)
	check(not flat.contains("Cleric") and flat.count("\"Healer\"") == 5 and flat.contains("\"Rogue\"") and flat.contains("\"Mage\"")
		and int(out.get("schema_version", 0)) >= 2,
		"old save: every Cleric (roster, recruits, missions, party, reports) becomes a Healer, schema v%s" % [out.get("schema_version")])
	var codex := {"fallen_heroes": [{"name": "Gil", "class": "Cleric"}, {"name": "Hal", "class": "Fighter"}]}
	var n: int = ss.rename_classes(codex)
	check(n == 1 and codex.fallen_heroes[0]["class"] == "Healer" and codex.fallen_heroes[1]["class"] == "Fighter",
		"codex: a fallen Cleric is remembered as a Healer (%d renamed)" % n)
	var live: Array = ss.codex_data.get("fallen_heroes", [])
	check(not live.any(func(h): return h is Dictionary and h.get("class") == "Cleric"),
		"the loaded codex holds no Cleric (migrated in memory on load)")


# --- Test 16: The townsfolk body kit, patrons by origin, villagers in town (Story 25.14) ---
# Six townsfolk variants on the KayKit rig, listed in data; patrons take a body whose origin type
# matches their origin, with adventurer bodies as a minority of travellers (decision E1, ~80 / 20);
# the hands stay free (patrons carry these bodies into the tavern); villagers stand or walk loops in
# town on the terrain, clear of the stream, buildings and street props, and bark the Villager's Voice
# (three weighted registers, in-world words only).
func test_townsfolk_kit() -> void:
	print("[Test 16] Townsfolk body kit, patrons by origin, villagers in town")
	var tf = _read_json(TOWNSFOLK_PATH)
	var has_data: bool = tf is Dictionary and tf.get("variants", null) is Array
	check(has_data, "townsfolk.json is readable, with a variants list")
	var variants: Array = tf.variants if has_data else []
	var ids := variants.map(func(v): return str(v.get("id", "")))
	var townsfolk := variants.filter(func(v): return str(v.get("role", "")) == "townsfolk")
	for role in TOWNSFOLK_ROLES:
		check(townsfolk.any(func(v): return v.get("id", "") == role), "townsfolk variant '%s' is listed" % role)
	for t in PATRON_ORIGIN_TYPES:
		check(townsfolk.any(func(v): return v.get("origin_type", "") == t), "a townsfolk variant covers patron origin '%s'" % t)
	var plines = _read_json(PATRON_LINES_PATH)
	var flavours: Array = plines.get("origin_flavor", {}).keys() if plines is Dictionary else []
	check(not flavours.is_empty() and flavours.all(func(k): return k in PATRON_ORIGIN_TYPES),
		"patron_lines' origin flavours are all patron origin types %s" % [flavours])
	var pools: Dictionary = tf.get("names", {}) if has_data else {}
	check(has_data and variants.all(func(v): return str(v.get("names", "any")) == "any" or pools.has(str(v.names))),
		"every variant's name pool exists %s" % [pools.keys()])
	var old := variants.filter(func(v): return v.get("id", "") == "old_woman")
	check(not old.is_empty() and str(old[0].get("names", "")) == "feminine", "the old woman draws feminine names")
	check(has_data and variants.all(func(v): return v.has("weight") and float(v.weight) > 0.0),
		"every variant has a positive weight (the game reads a missing one as 1)")
	check(has_data and variants.all(func(v): return str(v.get("origin_type", "")) in PATRON_ORIGIN_TYPES),
		"every variant's origin_type is a patron origin %s" % [PATRON_ORIGIN_TYPES])
	var travellers := variants.filter(func(v): return v.get("origin_type", "") == "traveler")
	var trav_w := 0.0
	var trav_body_w := 0.0
	for v in travellers:
		trav_w += float(v.get("weight", 0))
		if str(v.get("role", "")) == "townsfolk":
			trav_body_w += float(v.get("weight", 0))
	check(trav_w > 0.0 and trav_body_w / trav_w > 0.5, "the traveller body leads the travellers (%.2f)" % (trav_body_w / maxf(trav_w, 0.001)))
	var total := 0.0
	var tf_weight := 0.0
	for v in variants:
		total += float(v.get("weight", 0))
		if str(v.get("role", "")) == "townsfolk":
			tf_weight += float(v.get("weight", 0))
	var share := tf_weight / total if total > 0.0 else 0.0
	check(share >= 0.75 and share <= 0.85, "townsfolk take about 80%% of the patron weight (%.2f)" % share)
	var adventurers := variants.filter(func(v): return str(v.get("role", "")) == "adventurer")
	check(not adventurers.is_empty() and adventurers.all(func(v): return v.get("origin_type", "") == "traveler"),
		"adventurer bodies come only as travellers (%d)" % adventurers.size())
	check([HEALER_MODEL_PATH, RANGER_MODEL_PATH].all(func(p): return adventurers.any(func(v): return v.get("model_path", "") == p)),
		"the Healer and the Ranger still visit, as travelling adventurers (25.9's C4)")
	check(variants.all(func(v): return ResourceLoader.exists(str(v.get("model_path", "")))), "every pool model exists")

	# Story 25.31 S2 (AC 11/12, V11, V12): the townsfolk are route RL's realistic bodies, checked on the RL rules by
	# Test 19's GLB checker (the KayKit rig, the cast's 76 clips with the patrons' loops, none of the staff's clips, one
	# <Role>_Body of <= 3 surfaces with the head projection, <= 2 textures at <= 1024² Lossless with mipmaps, no LODs,
	# <= 10,000 tris with props, no glow, no metal, a top in 1.50-2.25); their fallbacks are the Story 25.14 KayKit-kit
	# GLBs (still on disk, the old rules); hands empty (R-9 refined): no prop on a hand slot except the old woman's cane,
	# which the game hides (RealisticPatron.dress_body); the merchant's purse is worn on hips.
	for v in townsfolk:
		var id := str(v.get("id", ""))
		var path := str(v.get("model_path", ""))
		var prefix: String = str(TOWNSFOLK_PREFIX.get(id, "?")) + "_"
		var props: Array = TOWNSFOLK_PROPS.get(id, [])
		check(str(v.get("look", "")) == "realistic" and path == "res://assets/characters/custom/g19_%s_real.glb" % id,
			"%s: its realistic body g19_%s_real.glb, look realistic (%s, %s)" % [id, id, path.get_file(), v.get("look", "")])
		_check_staff_glb(path, [[], prefix, props, [], STAFF_CLIPS, CAST_LOOPS, CAST_ONE_SHOTS, RL_TRI_BUDGET, RL_BODY_SURFACES, "realistic"])
		var fb := str(v.get("fallback_model_path", ""))
		var fb_ok := fb == "res://assets/characters/custom/townsfolk_%s.glb" % id and ResourceLoader.exists(fb)
		var fbones := 0
		var fmissing := ["missing"]
		if fb_ok:
			var finst := (load(fb) as PackedScene).instantiate()
			var fsks := finst.find_children("*", "Skeleton3D", true, false)
			fbones = (fsks[0] as Skeleton3D).get_bone_count() if not fsks.is_empty() else 0
			var faps := finst.find_children("*", "AnimationPlayer", true, false)
			var fclips: PackedStringArray = (faps[0] as AnimationPlayer).get_animation_list() if not faps.is_empty() else PackedStringArray()
			fmissing = CAST_CLIPS.filter(func(c): return not c in fclips)
			finst.free()
		var fst := _mesh_stats(fb) if fb_ok else {"tris": 0, "wrong": ["missing"]}
		check(fb_ok and fbones >= 41 and fmissing.is_empty() and fst.tris > 0 and fst.tris <= 7000 and fst.wrong.is_empty(),
			"%s's fallback is its Story 25.14 body %s (%d bones, %d tris, clips missing %s)" % [id, fb.get_file(), fbones, fst.tris, fmissing])
		for k in ["walk_ground_speed", "run_ground_speed", "head_top", "sit_head_top", "tankard_scale"]:
			var n = v.get(k)
			if not ((n is float or n is int) and float(n) > 0.0):
				check(false, "%s: townsfolk.json %s is a positive number (%s)" % [id, k, n])
		check(absf(float(v.get("walk_ground_speed", 0.0)) - float(TOWNSFOLK_GROUND.get(id, [0, 0])[0])) < 0.005
			and absf(float(v.get("run_ground_speed", 0.0)) - float(TOWNSFOLK_GROUND.get(id, [0, 0])[1])) < 0.005,
			"%s: walk / run ground speeds %.3f / %.3f are the measured ones (real_townsfolk.measure)" % [id, float(v.get("walk_ground_speed", 0.0)), float(v.get("run_ground_speed", 0.0))])
		# hands empty: the props on the hand slots, and what the game shows of them on its own body
		var RPS = load(PATRON_SCRIPT_PATH)
		var hand := []
		var shown := []
		var purse_on_hips := id != "merchant"
		if ResourceLoader.exists(path):
			var inst := (load(path) as PackedScene).instantiate()
			var sks := inst.find_children("*", "Skeleton3D", true, false)
			var hp: Array = RPS.hand_props(inst)
			for a in hp:
				hand.append(str(a.find_children("*", "MeshInstance3D", true, false).map(func(m): return str(m.name))))
			RPS.dress_body(inst, v, false)
			shown = hp.filter(func(a): return (a as Node3D).visible).map(func(a): return str((a as BoneAttachment3D).bone_name))
			if id == "merchant" and not sks.is_empty():
				var sk := sks[0] as Skeleton3D
				for a in inst.find_children("*", "BoneAttachment3D", true, false):
					var bi := sk.find_bone(str((a as BoneAttachment3D).bone_name))
					var par := sk.get_bone_parent(bi) if bi >= 0 else -1
					var on_bone := sk.get_bone_name(par) if par >= 0 and str((a as BoneAttachment3D).bone_name).begins_with("Merchant_") else str((a as BoneAttachment3D).bone_name)
					if on_bone == "hips" and (a as Node3D).visible and a.find_child("Merchant_Purse", true, false) != null:
						purse_on_hips = true
			inst.free()
		var want_hand := ["[\"OldWoman_Cane\"]"] if id == "old_woman" else []
		check(hand == want_hand and shown.is_empty() and purse_on_hips,
			"%s keeps its hands free: hand-slot props %s (only the old woman's cane), shown by the game %s (none), the purse worn on hips %s" % [id, hand, shown, purse_on_hips])

	var rp = load(PATRON_SCRIPT_PATH) as Script
	var has_api: bool = rp != null and ["townsfolk_pool", "pick_variant"].all(func(m): return rp.get_script_method_list().any(func(x): return x.name == m))
	check(has_api, "RealisticPatron.townsfolk_pool() and pick_variant() exist")
	if has_api:
		var pool: Array = rp.townsfolk_pool()
		check(pool.map(func(v): return str(v.get("id", ""))) == ids, "the patron pool is townsfolk.json's variants")
		var keeps := true
		for t in PATRON_ORIGIN_TYPES:
			for roll in [0.0, 0.5, 0.999]:
				if rp.pick_variant(pool, t, roll).get("origin_type", "") != t:
					keeps = false
		check(keeps, "pick_variant keeps the origin type (rolls 0, 0.5, 0.999)")
		check(not rp.pick_variant(pool, "dragon", 0.5).is_empty(), "an unknown origin still yields a body")
		var pool_w := 0.0
		for v in pool:
			pool_w += float(v.get("weight", 1.0))
		var edge := float(pool[0].get("weight", 1.0)) / pool_w if pool.size() >= 2 and pool_w > 0.0 else 0.5
		check(pool.size() >= 2 and rp.pick_variant(pool, "", 0.0) == pool[0] and rp.pick_variant(pool, "", 0.999) == pool[-1]
			and rp.pick_variant(pool, "", edge - 0.001) == pool[0] and rp.pick_variant(pool, "", edge + 0.001) == pool[1],
			"an empty origin picks across the whole pool by weight (the first entry ends at roll %.3f)" % edge)
		var zero := [{"id": "a", "weight": 0}, {"id": "b", "weight": 0}]
		check(rp.pick_variant(zero, "", 0.2).get("id") == "a" and rp.pick_variant(zero, "", 0.8).get("id") == "b",
			"all-zero weights pick evenly")

	var barks = _read_json(VILLAGER_BARKS_PATH)
	var regs: Dictionary = barks.get("registers", {}) if barks is Dictionary else {}
	for r in BARK_REGISTERS:
		var reg: Dictionary = regs.get(r, {})
		var ls: Array = reg.get("lines", [])
		check(float(reg.get("weight", 0)) > 0.0 and ls.size() >= 4, "bark register '%s': weight %s, %d lines" % [r, reg.get("weight", 0), ls.size()])
		var bad_lines := ls.filter(func(l): return str(l).length() > 110 or BANNED_BARK_WORDS.any(func(w): return str(l).to_lower().contains(w)))
		check(bad_lines.is_empty(), "'%s' lines stay short and in-world %s" % [r, bad_lines])
	var vs = load(VILLAGER_SCRIPT_PATH) as Script if ResourceLoader.exists(VILLAGER_SCRIPT_PATH) else null
	var vapi: bool = vs != null and ["pick_bark", "step_toward"].all(func(m): return vs.get_script_method_list().any(func(x): return x.name == m))
	check(vapi, "villager.gd has pick_bark() and step_toward()")
	var regs_ok := regs.has_all(BARK_REGISTERS)
	check(regs_ok, "villager_barks has the three registers %s" % [BARK_REGISTERS])
	if vapi and regs_ok:
		check(str(vs.pick_bark(barks, 0.0, 0.0)) in regs["grievance"]["lines"] and str(vs.pick_bark(barks, 0.999, 0.0)) in regs["paranoia"]["lines"],
			"pick_bark: a low roll grumbles, a high roll turns paranoid")
		var p1: Vector3 = vs.step_toward(Vector3(0, 5, 0), Vector3(3, 0, 4), 1.0, 1.0)
		var p2: Vector3 = vs.step_toward(Vector3(0, 5, 0), Vector3(3, 0, 4), 10.0, 1.0)
		check(p1.is_equal_approx(Vector3(0.6, 5, 0.8)) and p2.is_equal_approx(Vector3(3, 5, 4)),
			"step_toward walks speed × dt in XZ, keeps y and never overshoots (%s, %s)" % [p1, p2])

	var hf = _read_json(HEIGHTFIELD_FIXTURE)
	var ext := _scene_nodes(EXTERIOR_SCENE_PATH)
	var vill := ext.keys().filter(func(k): return str(k).begins_with("Villagers/") and str(k).count("/") == 1 and ext[k].instance == VILLAGER_SCENE_PATH)
	check(vill.size() >= 4 and vill.size() <= 8, "ExteriorWorld has %d villagers (4–8)" % vill.size())
	var buildings := []
	var street := []
	for k in ext:
		var key := str(k)
		if key.begins_with("Village/") and key.count("/") == 1 and ext[k].instance.contains("/blue/"):
			buildings.append((ext[k].world as Transform3D).origin)
		elif key.begins_with("Village/Street/") and key.count("/") == 2:
			street.append([(ext[k].world as Transform3D).origin, 2.0 if key.get_file().begins_with("StallTent") else 1.0])
	var problems := []
	var used := []
	var walkers := 0
	if hf is Dictionary:
		for k in vill:
			var n: Dictionary = ext[k]
			var vid := str(n.props.get("variant_id", ""))
			used.append(vid)
			if not vid in ids:
				problems.append("%s: unknown variant '%s'" % [k, vid])
			var o: Vector3 = (n.world as Transform3D).origin
			var ground := _hf_height(hf, o.x, o.z)
			if o.y - ground > 0.15 or ground - o.y > 0.35:
				problems.append("%s y=%.2f ground=%.2f" % [k, o.y, ground])
			var pts := [Vector2(o.x, o.z)]
			var wps: PackedVector3Array = n.props.get("waypoints", PackedVector3Array())
			if wps.size() >= 2:
				walkers += 1
				for i in wps.size():
					var a := Vector2(wps[i].x, wps[i].z)
					var b := Vector2(wps[(i + 1) % wps.size()].x, wps[(i + 1) % wps.size()].z)
					var steps := maxi(int(ceil(a.distance_to(b) / 0.5)), 1)
					for t in steps:
						pts.append(a.lerp(b, float(t) / steps))
			for p in pts:
				var why := _villager_spot_problem(hf, p, buildings, street)
				if why != "":
					problems.append("%s at (%.1f, %.1f): %s" % [k, p.x, p.y, why])
	check(hf is Dictionary and problems.is_empty(), "villagers stand and walk on clear ground %s" % [problems.slice(0, 4)])
	check(TOWNSFOLK_ROLES.all(func(r): return r in used), "one of each townsfolk variant lives in town (E2) %s" % [used])
	check(walkers >= 2, "%d villagers walk loops (≥ 2)" % walkers)

	# Village-life playtest polish (2026-09-25): less repetition, room to breathe, no walking through
	# each other, someone on the road by the tavern, names that fit the faces.
	var amb: Dictionary = plines.get("ambient", {}) if plines is Dictionary else {}
	var thin := (PATRON_ORIGIN_TYPES + ["default"]).filter(func(k): return (amb.get(k, []) as Array).size() < 8)
	check(thin.is_empty(), "patron chatter has 8+ lines per origin (thin: %s)" % [thin])
	var has_fresh: bool = rp != null and rp.get_script_method_list().any(func(m): return m.name == "fresh_line")
	check(has_fresh and rp.fresh_line(["a", "b", "c"], ["a"], 0.0) == "b" and rp.fresh_line(["a", "b", "c"], ["b", "c"], 0.5) == "a"
		and rp.fresh_line(["a", "b"], ["a", "b"], 0.0) == "a" and rp.fresh_line([], [], 0.3) == "",
		"fresh_line skips recently said lines (and falls back when all are recent)")
	if vapi and regs_ok:
		var first: String = str(regs["grievance"]["lines"][0])
		var again := str(vs.pick_bark(barks, 0.0, 0.0, [first]))
		check(again != first and again in regs["grievance"]["lines"], "pick_bark avoids a line just said (%s)" % again)
	var vconst: Dictionary = vs.get_script_constant_map() if vs != null else {}
	var gap = vconst.get("QUIET_GAP", null)
	check(gap is Vector2 and gap.x >= 3.0 and gap.y >= gap.x, "villagers leave a quiet gap after each bark (%s s)" % [gap])
	check(variants.filter(func(v): return v.get("id", "") in ["farmer", "local", "traveller", "guard", "merchant"]).all(func(v): return str(v.get("names", "")) == "masculine"),
		"the farmer, the local, the traveller, the guard and the merchant (the men of their picks) draw masculine names")
	var door := Vector2(-20.65, 10.0)   # TavernEntranceZone
	var near_door := false
	var paths := {}   # villager -> sampled path points (a post is a single point)
	for k in vill:
		var n: Dictionary = ext[k]
		var o: Vector3 = (n.world as Transform3D).origin
		var wps: PackedVector3Array = n.props.get("waypoints", PackedVector3Array())
		var samples := [Vector2(o.x, o.z)]
		for i in wps.size():
			var a := Vector2(wps[i].x, wps[i].z)
			var b := Vector2(wps[(i + 1) % wps.size()].x, wps[(i + 1) % wps.size()].z)
			if a.distance_to(door) < 8.0:
				near_door = true
			var steps := maxi(int(ceil(a.distance_to(b) / 0.5)), 1)
			for t in steps:
				samples.append(a.lerp(b, float(t) / steps))
		paths[k] = samples if wps.size() >= 2 else [Vector2(o.x, o.z)]
	check(near_door, "someone walks the road up to the tavern door")
	var crossings := []
	var keys := paths.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var best := 99.0
			for pa in paths[keys[i]]:
				for pb in paths[keys[j]]:
					best = minf(best, (pa as Vector2).distance_to(pb))
			if best < 1.0:
				crossings.append("%s/%s %.2f m" % [str(keys[i]).get_file(), str(keys[j]).get_file(), best])
	check(crossings.is_empty(), "villagers' paths keep 1 m apart, so nobody walks through anybody %s" % [crossings])
	print("")


## Test 16, runtime part (Story 25.31 S2, AC 12, V11, AH-7): the look gate for patrons and villagers (on its own
## body: the toon look, the hand-slot props hidden, the clip rate from the measured ground speed; on the fallback: none
## of it), an old save's KayKit townsfolk path re-picked by origin type, the patron's stool lift and the bubble heights.
func test_townsfolk_runtime() -> void:
	print("[Test 16] The realistic townsfolk at runtime: look gate, fallback, old saves, rates, bubbles")
	var world := Node3D.new()
	root.add_child(world)
	var RPS = load(PATRON_SCRIPT_PATH)
	var pool: Array = RPS.townsfolk_pool()
	var by_id := {}
	for v in pool:
		by_id[str(v.get("id", ""))] = v
	var p = (load("res://scenes/npcs/RealisticPatron.tscn") as PackedScene).instantiate()
	p.set_physics_process(false)
	world.add_child(p)
	await process_frame
	var why := []
	for id in TOWNSFOLK_ROLES:
		var v: Dictionary = by_id.get(id, {})
		p._swap_to_model(str(v.get("model_path", "")), v)
		var toned := 0
		for mi in p.patron_body_mesh.find_children("*", "MeshInstance3D", true, false):
			for s in ((mi as MeshInstance3D).mesh.get_surface_count() if (mi as MeshInstance3D).mesh else 0):
				var m = (mi as MeshInstance3D).get_surface_override_material(s)
				if m is Material and (m as Material).has_meta(&"anime_toon"):
					toned += 1
		var want_rate: float = RPS.SPEED / float(v.get("run_ground_speed", 1.0))
		var shown: Array = RPS.hand_props(p.patron_body_mesh).filter(func(a): return (a as Node3D).visible)
		if p.using_fallback or p.body_look != "realistic" or toned < 2 or absf(p.run_rate - want_rate) > 0.001 or not shown.is_empty() \
				or p.current_model_path != str(v.get("model_path", "")) or absf(p.tankard_scale - float(v.get("tankard_scale", 0.0))) > 0.001:
			why.append("%s: fallback %s look '%s' toned %d rate %.3f/%.3f shown %d" % [id, p.using_fallback, p.body_look, toned, p.run_rate, want_rate, shown.size()])
	check(why.is_empty(), "patrons: each realistic townsperson on its own body: toon look, hands empty, Running_A at SPEED / its ground speed, its tankard size %s" % [why])
	# the fallback: a missing model loads the entry's fallback, keeps its imported look and plays at 1.0; the save keeps
	# the entry's model_path (V11)
	var broken := (by_id.get("guard", {}) as Dictionary).duplicate()
	broken["model_path"] = "res://assets/characters/custom/__missing_g19_guard.glb"
	p._swap_to_model(str(broken.model_path), broken)
	check(p.using_fallback and p.body_path == str(broken.get("fallback_model_path", "")) and p.body_look == "" and p.run_rate == 1.0
		and p.current_model_path == str(broken.model_path) and absf(p.tankard_scale - RPS.TANKARD_HELD_SCALE) < 0.001,
		"patrons: a missing model loads its fallback %s with its own look, rate 1.0, the KayKit tankard size; the save keeps the entry's path" % p.body_path.get_file())
	# AH-7: an old save's body that is no longer in the pool (the KayKit townsfolk guard, still on disk) re-picks by origin
	var save := {"position": [0.0, 0.0, 0.0], "state": RPS.PatronState.SEATED, "name": "Bram Cooper", "origin": "the old keep",
		"origin_type": "soldier", "payment": 8, "model_path": "res://assets/characters/custom/townsfolk_guard.glb"}
	p.restore_from_save(save, Vector3.ZERO, Vector3.ZERO, 0, null)
	check(p.current_model_path == str(by_id.get("guard", {}).get("model_path", "")) and not p.using_fallback and p.body_look == "realistic",
		"old saves (AH-7): a saved KayKit guard (not in the pool any more) comes back as the realistic guard (%s)" % p.current_model_path.get_file())
	# seated on a stool: the body lifted, the bubble over the measured seated head
	p.seat_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.1 + RPS.BAR_STOOL_SEAT, 0))
	p._settle_on_seat(false)
	var want_b: float = float(by_id.guard.sit_head_top) + RPS.SIT_LIFT + RPS.BUBBLE_GAP
	check(absf(p.patron_body_mesh.position.y - RPS.SIT_LIFT) < 0.001 and absf(p.seated_head_height(RPS.BUBBLE_GAP, 0.0) - want_b) < 0.001,
		"patrons on a stool: the body rides up %.2f m, the bubble at %.2f m over the root (the seated head + the lift + %.2f)" % [p.patron_body_mesh.position.y, want_b, RPS.BUBBLE_GAP])
	p.queue_free()
	# villagers: the same gate; Walking_A at walk_speed / walk_ground_speed; the bubble over the standing head
	why = []
	var vscene := load(VILLAGER_SCENE_PATH) as PackedScene
	for id in TOWNSFOLK_ROLES:
		var vil = vscene.instantiate()
		vil.variant_id = id
		vil.set_physics_process(false)
		world.add_child(vil)
		var v: Dictionary = by_id.get(id, {})
		var want_walk: float = vil.walk_speed / float(v.get("walk_ground_speed", 1.0))
		var vc: Dictionary = (vil.get_script() as Script).get_script_constant_map()
		var want_lift: float = float(v.get("head_top", 0.0)) + float(vc.get("BUBBLE_GAP", 0.0)) - PatronSpeechBubble.HEAD_HEIGHT * float(vc.get("BUBBLE_SCALE", 1.0))
		var shown: Array = RPS.hand_props(vil._model).filter(func(a): return (a as Node3D).visible) if vil._model else ["no body"]
		if vil.using_fallback or vil.body_look != "realistic" or absf(vil.walk_rate - want_walk) > 0.001 or not shown.is_empty() \
				or absf(vil.bubble_lift() - want_lift) > 0.001:
			why.append("%s: fallback %s look '%s' rate %.3f/%.3f shown %d lift %.2f" % [id, vil.using_fallback, vil.body_look, vil.walk_rate, want_walk, shown.size(), vil.bubble_lift()])
		vil.queue_free()
	check(why.is_empty(), "villagers: each on its own realistic body, hands empty, Walking_A at walk_speed / its ground speed, the bubble over its head %s" % [why])
	world.queue_free()
	await process_frame
	print("")


## Where a villager may not stand or step: outside the play area, in the stream, inside a building
## (within 2.5 m of its origin, as Test 9's trees), or on a street prop (props = [origin, radius]:
## 1 m, 2 m for a stall tent). The bridge deck is fine: it's how you cross the stream.
static func _villager_spot_problem(hf: Dictionary, p: Vector2, buildings: Array, props: Array) -> String:
	var play: Array = hf.play
	if p.x < float(play[0]) or p.x > float(play[1]) or p.y < float(play[2]) or p.y > float(play[3]):
		return "outside the play area"
	var br: Dictionary = hf.get("bridge", {})
	var on_bridge: bool = not br.is_empty() and p.x >= float(br.x0) and p.x <= float(br.x1) and absf(p.y - float(br.z)) <= float(br.width) / 2.0
	if not on_bridge and absf(p.x - _hf_stream_x(hf, p.y)) < float(hf.stream_half) + 0.5:
		return "in the stream"
	for b in buildings:
		if Vector2(b.x, b.z).distance_to(p) < 2.5:
			return "inside a building"
	for q in props:
		if Vector2(q[0].x, q[0].z).distance_to(p) < float(q[1]):
			return "on a street prop"
	return ""


# --- Test 17: The Cat (Story 25.15) ---
# One cat on her own small rig with three looping clips and a one-shot Pet; pettable (decision F0:
# a small script and a PetZone, still no autoload, no name, no story entry); asleep in a basket by
# the hearth, where tending the fire puts you beside her, without her zone overlapping another E
# zone; in town, a baked stroll that stays on clear ground and away from the villagers' paths.
func test_the_cat() -> void:
	print("[Test 17] The Cat")
	for p in [CAT_PATH, CAT_BASKET_PATH, CAT_SCENE_PATH, CAT_SCRIPT_PATH]:
		check(ResourceLoader.exists(p), "exists: %s" % p.get_file())
	if ResourceLoader.exists(CAT_PATH):
		var inst := (load(CAT_PATH) as PackedScene).instantiate()
		var sks := inst.find_children("*", "Skeleton3D", true, false)
		var bones: int = (sks[0] as Skeleton3D).get_bone_count() if not sks.is_empty() else 0
		var aps := inst.find_children("*", "AnimationPlayer", true, false)
		var ap: AnimationPlayer = aps[0] if not aps.is_empty() else null
		var loops := []
		for clip in CAT_LOOPS:
			if ap == null or not ap.has_animation(clip) or ap.get_animation(clip).loop_mode != Animation.LOOP_LINEAR:
				loops.append(clip)
		check(bones >= 10 and loops.is_empty(), "her rig (%d bones) and looping clips (not looping or missing: %s)" % [bones, loops])
		check(ap != null and ap.has_animation("Pet") and ap.get_animation("Pet").loop_mode == Animation.LOOP_NONE,
			"a one-shot Pet clip")
		inst.free()
		var st := _mesh_stats(CAT_PATH)
		check(st.tris > 0 and st.tris <= 1500 and st.wrong.is_empty() and st.glow == 0,
			"g11_the_cat.glb: %d tris (≤ 1,500), nothing glows, roughness > 0 (wrong: %s)" % [st.tris, st.wrong])

	var cat := _scene_nodes(CAT_SCENE_PATH) if ResourceLoader.exists(CAT_SCENE_PATH) else {}
	var root_script = cat.get(".", {}).get("props", {}).get("script", null) if cat.has(".") else null
	var zone_r := 0.0
	var zone_off := Vector3.ZERO
	for k in cat:
		if str(k).begins_with("PetZone/") and cat[k].props.get("shape") is SphereShape3D:
			zone_r = (cat[k].props.shape as SphereShape3D).radius
			zone_off = (cat[k].world as Transform3D).origin
	check(root_script is Script and (root_script as Script).resource_path == CAT_SCRIPT_PATH, "TheCat.tscn runs the_cat.gd")
	check(cat.has("PetZone") and cat.PetZone.type == "Area3D" and zone_r > 0.3 and zone_r <= 1.2, "a PetZone (sphere, r %.2f m)" % zone_r)
	var anim_node := cat.keys().filter(func(k): return cat[k].type == "AnimationPlayer" or str(k).get_file() == "AnimationPlayer")
	check(not anim_node.is_empty() and str(cat[anim_node[0]].props.get("autoplay", "")) == "Sleep", "she sleeps unless something says otherwise (autoplay Sleep)")
	var project := FileAccess.get_file_as_string("res://project.godot")
	var autoloads := project.substr(project.find("[autoload]"), 2000) if project.find("[autoload]") >= 0 else ""
	autoloads = autoloads.substr(0, autoloads.find("\n[", 2)) if autoloads.find("\n[", 2) > 0 else autoloads
	check(not autoloads.contains("the_cat") and not autoloads.contains("TheCat"), "no autoload for the cat (AR D11)")   # not "cat": NotificationManager
	var cs = load(CAT_SCRIPT_PATH) as Script if ResourceLoader.exists(CAT_SCRIPT_PATH) else null
	var has_reaction: bool = cs != null and cs.get_script_method_list().any(func(m): return m.name == "reaction")
	var chance = cs.get_script_constant_map().get("PURR_CHANCE", -1.0) if cs != null else -1.0
	check(has_reaction and chance > 0.5 and chance < 0.95 and cs.reaction(0.0) == "purr" and cs.reaction(chance - 0.01) == "purr"
		and cs.reaction(chance + 0.01) == "mrrp" and cs.reaction(0.999) == "mrrp",
		"usually a purr, sometimes 'mrrp' (PURR_CHANCE %s)" % [chance])

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var cats := tav.keys().filter(func(k): return tav[k].instance == CAT_SCENE_PATH)
	check(cats.size() == 1, "one cat in the tavern (%d)" % cats.size())
	if cats.size() == 1:
		var o: Vector3 = (tav[cats[0]].world as Transform3D).origin
		var d := Vector2(o.x, o.z).distance_to(Vector2(HEARTH_INTERACT.x, HEARTH_INTERACT.z))
		check(d <= 2.5, "she sleeps by the hearth, %.2f m from where the fire is tended" % d)
		var baskets := []
		for k in tav:
			var bo: Vector3 = (tav[k].world as Transform3D).origin
			if tav[k].instance == CAT_BASKET_PATH and Vector2(bo.x, bo.z).distance_to(Vector2(o.x, o.z)) < 0.35:
				baskets.append(k)
		check(baskets.size() == 1, "in her basket (B20)")
		var overrides := tav.keys().filter(func(k): return str(k) == str(cats[0]) + "/AnimationPlayer")
		check(overrides.is_empty() or str(tav[overrides[0]].props.get("autoplay", "Sleep")) == "Sleep",
			"the tavern doesn't override her Sleep")
		var centre := o + (tav[cats[0]].world as Transform3D).basis * zone_off
		var clashes := []
		for k in tav:
			var key := str(k)
			if not key.contains("TavernNavigation/Interactive/") or tav[k].type != "CollisionShape3D":
				continue
			var w: Transform3D = tav[k].world
			var shape = tav[k].props.get("shape")
			var gap := -1.0    # a shape this check can't measure counts as a clash
			if shape is BoxShape3D:     # nearest point on the (rotated, scaled) box, found in its own frame
				var h: Vector3 = (shape as BoxShape3D).size / 2.0
				gap = centre.distance_to(w * (w.affine_inverse() * centre).clamp(-h, h))
			elif shape is SphereShape3D:
				gap = centre.distance_to(w.origin) - shape.radius * w.basis.x.length()
			if gap < zone_r:
				clashes.append(key.get_slice("/", key.get_slice_count("/") - 2))
		# Zones can't overlap; a player's body can still stand in both (the fire's is a step away), so
		# test_the_cat_yields() checks that she then leaves E to the other zone.
		check(clashes.is_empty(), "her PetZone overlaps no other E zone (overlaps: %s)" % [clashes])

	var ext := _scene_nodes(EXTERIOR_SCENE_PATH)
	var town_cats := ext.keys().filter(func(k): return ext[k].instance == CAT_SCENE_PATH)
	check(town_cats.size() == 1, "one cat in town (%d)" % town_cats.size())
	var hf = _read_json(HEIGHTFIELD_FIXTURE)
	var keys_pts := []
	for k in ext:
		if ext[k].type == "AnimationPlayer" and str(k).get_base_dir() == "CatStroll":
			var libs = ext[k].props.get("libraries", {})
			var lib = libs.get("", null) if libs is Dictionary else null
			var anim: Animation = lib.get_animation("Stroll") if lib is AnimationLibrary and lib.has_animation("Stroll") else null
			check(anim != null and anim.loop_mode == Animation.LOOP_LINEAR and str(ext[k].props.get("autoplay", "")) == "Stroll",
				"CatStroll plays a looping Stroll on its own")
			if anim != null:
				var base: Transform3D = ext["CatStroll"].world if ext.has("CatStroll") else Transform3D.IDENTITY
				for t in anim.get_track_count():
					if str(anim.track_get_path(t)).ends_with(":position"):
						for i in anim.track_get_key_count(t):
							keys_pts.append(base * (anim.track_get_key_value(t, i) as Vector3))
	check(keys_pts.size() >= 3, "her stroll has %d position keys" % keys_pts.size())
	var buildings := []
	var street := []
	for k in ext:
		var key := str(k)
		if key.begins_with("Village/") and key.count("/") == 1 and ext[k].instance.contains("/blue/"):
			buildings.append((ext[k].world as Transform3D).origin)
		elif key.begins_with("Village/Street/") and key.count("/") == 2:
			street.append([(ext[k].world as Transform3D).origin, 2.0 if key.get_file().begins_with("StallTent") else 1.0])
	var villager_pts := _villager_path_points(ext)
	var bad := []
	var walked := []      # every key, plus points every 0.25 m along the legs she walks between them
	for i in keys_pts.size():
		walked.append(keys_pts[i])
		if i + 1 < keys_pts.size():
			var a: Vector3 = keys_pts[i]
			var b: Vector3 = keys_pts[i + 1]
			var n := int(ceil(a.distance_to(b) / 0.25))
			for t in range(1, n):
				walked.append(a.lerp(b, float(t) / n))
	if hf is Dictionary:
		for p in walked:
			var g := _hf_height(hf, p.x, p.z)
			if absf(p.y - g) > 0.2:
				bad.append("(%.1f, %.1f) y %.2f vs ground %.2f" % [p.x, p.z, p.y, g])
			var why := _villager_spot_problem(hf, Vector2(p.x, p.z), buildings, street)
			if why != "":
				bad.append("(%.1f, %.1f) %s" % [p.x, p.z, why])
			for q in villager_pts:
				if (q as Vector2).distance_to(Vector2(p.x, p.z)) < 1.0:
					bad.append("(%.1f, %.1f) on a villager's path" % [p.x, p.z])
					break
	check(hf is Dictionary and bad.is_empty(), "her stroll (%d points along it) stays on clear ground, off the villagers' paths %s" % [walked.size(), bad.slice(0, 4)])
	print("")



## Test 17 (review; rule changed by Story 25.10 J6): one E never does two things. In a small world with
## a ZonePromptUI, a registered "fire" zone and the cat a step apart, a player body in both zones gives
## E and the prompt to the NEARER one (it was: the cat always yields); a waiting patron in range takes
## E first; walking away takes the prompt down; her carry-on never starts an AnimationPlayer she didn't
## pause.
func test_the_cat_yields() -> void:
	if not ResourceLoader.exists(CAT_SCENE_PATH):
		check(false, "the cat and E: TheCat.tscn missing")
		return
	var world := Node3D.new()
	root.add_child(world)
	var ui = load("res://scripts/game/ZonePromptUI.gd").new()
	world.add_child(ui)
	var other := AnimationPlayer.new()      # a sibling she must not start
	world.add_child(other)
	var fire := Area3D.new()
	var fire_shape := CollisionShape3D.new()
	fire_shape.shape = BoxShape3D.new()
	(fire_shape.shape as BoxShape3D).size = Vector3(2, 2, 2)
	fire_shape.position = Vector3(0, 1, 0)
	fire.add_child(fire_shape)
	world.add_child(fire)                    # box z -1..1; default anchor = its shape, (0, 1, 0), flat (0, 0)
	ui.register_zone(fire, "Press E - Tend Fire")
	var cat = (load(CAT_SCENE_PATH) as PackedScene).instantiate()
	world.add_child(cat)
	cat.position = Vector3(0, 0, 2.2)        # PetZone r 0.75 around (0, 0.3, 2.2): 0.45 m from the box
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.add_to_group("player")
	var cap := CollisionShape3D.new()
	cap.shape = CapsuleShape3D.new()
	(cap.shape as CapsuleShape3D).radius = PLAYER_RADIUS
	(cap.shape as CapsuleShape3D).height = 1.5
	cap.position = Vector3(0, 0.75, 0)
	player.add_child(cap)
	world.add_child(player)
	player.position = Vector3(0, 0, 6.0)

	var settle := func(frames: int) -> void:
		for i in frames:
			await physics_frame
		await process_frame
	await settle.call(40)                    # she finds the prompt UI (she looks for 30 frames)
	if not ui.has_method("owns_e"):
		check(false, "ZonePromptUI.owns_e (one E owner, Story 25.10)")
		world.queue_free()
		await process_frame
		return
	for c in [[1.05, "fire"], [1.4, "cat"]]:  # z 1.05: fire 1.05 / cat 1.15; z 1.4: cat 0.80 / fire 1.40
		player.position = Vector3(0, 0, 6.0)
		await settle.call(4)
		player.position = Vector3(0, 0, c[0])
		await settle.call(6)
		var both := [fire.overlaps_body(player), cat._zone.overlaps_body(player)]
		var fire_owns: bool = ui.owns_e(fire)
		var cat_owns: bool = ui.owns_e(cat._zone)
		var ok: bool
		if c[1] == "fire":
			ok = fire_owns and not cat_owns and not cat.can_be_petted() and ui.prompt_label.text == "Press E - Tend Fire"
		else:
			ok = cat_owns and not fire_owns and cat.can_be_petted() and ui.prompt_label.text == cat.PROMPT
		check(both == [true, true] and ok and ui.prompt_label.visible,
			"in both zones at z %.2f, E and the prompt go to the nearer, the %s (in both: %s)" % [c[0], c[1], both])
	player.position = Vector3(0, 0, 6.0)
	await settle.call(4)
	player.position = Vector3(0, 0, 2.9)     # beside her only (the town case)
	await settle.call(6)
	check(ui.owns_e(cat._zone) and cat.can_be_petted() and ui.prompt_label.visible and ui.prompt_label.text == cat.PROMPT,
		"beside her only: her prompt shows and E is hers")
	var patron := Node3D.new()               # a waiting patron in serving range takes E first
	patron.set_script(_waiting_patron_script())
	patron.add_to_group("patrons")
	world.add_child(patron)
	await settle.call(2)
	check(not cat.can_be_petted() and not ui.owns_e(cat._zone) and not ui.prompt_label.visible,
		"a waiting patron in range takes E before her, and the prompt goes (it would name the wrong action)")
	patron.free()
	player.position = Vector3(0, 0, 6.0)     # walked away
	await settle.call(6)
	check(not cat.can_be_petted() and not ui.prompt_label.visible, "walking away takes her prompt down")
	cat._carry_on()
	check(not other.is_playing(), "her carry-on doesn't start an AnimationPlayer she didn't pause")
	world.queue_free()
	await process_frame


static func _waiting_patron_script() -> GDScript:
	var gs := GDScript.new()
	gs.source_code = "extends Node3D\nfunc can_be_served_by(_p: Vector3) -> bool:\n\treturn true\n"
	gs.reload()
	return gs

# --- Test 18: Den Fa, the Architect (Story 25.10) ---
# A tall construct on his own rig (ears, mask, four folded bone wings: Story 26.11 animates them), a
# metallic mirror mask that keeps its ink outline, seated at the Hearth's SitPoint by his own seat
# convention, talkable (his E opens the dialogue box: Story 10.2, Test 20), a walk to the bar and a point at the
# pillar, two reflection probes, and one E owner near the hearth (J6: the nearest zone wins, behind a
# gate decided once per frame so serving a patron can never also talk).
func test_den_fa() -> void:
	print("[Test 18] Den Fa")
	for p in [DEN_FA_PATH, DEN_FA_SCENE_PATH, DEN_FA_SCRIPT_PATH]:
		check(ResourceLoader.exists(p), "exists: %s" % p.get_file())
	if ResourceLoader.exists(DEN_FA_PATH):
		var inst := (load(DEN_FA_PATH) as PackedScene).instantiate()
		var sks := inst.find_children("*", "Skeleton3D", true, false)
		var names := []
		if not sks.is_empty():
			for b in (sks[0] as Skeleton3D).get_bone_count():
				names.append((sks[0] as Skeleton3D).get_bone_name(b))
		var needed := ["d_mask", "d_ear1.L", "d_ear2.L", "d_ear1.R", "d_ear2.R"]
		for w in ["U", "L"]:
			for i in [1, 2, 3]:
				for side in ["L", "R"]:
					needed.append("d_wing%s%d.%s" % [w, i, side])
		var missing := needed.filter(func(n): return not names.has(n))
		var unprefixed := names.filter(func(n): return not str(n).begins_with("d_"))
		check(names.size() >= 40 and missing.is_empty() and unprefixed.is_empty(),
			"his rig: %d bones, all d_ (not: %s); ears, mask and 12 wing bones (missing: %s)" % [names.size(), unprefixed.slice(0, 3), missing])
		var aps := inst.find_children("*", "AnimationPlayer", true, false)
		var ap: AnimationPlayer = aps[0] if not aps.is_empty() else null
		var wrong_clips := []
		for c in DEN_FA_LOOPS:
			if ap == null or not ap.has_animation(c) or ap.get_animation(c).loop_mode != Animation.LOOP_LINEAR:
				wrong_clips.append(c)
		for c in DEN_FA_ONE_SHOTS:
			if ap == null or not ap.has_animation(c) or ap.get_animation(c).loop_mode != Animation.LOOP_NONE:
				wrong_clips.append(c)
		check(wrong_clips.is_empty(), "Idle, Sit and Walk loop; Point, StandUp and SitDown play once (wrong or missing: %s)" % [wrong_clips])
		inst.free()
		var st := _mesh_stats(DEN_FA_PATH)
		check(st.tris > 0 and st.tris <= 6000 and st.glow == 0 and st.wrong.is_empty(),
			"g9_den_fa.glb: %d tris (≤ 6,000), nothing glows, roughness > 0 (wrong: %s)" % [st.tris, st.wrong])
		var gnodes := _scene_nodes(DEN_FA_PATH)
		var top := -INF
		var mask: StandardMaterial3D = null
		for k in gnodes:
			var mesh = gnodes[k].props.get("mesh")
			if not mesh is Mesh:
				continue
			top = maxf(top, ((gnodes[k].world as Transform3D) * (mesh as Mesh).get_aabb()).end.y)
			for s in (mesh as Mesh).get_surface_count():
				var m = (mesh as Mesh).surface_get_material(s)
				if m is StandardMaterial3D and (m as StandardMaterial3D).resource_name == "den_fa_mask":
					mask = m
		check(top >= KNIGHT_TOP + 0.45 and top <= 3.2,
			"taller than the whole chibi cast: %.2f m (the Knight's %.3f + 0.45, at most 3.2)" % [top, KNIGHT_TOP])
		check(mask != null and mask.metallic >= 0.9 and mask.roughness > 0.05 and mask.roughness <= 0.20
			and not mask.emission_enabled and mask.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
			"the mirror mask is metallic, roughness in (0.05, 0.20] (ink outline), opaque, not glowing (%s)"
			% ["missing" if mask == null else "metallic %.2f roughness %.2f" % [mask.metallic, mask.roughness]])

	var dscene := _scene_nodes(DEN_FA_SCENE_PATH) if ResourceLoader.exists(DEN_FA_SCENE_PATH) else {}
	var root_script = dscene.get(".", {}).get("props", {}).get("script", null) if dscene.has(".") else null
	check(root_script is Script and (root_script as Script).resource_path == DEN_FA_SCRIPT_PATH, "DenFa.tscn runs den_fa.gd")
	var tz_r := 0.0
	for k in dscene:
		if str(k).begins_with("TalkZone/") and dscene[k].props.get("shape") is SphereShape3D:
			tz_r = (dscene[k].props.shape as SphereShape3D).radius
	check(dscene.has("TalkZone") and dscene.TalkZone.type == "Area3D" and tz_r >= 0.6 and tz_r <= 1.2, "a TalkZone (sphere, r %.2f m)" % tz_r)
	var bodies := dscene.keys().filter(func(k): return dscene[k].type in ["CharacterBody3D", "RigidBody3D", "StaticBody3D"])
	var groups := []
	for k in dscene:
		groups.append_array(dscene[k].groups)
	check(dscene.has(".") and bodies.is_empty() and not (groups.has("patrons") or groups.has("villagers") or groups.has("patron_seat")),
		"not a patron and no physics body (bodies %s, groups %s)" % [bodies, groups])
	var project := FileAccess.get_file_as_string("res://project.godot")
	var autoloads := project.substr(project.find("[autoload]"), 2000) if project.find("[autoload]") >= 0 else ""
	autoloads = autoloads.substr(0, autoloads.find("\n[", 2)) if autoloads.find("\n[", 2) > 0 else autoloads
	check(not autoloads.contains("den_fa") and not autoloads.contains("DenFa"), "no autoload for Den Fa (AR D11)")
	var ds = load(DEN_FA_SCRIPT_PATH) as Script if ResourceLoader.exists(DEN_FA_SCRIPT_PATH) else null
	var methods := ds.get_script_method_list().map(func(m): return m.name) if ds != null else []
	var pl_ok: bool = methods.has("pick_line") and ds.pick_line(0, -1, 0.5) == -1 and ds.pick_line(1, 0, 0.5) == 0
	if pl_ok:
		var last := -1
		for i in 20:
			var n: int = ds.pick_line(3, last, float(i) / 20.0)
			if n == last or n < 0 or n > 2:
				pl_ok = false
			last = n
		for roll in [0.0, 0.34, 0.5, 0.99]:
			if ds.pick_line(2, 0, roll) != 1:
				pl_ok = false
	check(pl_ok, "pick_line: none for no lines, the only one for one, never the same twice in a row")

	var sit_world := _hearth_sit_point_world()
	var fwd := Vector3(sit_world.basis.z.x, 0, sit_world.basis.z.z).normalized()
	check(fwd.distance_to(Vector3(0.906, 0, -0.423)) < 0.01, "the SitPoint faces the room, turned toward the fire")
	var seat: Vector3 = ds.seat_root(sit_world) if methods.has("seat_root") else Vector3.INF
	var ahead := (seat - sit_world.origin).dot(fwd) if seat != Vector3.INF else 0.0
	check(seat != Vector3.INF and absf(seat.y - 0.10) < 0.02 and ahead > 0.25 and ahead < 0.7,
		"seat_root: on the floor (y %.2f), %.2f m in front of the SitPoint" % [seat.y if seat != Vector3.INF else -1.0, ahead])
	var side := (seat - sit_world.origin).dot(Vector3(-fwd.z, 0, fwd.x)) if seat != Vector3.INF else 0.0
	check(absf(side - 0.48) < 0.02, "seat_root: also 0.48 m to his right, the room side, so he stands up clear of the chimney (%.2f)" % side)
	var hs := _scene_nodes(HEARTH_SCENE_PATH)
	check(hs.has("SitPoint") and not (hs.SitPoint.groups as Array).has("patron_seat"), "the SitPoint is not a patron seat")

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var dens := tav.keys().filter(func(k): return tav[k].instance == DEN_FA_SCENE_PATH)
	check(dens.size() == 1, "one Den Fa in the tavern (%d)" % dens.size())
	if dens.size() == 1:
		var dw: Transform3D = tav[dens[0]].world
		var face := Vector3(dw.basis.z.x, 0, dw.basis.z.z).normalized()
		var off := Vector2(dw.origin.x, dw.origin.z).distance_to(Vector2(seat.x, seat.z)) if seat != Vector3.INF else 99.0
		check(off <= 0.05 and absf(dw.origin.y - seat.y) <= 0.05 and rad_to_deg(face.angle_to(fwd)) <= 5.0 and not (tav[dens[0]].groups as Array).has("patrons"),
			"seated at the hearth: root %.2f m from seat_root, facing %.1f° off the SitPoint" % [off, rad_to_deg(face.angle_to(fwd))])
		var props: Dictionary = tav[dens[0]].props
		var route: PackedVector3Array = props.get("bar_route", PackedVector3Array())
		var nav: NavigationMesh = tav["SubViewportContainer/SubViewport/TavernNavigation"].props.get("navigation_mesh")
		var basket := Vector3.INF
		var stools := []
		for k in tav:
			if tav[k].instance == CAT_BASKET_PATH:
				basket = (tav[k].world as Transform3D).origin
			if str(k).get_file() == "RoundBar":
				var sub := _scene_nodes(tav[k].instance)
				for s in ["Stools/Stool03", "Stools/Stool04"]:
					if sub.has(s):
						stools.append(((tav[k].world as Transform3D) * (sub[s].world as Transform3D)).origin)
		var why := []
		if route.size() < 3:
			why.append("%d points" % route.size())
		for p in route:
			if absf(p.y - 0.10) > 0.05:
				why.append("y %.2f" % p.y)
		for i in route.size() - 1:
			var a := route[i]
			var b := route[i + 1]
			var n := maxi(int(ceil(a.distance_to(b) / 0.25)), 1)
			for t in n + 1:
				var q := a.lerp(b, float(t) / n)
				if i > 0 and not _nav_contains(nav, q.x, q.z):
					why.append("off the navmesh at (%.1f, %.1f)" % [q.x, q.z])
				if basket != Vector3.INF and Vector2(q.x, q.z).distance_to(Vector2(basket.x, basket.z)) < 0.8:
					why.append("by the basket at (%.1f, %.1f)" % [q.x, q.z])
		if route.size() > 0:
			var end := route[route.size() - 1]
			if end.distance_to(BAR_SPOT) > 0.6:
				why.append("ends at (%.2f, %.2f)" % [end.x, end.z])
			for s in stools:
				if Vector2(end.x, end.z).distance_to(Vector2(s.x, s.z)) < 0.6:
					why.append("on a stool")
		check(route.size() >= 3 and stools.size() == 2 and why.is_empty(),
			"his walk to the bar: on the floor, on the navmesh after the first leg, clear of the basket, between Stool03 and Stool04 %s" % [why.slice(0, 4)])
		check(str(props.get("pillar_target", "")).ends_with("HourglassPillar/HumAnchor"), "he points at the pillar's HumAnchor")
		var probes := tav.keys().filter(func(k): return tav[k].type == "ReflectionProbe")
		var consts: Dictionary = ds.get_script_constant_map() if ds != null else {}
		var masks := []
		for c in ["MASK_SEATED", "MASK_STANDING"]:
			if consts.get(c) is Vector3:
				masks.append(dw * (consts[c] as Vector3))
		var probe_ok := probes.size() == 2 and masks.size() == 2
		var in_hearth := false
		for k in probes:
			var pp: Dictionary = tav[k].props
			if int(pp.get("ambient_mode", 1)) != ReflectionProbe.AMBIENT_DISABLED or int(pp.get("update_mode", 0)) != ReflectionProbe.UPDATE_ONCE \
					or not pp.get("box_projection", false) or not pp.get("interior", false):
				probe_ok = false
			var probe_script = pp.get("script")
			if str(k).get_file() == "HearthProbe" and not (probe_script is Script and (probe_script as Script).resource_path.ends_with("hearth_probe.gd")):
				probe_ok = false
			if str(k).get_file() == "HearthProbe" and masks.size() == 2:
				var half: Vector3 = (pp.get("size", Vector3(20, 20, 20)) as Vector3) / 2.0
				var pw: Transform3D = tav[k].world
				in_hearth = true
				for m in masks:
					var q: Vector3 = (pw.affine_inverse() * (m as Vector3)).abs() - half
					if q.x > 0.0 or q.y > 0.0 or q.z > 0.0:
						in_hearth = false
		check(probe_ok and in_hearth, "two reflection probes (ambient off, once, box, interior); HearthProbe runs hearth_probe.gd and holds his mask seated and standing (%d probes)" % probes.size())
	var mt := FileAccess.get_file_as_string("res://scripts/game/main_tavern.gd")
	var zp := mt.substr(mt.find("func _init_zone_prompts"), 500)
	check(zp.contains(".find(get_tree())"), "the tavern reuses its ZonePromptUI: one prompt manager")
	print("")


## One E owner near the hearth (Test 18, J6). A small world in tavern coordinates: the prompt UI, the
## fire's zone (anchored at its interact_point), the cat, Den Fa seated at the SitPoint, a player body.
func test_den_fa_e() -> void:
	var ui = load("res://scripts/game/ZonePromptUI.gd").new()
	if not ResourceLoader.exists(DEN_FA_SCENE_PATH) or not ResourceLoader.exists(CAT_SCENE_PATH) or not ui.has_method("owns_e"):
		check(false, "one E owner near the hearth: DenFa.tscn, TheCat.tscn and ZonePromptUI.owns_e needed")
		ui.free()
		return
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(ui)
	var fire := Area3D.new()
	var fire_shape := CollisionShape3D.new()
	fire_shape.shape = BoxShape3D.new()
	(fire_shape.shape as BoxShape3D).size = Vector3(2.7, 2.2, 2.8)
	fire_shape.position = Vector3(0, 1.1, 0)
	fire.add_child(fire_shape)
	fire.position = Vector3(-3.55, 0, -9.3)
	world.add_child(fire)
	ui.register_zone(fire, "Press E - Tend Fire")
	var fire_anchor := Marker3D.new()        # the production path: set_anchor with a node (the hearth's interact_point)
	world.add_child(fire_anchor)
	fire_anchor.global_position = FIRE_ANCHOR
	ui.set_anchor(fire, fire_anchor)
	var cat = (load(CAT_SCENE_PATH) as PackedScene).instantiate()
	world.add_child(cat)
	cat.position = CAT_WORLD
	var marker := Marker3D.new()
	world.add_child(marker)
	marker.transform = _hearth_sit_point_world()
	var den = (load(DEN_FA_SCENE_PATH) as PackedScene).instantiate()
	world.add_child(den)
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.add_to_group("player")
	var cap := CollisionShape3D.new()
	cap.shape = CapsuleShape3D.new()
	(cap.shape as CapsuleShape3D).radius = PLAYER_RADIUS
	(cap.shape as CapsuleShape3D).height = 1.5
	cap.position = Vector3(0, 0.75, 0)
	player.add_child(cap)
	world.add_child(player)
	var outside := Vector3(-3.4, 0, -4.0)
	player.position = outside
	var settle := func(frames: int) -> void:
		for i in frames:
			await physics_frame
		await process_frame
	await settle.call(40)                    # the cat and Den Fa find the prompt UI (they look for 30 frames)
	if not den.has_method("sit_at") or not den.has_method("can_talk"):
		check(false, "den_fa.gd has sit_at() and can_talk()")
		world.queue_free()
		await process_frame
		return
	den.sit_at(marker)
	await settle.call(4)
	var talk: Area3D = den.get_node("TalkZone")
	var zones := {"fire": fire, "cat": cat._zone, "den_fa": talk}
	var texts := {"fire": "Press E - Tend Fire", "cat": cat.PROMPT, "den_fa": den.PROMPT}
	var owners := func() -> Array:
		return zones.keys().filter(func(k): return ui.owns_e(zones[k]))
	for c in [["den_fa", Vector3(-3.4, 0, -7.9)], ["cat", Vector3(-3.2, 0, -7.2)], ["fire", Vector3(-3.0, 0, -8.6)]]:
		player.position = outside
		await settle.call(4)
		player.position = c[1]
		await settle.call(6)
		var o: Array = owners.call()
		check(o == [c[0]] and ui.prompt_label.visible and ui.prompt_label.text == texts[c[0]],
			"at (%.1f, %.1f) E and the prompt go to the nearest, %s (owners %s, prompt '%s')" % [c[1].x, c[1].z, c[0], o, ui.prompt_label.text])
	player.position = outside
	await settle.call(4)
	player.position = Vector3(-3.2, 0, -7.2)
	await settle.call(6)
	player.position = Vector3(-3.43, 0, -7.21)  # Den Fa's root 0.49, the cat 0.59: within the 0.2 m hysteresis
	await settle.call(6)
	var hp := Vector2(-3.43, -7.21)
	var d_den := hp.distance_to(Vector2(den.global_position.x, den.global_position.z))
	var d_cat := hp.distance_to(Vector2(cat.global_position.x, cat.global_position.z))
	var in_both: bool = talk.overlaps_body(player) and cat._zone.overlaps_body(player)
	check(in_both and d_den < d_cat and d_cat - d_den < 0.2 and owners.call() == ["cat"],
		"hysteresis: in both zones and nearer Den Fa (%.2f vs %.2f), the cat keeps E (owners %s)" % [d_den, d_cat, owners.call()])
	var patron := Node3D.new()               # a waiting patron in serving range takes E first
	patron.set_script(_waiting_patron_script())
	patron.add_to_group("patrons")
	world.add_child(patron)
	await settle.call(2)
	check(owners.call().is_empty() and not den.can_talk() and not cat.can_be_petted() and not ui.prompt_label.visible,
		"a waiting patron takes E from the cat and Den Fa, and the prompt goes")
	patron.free()
	player.position = outside
	await settle.call(4)
	player.position = Vector3(-3.4, 0, -7.9)
	await settle.call(6)
	var his_before: bool = ui.owns_e(talk)
	var flip := Node3D.new()                 # serving flips a patron at once (RealisticPatron.serve_patron)
	flip.set_script(_flip_patron_script())
	flip.add_to_group("patrons")
	world.add_child(flip)
	await settle.call(2)
	var closed: bool = not ui.owns_e(talk)
	flip.serve_patron()
	check(his_before and closed and not ui.owns_e(talk) and not den.can_talk(),
		"serving a patron can't also talk to him: the gate is decided once per frame")
	await settle.call(3)                     # the served patron is still there, no longer waiting
	check(ui.owns_e(talk) and den.can_talk() and ui.prompt_label.visible and ui.prompt_label.text == den.PROMPT,
		"once the patron is served (still in the room), E and the prompt are his again")
	var gm = root.get_node_or_null("GameManager")
	var flags_before = gm.dialogue_flags.duplicate() if gm != null and gm.get("dialogue_flags") is Dictionary else null
	current_scene = world                    # the dialogue box opens in the current scene (Story 10.2)
	var talks := [0]
	den.talked.connect(func(_state): talks[0] += 1)
	var press := InputEventAction.new()      # a real E press through the input pipeline
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await settle.call(3)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	await settle.call(2)
	var den_bubbles: int = den.get_children().filter(func(c): return c is PatronSpeechBubble).size()
	var cat_bubbles: int = cat.get_children().filter(func(c): return c is PatronSpeechBubble).size()
	var open_boxes := get_nodes_in_group("dialogue_open")
	check(talks[0] == 1 and open_boxes.size() == 1 and den_bubbles == 0 and cat_bubbles == 0,
		"a real E press beside him: a dialogue box, no bubble; he talks once and the cat stays quiet (talked %d, boxes %d, bubbles %d / %d)"
		% [talks[0], open_boxes.size(), den_bubbles, cat_bubbles])
	for b in open_boxes:
		b.close("test")
	await settle.call(2)
	current_scene = null
	if flags_before != null:
		gm.dialogue_flags = flags_before
	flip.free()
	player.position = outside
	await settle.call(6)
	check(not ui.prompt_label.visible and owners.call().is_empty(), "walking away takes the prompt down")
	var trees := den.find_children("*", "AnimationTree", true, false)
	var sm = (trees[0] as AnimationTree).tree_root if not trees.is_empty() else null
	var states_ok: bool = sm is AnimationNodeStateMachine and DEN_FA_STATES.all(func(s): return (sm as AnimationNodeStateMachine).has_node(s))
	check(states_ok, "one AnimationTree whose state machine holds %s" % [DEN_FA_STATES])
	if states_ok and den.has_method("stand") and den.has_method("point_at_pillar") and den.has_method("return_to_seat"):
		var pb: AnimationNodeStateMachinePlayback = (trees[0] as AnimationTree).get("parameters/playback")
		den.stand()
		var t0 := Time.get_ticks_msec()
		while pb.get_current_node() != "Idle" and Time.get_ticks_msec() - t0 < 4000:
			await process_frame
		check(pb.get_current_node() == "Idle" and not ui.connected_zones.has(talk), "he stands up (Idle) and gives up his E zone")
		var pillar := Marker3D.new()
		world.add_child(pillar)
		pillar.global_position = Vector3(7.74, 2.2, -8.215)
		den.pillar_target = den.get_path_to(pillar)
		var aimed: bool = den.point_at_pillar()
		t0 = Time.get_ticks_msec()
		while pb.get_current_node() != "Point" and Time.get_ticks_msec() - t0 < 3000:
			await process_frame
		var to: Vector3 = pillar.global_position - den.global_position
		var aim_err := rad_to_deg(absf(wrapf(den.global_rotation.y - atan2(to.x, to.z), -PI, PI)))
		check(aimed and pb.get_current_node() == "Point" and aim_err < 10.0,
			"he turns to his pillar_target and points (state %s, %.0f deg off)" % [pb.get_current_node(), aim_err])
		var start: Vector3 = den.global_position
		den.bar_route = PackedVector3Array([start, start + Vector3(1.5, 0, 0.3)])
		den.seat_path = den.get_path_to(marker)
		den.walk_route(den.bar_route)            # queued until the point is over
		t0 = Time.get_ticks_msec()
		while (den.global_position.distance_to(den.bar_route[1]) > 0.05 or pb.get_current_node() != "Idle") and Time.get_ticks_msec() - t0 < 9000:
			await process_frame
		check(den.global_position.distance_to(den.bar_route[1]) < 0.05, "after the point he walks his route (%.2f m from its end)" % den.global_position.distance_to(den.bar_route[1]))
		den.return_to_seat()
		t0 = Time.get_ticks_msec()
		while not (den._seated and pb.get_current_node() == "Sit") and Time.get_ticks_msec() - t0 < 9000:
			await process_frame
		var seat_pos: Vector3 = den.seat_root(marker.global_transform)
		var sf := Vector3(marker.global_transform.basis.z.x, 0, marker.global_transform.basis.z.z).normalized()
		var yaw_err := rad_to_deg(absf(wrapf(den.global_rotation.y - atan2(sf.x, sf.z), -PI, PI)))
		check(den._seated and pb.get_current_node() == "Sit" and den.global_position.distance_to(seat_pos) < 0.05 and yaw_err < 5.0 and ui.connected_zones.has(talk),
			"return_to_seat: he walks back, turns to the room and sits, claiming E again (%.2f m, %.1f deg off)" % [den.global_position.distance_to(seat_pos), yaw_err])
	else:
		check(false, "he stands, points at his pillar_target, walks and returns to his seat")
	var probe := ReflectionProbe.new()       # the hearth probe re-captures when the fire's band changes
	probe.set_script(load("res://scripts/game/hearth_probe.gd"))
	world.add_child(probe)
	await settle.call(2)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe._on_fuel(85.0)
	var flipped: bool = probe.update_mode == ReflectionProbe.UPDATE_ALWAYS
	await settle.call(4)
	check(flipped and probe.update_mode == ReflectionProbe.UPDATE_ONCE, "the hearth probe re-captures on a fire band change (Always for two frames, then Once)")
	world.queue_free()
	await process_frame


# --- Test 19: the Bartender and the Quest Dealer (Story 25.13) ---
# Two staff bodies on the KayKit rig with seven work clips. The Bartender works the inside of the round
# bar (the serve points and the restock station, arcs round the ring in Walk_Bar); the Quest Dealer
# works the guild desk (her own seat offset; the stool pulled out, sat on and shuffled in). In the demo
# profile they are there from the first morning (K9); in the full game they walk in through the front
# door when GuildBus.staff_hired says so. Visuals only: no GameManager writes, no E, no physics body.
func test_staff() -> void:
	print("[Test 19] The Bartender and the Quest Dealer")
	_t19_ms = Time.get_ticks_msec()
	for p in [BARTENDER_PATH, BARTENDER_FALLBACK_PATH, DEALER_PATH, DEALER_FALLBACK_PATH, BARTENDER_SCENE, DEALER_SCENE, STAFF_BASE_SCRIPT, BARTENDER_SCRIPT, DEALER_SCRIPT,
			ANIME_LOOK_SCRIPT, ANIME_OUTLINE]:
		check(ResourceLoader.exists(p), "exists: %s" % p.get_file())
	check(FileAccess.file_exists(STAFF_DATA_PATH), "exists: staff.json")

	var data = _read_json(STAFF_DATA_PATH) if FileAccess.file_exists(STAFF_DATA_PATH) else null
	var roles: Dictionary = data.get("roles", {}) if data is Dictionary else {}
	# the GLB checks run on the bodies staff.json loads (every variant of each role), not on fixed paths. Per role:
	# [mesh allowlist, prefix, props, own clips, excluded clips, loops, one-shots, tri budget, surface cap (-1: none),
	# route ("anime" / "realistic"; 25.31: the RL rules - two textures at <= 1024, a head projection, top 1.50-2.25)]
	var glb_rules := {"bartender": [[], "Bartender_", ["Bartender_ClothBelt", "Bartender_ClothHand"],
			BARTENDER_CLIPS, BARTENDER_EXCLUDED, BARTENDER_LOOPS, BARTENDER_ONE_SHOTS, RL_TRI_BUDGET, RL_BODY_SURFACES, "realistic"],
		"desk_manager": [[], "Dealer_", ["Dealer_Quill"], DEALER_CLIPS, DEALER_EXCLUDED, DEALER_LOOPS, DEALER_ONE_SHOTS, RL_TRI_BUDGET, RL_BODY_SURFACES, "realistic"]}
	for role in glb_rules:
		var rv = roles.get(role)
		var vs = rv.get("variants", {}) if rv is Dictionary else {}
		if not (vs is Dictionary and not vs.is_empty()):
			check(false, "staff.json: %s has variants whose bodies the GLB checks can run on" % role)
			continue
		for v in vs.values():
			_check_staff_glb(str(v.get("model_path", "")) if v is Dictionary else "", glb_rules[role])
	# Review 2026-10-03: a custom fallback body (the 25.13 KayKit-rig dealer behind the anime one) is a staff body
	# too and gets the same checks under its own rule (a stock KayKit fallback, the Bartender's Barbarian, does not).
	var fallback_rules := {"desk_manager": [[], "Dealer_", ["Dealer_Quill"], DEALER_CLIPS, DEALER_EXCLUDED, DEALER_LOOPS,
			DEALER_ONE_SHOTS, AN_TRI_BUDGET, AN_BODY_SURFACES, "anime"],
		"bartender": [BARTENDER_MESH_ALLOW, "Bartender_", ["Bartender_ClothBelt", "Bartender_ClothHand"],
			STAFF_CLIPS, [], STAFF_LOOPS, STAFF_ONE_SHOTS, 7000, -1]}
	for role in fallback_rules:
		var fvs = roles.get(role, {}).get("variants", {}) if roles.get(role) is Dictionary else {}
		var fbs := []
		for v in (fvs.values() if fvs is Dictionary else []):
			var fb := str(v.get("fallback_model_path", "")) if v is Dictionary else ""
			if fb != "" and not fb.contains("/kaykit_adventurers/") and not fb in fbs:
				fbs.append(fb)
		check(not fbs.is_empty(), "staff.json: %s has a custom fallback body to check %s" % [role, fbs])
		for fb in fbs:
			_check_staff_glb(fb, fallback_rules[role])
	# the anime dealer's data (Story 25.30, N4): look "anime", the KayKit g13 dealer as the fallback, every body number
	var se = roles.get("desk_manager", {}).get("variants", {}).get("silver_elf") if roles.get("desk_manager") is Dictionary and roles.desk_manager.get("variants") is Dictionary else null
	var se_body = se.get("body") if se is Dictionary else null
	var bad_keys := DEALER_BODY_KEYS.filter(func(k): return not (se_body is Dictionary and (se_body.get(k) is float or se_body.get(k) is int)
		and (k == "seated_front" or float(se_body.get(k)) > 0.0)))
	check(se is Dictionary and str(se.get("look", "")) == "realistic" and str(se.get("model_path", "")) == DEALER_PATH
		and str(se.get("fallback_model_path", "")) == DEALER_FALLBACK_PATH and bad_keys.is_empty(),
		"staff.json silver_elf: the realistic body (look realistic), her anime v2 body as its fallback, and every body number (missing or bad %s)" % [bad_keys])
	# the realistic Bartender's data (Story 25.31, V14, F29): look "realistic", the 25.13 g12 as his fallback, every
	# body number; his ring (ring_r / keg_r / gap_r) clears the shelf, the kegs and the counter for his own Walk_Bar
	# half-widths (Test 19's 25.13 rules), he serves between the ring and the counter, the tankard drawn x 1.0-1.8
	var bk = roles.get("bartender", {}).get("variants", {}).get("barkeep") if roles.get("bartender") is Dictionary and roles.bartender.get("variants") is Dictionary else null
	var bk_body = bk.get("body") if bk is Dictionary else null
	var bk_bad := BARTENDER_BODY_KEYS.filter(func(k): return not (bk_body is Dictionary and (bk_body.get(k) is float or bk_body.get(k) is int)
		and float(bk_body.get(k)) > 0.0))
	check(bk is Dictionary and str(bk.get("look", "")) == "realistic" and str(bk.get("model_path", "")) == BARTENDER_PATH
		and str(bk.get("fallback_model_path", "")) == BARTENDER_FALLBACK_PATH and bk_bad.is_empty(),
		"staff.json barkeep: the realistic body (look realistic), the 25.13 g12 Bartender as its fallback, and every body number (missing or bad %s)" % [bk_bad])
	var bkd: Dictionary = bk_body if bk_body is Dictionary and bk_bad.is_empty() else {}
	var bscript = load(BARTENDER_SCRIPT) if ResourceLoader.exists(BARTENDER_SCRIPT) else null
	var bk_why := []
	if bkd.is_empty() or bscript == null:
		bk_why.append("no body block or script")
	else:
		for deg in 360:
			var r: float = bscript.ring_radius_at(deg_to_rad(float(deg)), float(bkd.ring_r), float(bkd.keg_r), float(bkd.gap_r))
			if r - float(bkd.walk_bar_half_shelf) < 1.28:
				bk_why.append("the shelf at %d°" % deg)
				break
			if absf(float(deg) - 180.0) <= 30.0 and r - float(bkd.walk_bar_half_low) < 1.49:
				bk_why.append("the kegs at %d°" % deg)
				break
			if absf(float(deg) - 180.0) > 16.8 and r + float(bkd.walk_bar_half_mid) > 2.355:
				bk_why.append("the counter at %d°" % deg)
				break
		if float(bkd.serve_r) < float(bkd.ring_r) - 0.05 or float(bkd.serve_r) > 2.35 - 0.25:
			bk_why.append("serve_r %.2f" % float(bkd.serve_r))
		if float(bkd.restock_r) < 1.49 + float(bkd.walk_bar_half_low) or float(bkd.restock_r) > 2.35:
			bk_why.append("restock_r %.2f" % float(bkd.restock_r))
		if float(bkd.tankard_scale) < 1.0 or float(bkd.tankard_scale) > 1.8:
			bk_why.append("tankard_scale %.2f" % float(bkd.tankard_scale))
	check(bk_why.is_empty(), "his body block: the ring clears the shelf, the kegs and the counter for his Walk_Bar, he serves between the ring and the counter (its face 0.25 m past his belly at most), the restock stand clears the kegs, the tankard x 1.0-1.8 (wrong: %s)" % [bk_why])
	var why := []
	if not (data is Dictionary and str(data.get("_note", "")).length() > 10):
		why.append("no _note")
	for role in ["bartender", "desk_manager"]:
		var r = roles.get(role)
		if not r is Dictionary:
			why.append("no role " + role)
			continue
		var variants = r.get("variants", {})
		if not (variants is Dictionary and variants.has(str(r.get("default_variant", "")))):
			why.append(role + ": default_variant not in variants")
		for v in (variants.values() if variants is Dictionary else []):
			for key in ["model_path", "fallback_model_path"]:
				if not (v is Dictionary and ResourceLoader.exists(str(v.get(key, "")))):
					why.append("%s: %s missing" % [role, key])
		var distinct := {}
		for l in r.get("barks", []):
			if str(l).strip_edges() != "":
				distinct[str(l)] = true
		if distinct.size() < 3:
			why.append("%s: %d barks" % [role, distinct.size()])
		if str(r.get("display_name", "")) == "":
			why.append(role + ": no display_name")
	check(why.is_empty(), "staff.json: both roles, a default variant with existing model and fallback paths, ≥ 3 barks each %s" % [why])

	var gms = load(GAME_MANAGER_PATH)
	var gm_methods: Array = gms.get_script_method_list().map(func(m): return m.name)
	var prof_ok: bool = gm_methods.has("staff_hired_by_profile") and gm_methods.has("is_staff_hired")
	if prof_ok:
		prof_ok = gms.staff_hired_by_profile("demo", ["bartender", "desk_manager"], "bartender") \
			and not gms.staff_hired_by_profile("full", ["bartender", "desk_manager"], "bartender") \
			and not gms.staff_hired_by_profile("demo", [], "bartender") \
			and not gms.staff_hired_by_profile("demo", ["bartender", "desk_manager"], "gardener")
	check(prof_ok, "staff_hired_by_profile: hired at start only in the demo profile and only for the listed roles")
	var cfg = _read_json(GAME_CONFIG_PATH)
	var start_staff = cfg.get("demo_start_staff", []) if cfg is Dictionary else []
	var gm = root.get_node_or_null("GameManager")
	check(cfg is Dictionary and str(cfg.get("profile", "")) == "demo" and start_staff is Array and start_staff.has("bartender") and start_staff.has("desk_manager")
		and gm != null and gm.has_method("is_staff_hired") and gm.is_staff_hired("bartender") and gm.is_staff_hired("desk_manager"),
		"the demo profile starts with both staff hired (K9: game_config profile + demo_start_staff)")
	var gb = root.get_node_or_null("GuildBus")
	check(gb != null and gb.has_signal("staff_hired") and gb.has_signal("staff_fired"), "GuildBus has staff_hired and staff_fired (Story 16.1's contract)")

	var bs = load(BARTENDER_SCRIPT) if ResourceLoader.exists(BARTENDER_SCRIPT) else null
	var bconst: Dictionary = bs.get_script_constant_map() if bs != null else {}
	var bmethods: Array = bs.get_script_method_list().map(func(m): return m.name) if bs != null else []
	check(absf(float(bconst.get("RING_R", 0.0)) - 1.80) < 0.001 and absf(float(bconst.get("RESTOCK_R", 0.0)) - 1.98) < 0.001
		and absf(float(bconst.get("SERVE_R", 0.0)) - 1.76) < 0.001,
		"the ring walk runs at r 1.80 (the serve points), he stands to serve at r 1.76 (his beard clears the counter) and the restock station is at r 1.98 (in the flap gap; %s, %s, %s)" % [bconst.get("RING_R"), bconst.get("SERVE_R"), bconst.get("RESTOCK_R")])
	var ring_ok: bool = bmethods.has("ring_arc") and bmethods.has("ring_radius_at") and bmethods.has("nearest_station")
	why = []
	if ring_ok:
		for phi in [0.0, 60.0, 120.0, 240.0, 300.0]:
			if absf(bs.ring_radius_at(deg_to_rad(phi)) - 1.80) > 0.001:
				why.append("r(%d)" % phi)
		for phi in [150.0, 164.0, 172.0, 180.0, 188.0, 196.0, 210.0]:
			if bs.ring_radius_at(deg_to_rad(phi)) < 1.898:
				why.append("keg sector r(%d) %.3f" % [phi, bs.ring_radius_at(deg_to_rad(phi))])
		var arc: PackedVector3Array = bs.ring_arc(RING_CENTER, 0.0, deg_to_rad(300.0), 0.25)
		if arc.is_empty() or arc[0].distance_to(RING_CENTER + Vector3(0, 0, 1.8)) > 0.001 \
				or arc[arc.size() - 1].distance_to(RING_CENTER + Vector3(sin(deg_to_rad(300.0)), 0, cos(deg_to_rad(300.0))) * 1.8) > 0.001:
			why.append("endpoints")
		for i in arc.size():
			var d := arc[i] - RING_CENTER
			var phi_deg := fposmod(rad_to_deg(atan2(d.x, d.z)), 360.0)
			if phi_deg > 1.0 and phi_deg < 299.0:
				why.append("the long way (%.0f°)" % phi_deg)
				break
			if absf(Vector2(d.x, d.z).length() - bs.ring_radius_at(atan2(d.x, d.z))) > 0.01 or absf(arc[i].y - RING_CENTER.y) > 0.001:
				why.append("off the ring at %.0f°" % phi_deg)
				break
			if i > 0 and arc[i].distance_to(arc[i - 1]) > 0.26:
				why.append("a %.2f m step" % arc[i].distance_to(arc[i - 1]))
				break
		var low := float(bconst.get("WALK_BAR_HALF_LOW", 9.0))        # at the kegs' height (0.26-0.49 m)
		var shelf := float(bconst.get("WALK_BAR_HALF_SHELF", 9.0))    # at the shelf's lowest tier (0.3-0.6 m)
		var mid := float(bconst.get("WALK_BAR_HALF_MID", 9.0))        # up to the counter top (0.6-1.12 m)
		for deg in 360:
			var r: float = bs.ring_radius_at(deg_to_rad(float(deg)))
			if r - shelf < 1.28:
				why.append("the shelf at %d°" % deg)
				break
			if absf(float(deg) - 180.0) <= 30.0 and r - low < 1.49:    # the kegs, and his body's length past them
				why.append("the kegs at %d°" % deg)
				break
			if absf(float(deg) - 180.0) > 16.8 and r + mid > 2.355:    # the counter (0.005 m contact tolerance)
				why.append("the counter at %d°" % deg)
				break
	check(ring_ok and why.is_empty(), "ring_arc: the shorter way round, on the ring (r 1.80; ≥ 1.898 past the kegs), 0.25 m steps; Walk_Bar clears the shelf, the kegs and the counter %s" % [why])
	var stations := []
	for deg in [0.0, 60.0, 120.0, 240.0, 300.0]:
		stations.append(RING_CENTER + Vector3(sin(deg_to_rad(deg)), 0, cos(deg_to_rad(deg))) * 1.8)
	var near_ok: bool = ring_ok
	if ring_ok:
		for pair in [[10.0, 0], [70.0, 1], [250.0, 3]]:
			var t := RING_CENTER + Vector3(sin(deg_to_rad(pair[0])), 0, cos(deg_to_rad(pair[0]))) * 3.55
			if bs.nearest_station(stations, t) != pair[1]:
				near_ok = false
	check(near_ok and bconst.get("CAMERA_VISIBLE", []) == [0, 1, 2, 4], "nearest_station picks the serve point facing a stool; the autopilot prefers 01, 02, 03 and 05")
	var base = load(STAFF_BASE_SCRIPT) if ResourceLoader.exists(STAFF_BASE_SCRIPT) else null
	var bm: Array = base.get_script_method_list().map(func(m): return m.name) if base != null else []
	var pl_ok: bool = bm.has("pick_line") and base.pick_line(0, -1, 0.5) == -1 and base.pick_line(1, 0, 0.5) == 0
	if pl_ok:
		var last := -1
		for i in 20:
			var n: int = base.pick_line(4, last, float(i) / 20.0)
			if n == last or n < 0 or n > 3:
				pl_ok = false
			last = n
	check(pl_ok, "pick_line: none for no lines, the only one for one, never the same twice in a row")
	var rc_ok: bool = bm.has("resolve_clip")
	if rc_ok:
		rc_ok = base.resolve_clip(PackedStringArray(["Wipe"]), "Wipe") == "Wipe" \
			and base.resolve_clip(PackedStringArray(["Idle", "Interact"]), "Wipe") == "Interact" \
			and base.resolve_clip(PackedStringArray(["Idle"]), "Wipe") == "Idle" \
			and base.resolve_clip(PackedStringArray(), "Wipe") == ""
	check(rc_ok, "resolve_clip: a state plays its own clip, else CLIP_FALLBACK's, else Idle, else none (never a clip the body lacks)")
	var ana := AnimationNodeAnimation.new()
	check("use_custom_timeline" in ana and "loop_mode" in ana and "timeline_length" in ana,
		"AnimationNodeAnimation has use_custom_timeline, timeline_length and loop_mode in this engine (the tree owns the staff's loop modes, AC 6)")
	var named := [STAFF_BASE_SCRIPT, BARTENDER_SCRIPT, DEALER_SCRIPT, ANIME_LOOK_SCRIPT].filter(func(p): return ResourceLoader.exists(p) and (load(p) as Script).get_global_name() != "")
	check(named.is_empty(), "no class_name on the staff scripts or the anime look helper (AC 6) %s" % [named])

	var ds = load(DEALER_SCRIPT) if ResourceLoader.exists(DEALER_SCRIPT) else null
	var dconst: Dictionary = ds.get_script_constant_map() if ds != null else {}
	var desk := _scene_nodes(DESK_SCENE_PATH)
	var wp_world: Transform3D = Transform3D(Basis(), DESK_WORLD) * (desk.WorkPoint.world as Transform3D) if desk.has("WorkPoint") else Transform3D.IDENTITY
	var hip_back := float(dconst.get("DEALER_HIP_BACK", 0.0))
	var pull := float(dconst.get("STOOL_PULL", 0.0))
	var seated: Vector3 = ds.seated_root(wp_world) if ds != null and ds.get_script_method_list().any(func(m): return m.name == "seated_root") else Vector3.INF
	var expect := Vector3(wp_world.origin.x, 0.10, wp_world.origin.z + hip_back)
	var walk_half := float(dconst.get("WALK_HALF_AT_DESK", 9.0))
	var seated_front := float(dconst.get("SEATED_FRONT", 9.0))
	check(seated != Vector3.INF and seated.distance_to(expect) < 0.005 and hip_back > 0.25 and hip_back < 0.40
		and seated.z + seated_front <= DESK_SLAB_BACK - 0.02,
		"her seated root: %.2f m in front of the WorkPoint, on the floor; seated, she clears the desk top by ≥ 0.02 m" % hip_back)
	var standing_z := seated.z - pull if seated != Vector3.INF else 0.0
	check(pull >= 0.45 and standing_z <= DESK_SLAB_BACK - maxf(DEALER_IDLE_FRONT, walk_half) - 0.02,
		"STOOL_PULL %.2f: standing to sit, and turning there, she clears the desk top (root z %.2f)" % [pull, standing_z])
	# the data pass (Story 25.30): the same geometry with the anime body's own numbers from staff.json. Her hips,
	# 0.397 behind the root after the sit re-fit, stay over the stool (z -5.302..-4.905): 0.18 <= hip_back <= 0.57
	var bd: Dictionary = se_body if se_body is Dictionary else {}
	var hb_d := float(bd.get("hip_back", NAN))
	var pull_d := float(bd.get("stool_pull", NAN))
	var sf_d := float(bd.get("seated_front", NAN))
	var wh_d := float(bd.get("walk_half_at_desk", NAN))
	var if_d := float(bd.get("idle_front", NAN))
	var seated_d := _dealer_seated_root(ds, wp_world, hb_d)
	var expect_d := Vector3(wp_world.origin.x, 0.10, wp_world.origin.z + hb_d)
	check(seated_d != Vector3.INF and seated_d.distance_to(expect_d) < 0.005 and hb_d >= 0.18 and hb_d <= 0.57
		and seated_d.z + sf_d <= DESK_SLAB_BACK - 0.02,
		"her anime body's seated root (staff.json hip_back %.2f): over the stool, on the floor; seated, she clears the desk top by ≥ 0.02 m" % hb_d)
	var standing_d := seated_d.z - pull_d if seated_d != Vector3.INF else NAN
	check(pull_d >= 0.45 and standing_d <= DESK_SLAB_BACK - maxf(if_d, wh_d) - 0.02,
		"her anime body's stool_pull %.2f: standing to sit, and turning there, she clears the desk top (root z %.2f)" % [pull_d, standing_d])

	for sp in [BARTENDER_SCENE, DEALER_SCENE]:
		var sn := _scene_nodes(sp) if ResourceLoader.exists(sp) else {}
		var scr = sn.get(".", {}).get("props", {}).get("script", null) if sn.has(".") else null
		var based: bool = scr is Script and (scr as Script).get_base_script() != null and (scr as Script).get_base_script().resource_path == STAFF_BASE_SCRIPT
		var bodies := sn.keys().filter(func(k): return sn[k].type in ["CharacterBody3D", "RigidBody3D", "StaticBody3D", "Area3D"])
		var groups := []
		for k in sn:
			groups.append_array(sn[k].groups)
		var bad_groups := groups.filter(func(gr): return gr in ["patrons", "patron_seat", "villagers", "player", "mission_board", "notice_board"])
		check(sn.has(".") and sn["."].type == "Node3D" and based and bodies.is_empty() and bad_groups.is_empty(),
			"%s: a Node3D running a staff_npc.gd script; no body, no zone, no patron group (bodies %s, groups %s)" % [sp.get_file(), bodies, bad_groups])
	var project := FileAccess.get_file_as_string("res://project.godot")
	var autoloads := project.substr(project.find("[autoload]"), 2000) if project.find("[autoload]") >= 0 else ""
	autoloads = autoloads.substr(0, autoloads.find("\n[", 2)) if autoloads.find("\n[", 2) > 0 else autoloads
	check(not autoloads.to_lower().contains("staff") and not autoloads.to_lower().contains("bartender") and not autoloads.to_lower().contains("dealer"), "no autoload for the staff")
	var fd = load(FRONT_DOOR_SCRIPT)
	var fdm: Array = fd.get_script_method_list().map(func(m): return m.name)
	check(fdm.has("hold_open") and fdm.has("release_hold"), "the front door can be held open by a walker without a body")

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var bars := tav.keys().filter(func(k): return tav[k].instance == BARTENDER_SCENE)
	var dealers := tav.keys().filter(func(k): return tav[k].instance == DEALER_SCENE)
	var staff_parent := "SubViewportContainer/SubViewport/TavernNavigation/Staff"
	check(bars.size() == 1 and dealers.size() == 1 and str(bars[0]).get_base_dir() == staff_parent and str(dealers[0]).get_base_dir() == staff_parent
		and tav.has(staff_parent) and (tav[staff_parent].local as Transform3D).is_equal_approx(Transform3D.IDENTITY),
		"one Bartender and one Quest Dealer under TavernNavigation/Staff (no offset) (%d, %d)" % [bars.size(), dealers.size()])
	for k in bars + dealers:
		var pr: Dictionary = tav[k].props
		check(int(pr.get("hired_at_start_override", -1)) == -1 and str(pr.get("variant", "")) == "",
			"%s asks GameManager whether it is hired and uses its role's default variant" % str(k).get_file())
	print("")


## quest_dealer.gd's seated root for a hip-back (Story 25.30); INF while its seated_root takes no hip-back yet.
static func _dealer_seated_root(ds, wp: Transform3D, hip_back: float) -> Vector3:
	if ds == null or is_nan(hip_back):
		return Vector3.INF
	var m = ds.get_script_method_list().filter(func(x): return x.name == "seated_root")
	if m.is_empty() or m[0].args.size() < 2:
		return Vector3.INF
	return ds.seated_root(wp, hip_back)


## One staff GLB (Test 19): the KayKit rig, the 76 clips plus the role's own clips (and none of the other role's;
## loops set), its own mesh nodes and props, the tri budget and the glow rule, no metal, under the door lintel.
## An anime body (a surface cap ≥ 0) also has one <prefix>Body within the cap, Lossless face and palette textures
## that Detect 3D cannot switch, and no LODs. rule = [allow, prefix, props, clips, excluded, loops, one_shots,
## tri_budget, surface_cap, route]. Story 25.31: route "realistic" (RL, AH-15) checks the same, with the head
## projection's texture (*_head) as the face, at most RL_TEXTURES textures of at most RL_TEX_SIZE², the RL_TRI_CAP and
## a top in RL_TOP; route "anime" (the default) keeps 25.30's rules.
func _check_staff_glb(path: String, rule: Array) -> void:
	var allow: Array = rule[0]
	var prefix: String = rule[1]
	var props: Array = rule[2]
	var own: Array = rule[3]
	var excluded: Array = rule[4]
	var loops: Array = rule[5]
	var one_shots: Array = rule[6]
	var tri_budget: int = rule[7]
	var cap: int = rule[8]
	var route: String = str(rule[9]) if rule.size() > 9 else "anime"
	var rl := route == "realistic"
	var tri_cap: int = RL_TRI_CAP if rl else AN_TRI_CAP
	var want_clips := 76 + own.size()
	var fname := path.get_file()
	if not ResourceLoader.exists(path):
		check(false, "%s: the KayKit rig, %d clips with loops set, its own meshes, props, ≤ %d tris, no metal, under 2.25 m" % [fname, want_clips, tri_budget])
		return
	var inst := (load(path) as PackedScene).instantiate()
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	var bones := []
	if not sks.is_empty():
		for b in (sks[0] as Skeleton3D).get_bone_count():
			bones.append((sks[0] as Skeleton3D).get_bone_name(b))
	check(bones.size() >= 41 and ["handslot.l", "handslot.r", "hips", "head"].all(func(b): return bones.has(b)),
		"%s: the KayKit rig (%d bones, handslots, hips, head)" % [fname, bones.size()])
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	var ap: AnimationPlayer = aps[0] if not aps.is_empty() else null
	var clips: Array = Array(ap.get_animation_list()) if ap else []
	var missing := (CAST_CLIPS + own).filter(func(c): return not clips.has(c))
	var dupes := clips.filter(func(c): return str(c).contains(".00"))
	var foreign := excluded.filter(func(c): return clips.has(c))
	check(clips.size() == want_clips and missing.is_empty() and dupes.is_empty() and foreign.is_empty(),
		"%s: %d clips, the cast's and its own %s, none of %s (%d; missing %s, .00x %s, foreign %s)" % [fname, want_clips, own, excluded, clips.size(), missing, dupes, foreign])
	var wrong := []
	for c in loops:
		if ap == null or not ap.has_animation(c) or ap.get_animation(c).loop_mode != Animation.LOOP_LINEAR:
			wrong.append(c)
	for c in one_shots:
		if ap == null or not ap.has_animation(c) or ap.get_animation(c).loop_mode != Animation.LOOP_NONE:
			wrong.append(c)
	check(wrong.is_empty(), "%s: the work loops loop and the one-shots play once (wrong: %s)" % [fname, wrong])
	var meshes := inst.find_children("*", "MeshInstance3D", true, false).map(func(m): return str(m.name))
	var stray := meshes.filter(func(m): return not allow.has(m) and not m.begins_with(prefix))
	var no_props := props.filter(func(p): return not meshes.has(p))
	check(stray.is_empty() and no_props.is_empty(), "%s: only its own pieces (stray %s) and its props (missing %s)" % [fname, stray, no_props])
	if cap >= 0:
		# an AN body: one <prefix>Body within the surface cap (props apart), Lossless textures that Detect 3D cannot
		# switch to VRAM (the face reads at mip 5; S3TC would smear the palette cells), and no LODs
		var body_mi := inst.find_child(prefix + "Body", true, false) as MeshInstance3D
		var nsurf: int = body_mi.mesh.get_surface_count() if body_mi and body_mi.mesh else -1
		var tex_wrong := []
		var tex_n := 0
		var has_face := false
		var face_key := "_head" if rl else "_face"
		for s in (nsurf if nsurf > 0 else 0):
			var mat = body_mi.mesh.surface_get_material(s)
			var tex: Texture2D = (mat as BaseMaterial3D).albedo_texture if mat is BaseMaterial3D else null
			if tex == null or tex.resource_path == "":
				tex_wrong.append("surface %d: no albedo texture" % s)   # every body surface reads a texture (face or palette)
				continue
			tex_n += 1
			if str(mat.resource_name).to_lower().ends_with(face_key) or tex.resource_path.get_file().to_lower().contains(face_key):
				has_face = true
			if rl and (tex.get_width() > RL_TEX_SIZE or tex.get_height() > RL_TEX_SIZE):
				tex_wrong.append("%s %dx%d" % [tex.resource_path.get_file(), tex.get_width(), tex.get_height()])
			var cf := ConfigFile.new()
			if cf.load(tex.resource_path + ".import") != OK:
				tex_wrong.append(tex.resource_path.get_file() + ": no .import")
			elif int(cf.get_value("params", "compress/mode", -1)) != 0 or not bool(cf.get_value("params", "mipmaps/generate", false)) \
					or int(cf.get_value("params", "detect_3d/compress_to", -1)) != 0:
				tex_wrong.append(tex.resource_path.get_file())
		var gcf := ConfigFile.new()
		var lods_off: bool = gcf.load(path + ".import") == OK and not bool(gcf.get_value("params", "meshes/generate_lods", true))
		# a per-mesh import override ("generate/lods": 1 = on) beats the global switch
		var subs = gcf.get_value("params", "_subresources", {})
		var mesh_subs = subs.get("meshes", {}) if subs is Dictionary else {}
		for mk in (mesh_subs if mesh_subs is Dictionary else {}):
			if mesh_subs[mk] is Dictionary and int(mesh_subs[mk].get("generate/lods", 0)) == 1:
				lods_off = false
		var distinct_tex := {}
		for s in (nsurf if nsurf > 0 else 0):
			var mt = body_mi.mesh.surface_get_material(s)
			if mt is BaseMaterial3D and (mt as BaseMaterial3D).albedo_texture:
				distinct_tex[(mt as BaseMaterial3D).albedo_texture.resource_path] = true
		var tex_ok: bool = not rl or distinct_tex.size() <= RL_TEXTURES
		check(body_mi != null and nsurf >= 1 and nsurf <= cap and tex_n == nsurf and has_face and tex_wrong.is_empty() and lods_off and tex_ok,
			"%s: one %sBody with %d surfaces (≤ %d), each textured, the %s among them (%s); its %d textures (%s) Lossless with mipmaps and Detect 3D off (wrong %s); no LODs, per mesh too (%s)" % [fname, prefix, nsurf, cap, "head projection" if rl else "face", has_face, distinct_tex.size(), ("≤ %d at ≤ %d²" % [RL_TEXTURES, RL_TEX_SIZE]) if rl else "any", tex_wrong, lods_off])
		var an_st := _mesh_stats(path)
		check(tri_budget <= tri_cap and an_st.tris > 0 and an_st.tris <= tri_cap,
			"%s: %d tris under the %s hard cap (%d, props included; budget %d)" % [fname, an_st.tris, "RL" if rl else "AN", tri_cap, tri_budget])
	var metal := []
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (m as MeshInstance3D).mesh
		for s in (mesh.get_surface_count() if mesh else 0):
			var mat = mesh.surface_get_material(s)
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).metallic > 0.01:
				metal.append(str(m.name))
	inst.free()
	var st := _mesh_stats(path)
	check(st.tris > 0 and st.tris <= tri_budget and st.glow == 0 and st.wrong.is_empty() and metal.is_empty(),
		"%s: %d tris (≤ %d), nothing glows, roughness > 0, no metal (wrong %s, metal %s)" % [fname, st.tris, tri_budget, st.wrong, metal])
	var top := -INF
	var gnodes := _scene_nodes(path)
	for k in gnodes:
		var mesh = gnodes[k].props.get("mesh")
		if mesh is Mesh:
			top = maxf(top, ((gnodes[k].world as Transform3D) * (mesh as Mesh).get_aabb()).end.y)
	if rl and cap >= 0:
		check(top >= RL_TOP[0] and top <= RL_TOP[1], "%s: %.2f m tall, in the RL range %.2f-%.2f (under the door lintel %.2f)" % [fname, top, RL_TOP[0], RL_TOP[1], LINTEL_Y])
	else:
		check(top > 1.8 and top <= LINTEL_Y - 0.05, "%s: %.2f m tall, under the door lintel (%.2f)" % [fname, top, LINTEL_Y])


## The staff in the real tavern (Test 19): their routes (on the navmesh except the listed legs, clear of
## every seat and footprint, through the door opening), their node paths, one work_point, two probes.
## The tavern is instanced with every script stripped (so nothing runs), after reading the staff exports.
func test_staff_tavern() -> void:
	var scene: Node = (load(TAVERN_SCENE_PATH) as PackedScene).instantiate()
	var tn_path := "SubViewportContainer/SubViewport/TavernNavigation"
	var staff := {}
	for n in ["Bartender", "QuestDealer"]:
		var node := scene.get_node_or_null(tn_path + "/Staff/" + n)
		if node:
			staff[n] = {"route": node.get("arrive_route"), "paths": {}}
			for p in ["bar_path", "desk_path", "door_path", "recruitment_zone_path", "recruitment_popup_path"]:
				if node.get(p) != null:
					staff[n].paths[p] = node.get(p)
	_strip_scripts(scene)
	root.add_child(scene)
	await process_frame
	var tn: Node3D = scene.get_node(tn_path)
	var nav: NavigationMesh = (tn as NavigationRegion3D).navigation_mesh
	var seats := []
	for n in scene.find_children("*", "Node3D", true, false):
		if n.is_in_group("patron_seat"):
			var t: Transform3D = (n as Node3D).global_transform
			var f := Vector3(t.basis.z.x, 0, t.basis.z.z).normalized()
			seats.append(t.origin + f * 0.40)
	var ps = load("res://scripts/npcs/PatronSpawner.gd").new()
	for p in ps.table_positions:
		seats.append(p)
	ps.free()
	var foots := []
	for parent in ["Furniture", "Props"]:
		for m in tn.get_node(parent).find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			if ab.position.y < 2.0 and ab.size.y > 0.05 and not str(m.get_path()).contains("/TheCat") and not str(m.get_path()).contains("/DenFa"):
				foots.append(ab)
	var legs := {
		"Bartender": func(q: Vector3) -> bool: return q.z >= 3.69 and q.z <= 5.25,
		"QuestDealer": func(q: Vector3) -> bool: return (q.z >= 3.69 and q.z <= 5.25) or (q.x < 10.2 and q.z >= -5.6 and q.z <= -5.2),
	}
	# the route ends from the scripts' own constants and the live bar and desk: a re-measured FLAP_R or
	# APPROACH_LOCAL without a matching MainTavern route fails here
	var bconst_t: Dictionary = load(BARTENDER_SCRIPT).get_script_constant_map()
	var dconst_t: Dictionary = load(DEALER_SCRIPT).get_script_constant_map()
	var round_bar := tn.get_node_or_null("Architecture/RoundBar") as Node3D
	var guild_desk := tn.get_node_or_null("Furniture/GuildDesk") as Node3D
	var ends := {
		"Bartender": load(BARTENDER_SCRIPT).ring_point(round_bar.global_position, PI, float(bconst_t.get("FLAP_R", 0.0))) if round_bar else Vector3.INF,
		"QuestDealer": guild_desk.global_transform * (dconst_t.get("APPROACH_LOCAL", Vector3.INF) as Vector3) if guild_desk else Vector3.INF,
	}
	for n in ["Bartender", "QuestDealer"]:
		if not staff.has(n):
			check(false, "%s: its arrive_route through the door, on the navmesh, clear of seats and furniture" % n)
			continue
		var route: PackedVector3Array = staff[n].route if staff[n].route is PackedVector3Array else PackedVector3Array()
		var why := []
		if route.size() < 3:
			why.append("%d points" % route.size())
		else:
			if route[0].z <= 5.25 or absf(route[0].y + 0.33) > 0.05:
				why.append("starts at (%.2f, %.2f, %.2f), not on the porch" % [route[0].x, route[0].y, route[0].z])
			if Vector2(route[route.size() - 1].x, route[route.size() - 1].z).distance_to(Vector2(ends[n].x, ends[n].z)) > 0.2:
				why.append("ends at (%.2f, %.2f)" % [route[route.size() - 1].x, route[route.size() - 1].z])
			var crossings := 0
			for i in route.size() - 1:
				var a := route[i]
				var b := route[i + 1]
				if a.z < 3.69 and absf(a.y - 0.10) > 0.05:
					why.append("hall point y %.2f" % a.y)
				if (a.z - 4.48) * (b.z - 4.48) < 0.0:
					crossings += 1
					var x := a.x + (b.x - a.x) * (4.48 - a.z) / (b.z - a.z)
					if x < 9.45 or x > 9.75:
						why.append("the door at x %.2f" % x)
				var steps := maxi(int(ceil(a.distance_to(b) / 0.25)), 1)
				for s in steps + 1:
					var q := a.lerp(b, float(s) / steps)
					if not legs[n].call(q) and not _nav_contains(nav, q.x, q.z):
						why.append("off the navmesh at (%.2f, %.2f)" % [q.x, q.z])
					for st in seats:
						if Vector2(q.x - st.x, q.z - st.z).length() < 0.9:
							why.append("by a seat at (%.2f, %.2f)" % [q.x, q.z])
							break
					for ab in foots:
						var dx := maxf(maxf(ab.position.x - q.x, 0.0), q.x - ab.end.x)
						var dz := maxf(maxf(ab.position.z - q.z, 0.0), q.z - ab.end.z)
						if Vector2(dx, dz).length() < 0.3:
							why.append("by furniture at (%.2f, %.2f)" % [q.x, q.z])
							break
			var last := route[route.size() - 1]
			if last.z < 3.69 and absf(last.y - 0.10) > 0.05:
				why.append("hall point y %.2f" % last.y)
			if crossings != 1:
				why.append("%d door crossings" % crossings)
		check(why.is_empty() and seats.size() >= 17 and foots.size() > 20,
			"%s: arrive_route from the porch through the door (x 9.45-9.75), on the navmesh but for its listed legs, ≥ 0.9 m from %d seats, ≥ 0.3 m from %d footprints %s" % [n, seats.size(), foots.size(), why.slice(0, 4)])
	var expect_paths := {"bar_path": "Architecture/RoundBar", "desk_path": "Furniture/GuildDesk", "door_path": "Architecture/Shell/FrontDoor",
		"recruitment_zone_path": "Interactive/RecruitmentDesk", "recruitment_popup_path": "GameUI/PopupManager/RecruitmentPopup"}
	var need := {"Bartender": ["bar_path", "door_path"], "QuestDealer": ["desk_path", "door_path", "recruitment_zone_path", "recruitment_popup_path"]}
	for n in need:
		var why := []
		var node := tn.get_node_or_null("Staff/" + n)
		for p in need[n]:
			var np = staff.get(n, {}).get("paths", {}).get(p)
			var target: Node = node.get_node_or_null(np) if node and np is NodePath else null
			if np is NodePath and (np as NodePath).is_absolute():
				why.append(p + " absolute")
			elif target == null or not str(target.get_path()).ends_with(expect_paths[p]):
				why.append(p)
		check(node != null and why.is_empty(), "%s: its node paths resolve in the tavern (bad: %s)" % [n, why])
	var wps := scene.find_children("*", "Node3D", true, false).filter(func(w): return w.is_in_group("work_point"))
	check(wps.size() == 1 and str(wps[0].get_path()).ends_with("GuildDesk/WorkPoint"), "exactly one work_point in the tavern: the desk's (%d)" % wps.size())
	var b12 := tn.get_node_or_null("Architecture/RoundBar/BackBar")
	var restock: Node3D = b12.find_child("work_point", true, false) if b12 else null
	check(restock != null and restock.global_position.distance_to(Vector3(7.740, 0.1, -10.015)) < 0.01,
		"the B12 restock marker, found scoped to BackBar, is at the ring's φ 180 (r 1.80)")
	var probes := scene.find_children("*", "ReflectionProbe", true, false)
	check(probes.size() == 2, "still exactly two reflection probes (%d)" % probes.size())
	scene.queue_free()
	await process_frame


## The staff at work in small worlds (Test 19), stepped by hand (manual_tick): the door's hold, the
## Bartender's walk-in, serve, restock and walk-out, the Quest Dealer's stool, sit, states and leave; the
## fallback bodies, the API with the autopilot off (Story 16.3's mode), both autopilots' own choices, and
## the hire and fire edges (mid walk-in, mid walk-out, mid-serve, mid-sit, while gone or already there).
func test_staff_runtime() -> void:
	if not (ResourceLoader.exists(BARTENDER_SCENE) and ResourceLoader.exists(DEALER_SCENE) and ResourceLoader.exists(FRONT_DOOR_SCRIPT)):
		check(false, "the staff at work: Bartender.tscn and QuestDealer.tscn needed")
		return
	var fd_methods: Array = load(FRONT_DOOR_SCRIPT).get_script_method_list().map(func(m): return m.name)
	if not fd_methods.has("hold_open"):
		check(false, "the front door's hold_open / release_hold needed")
		return
	var gb = root.get_node("GuildBus")
	var gm = root.get_node("GameManager")
	var eb = root.get_node("EconomyBus")
	var world := Node3D.new()
	root.add_child(world)
	var door := _make_door()
	world.add_child(door)
	door.global_position = DOOR_CENTER
	var opened := [0]
	var closed := [0]
	door.door_opened.connect(func(): opened[0] += 1)
	door.door_closed.connect(func(): closed[0] += 1)
	await process_frame
	var holder_a := Node.new()
	var holder_b := Node.new()
	door.hold_open(holder_a)
	var open_once: bool = opened[0] == 1
	door.hold_open(holder_b)
	holder_b.free()                              # a holder freed without releasing is pruned
	door.release_hold(holder_a)
	var t0 := Time.get_ticks_msec()
	while closed[0] == 0 and Time.get_ticks_msec() - t0 < 2000:
		await process_frame
	check(open_once and opened[0] == 1 and closed[0] == 1, "the door opens for a holder once and closes after the last release, a freed holder pruned (%d, %d)" % [opened[0], closed[0]])
	holder_a.free()
	# two live holders: no close is armed while one of them still holds it
	var holder_d := Node.new()
	var holder_e := Node.new()
	door.hold_open(holder_d)
	door.hold_open(holder_e)
	door.release_hold(holder_d)
	var kept_open: bool = door._is_open and door._close_timer.is_stopped()
	door.release_hold(holder_e)
	var close_armed: bool = not door._close_timer.is_stopped()
	t0 = Time.get_ticks_msec()
	while door._is_open and Time.get_ticks_msec() - t0 < 2000:
		await process_frame
	check(kept_open and close_armed and not door._is_open, "two holders: the door stays open until the last one lets go")
	holder_d.free()
	holder_e.free()
	var body := CharacterBody3D.new()
	var cap := CollisionShape3D.new()
	cap.shape = CapsuleShape3D.new()
	body.add_child(cap)
	body.collision_layer = 2
	world.add_child(body)
	body.global_position = DOOR_CENTER + Vector3(0, 1.0, -1.0)
	for i in 6:
		await physics_frame
	var holder_c := Node.new()
	door.hold_open(holder_c)
	door.release_hold(holder_c)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1000:
		await process_frame
	var still_open: bool = door._is_open
	body.queue_free()
	holder_c.free()
	t0 = Time.get_ticks_msec()
	while door._is_open and Time.get_ticks_msec() - t0 < 2000:
		await process_frame
	check(still_open and not door._is_open, "a body still inside keeps the door open after a release; it closes once the body leaves")

	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var door_key := "SubViewportContainer/SubViewport/TavernNavigation/Architecture/Shell/FrontDoor"
	var door_at: Vector3 = (tav[door_key].world as Transform3D).origin if tav.has(door_key) else Vector3.INF
	check(door_at.distance_to(DOOR_CENTER) < 0.01, "Test 19's door stands where MainTavern's FrontDoor does (%s)" % door_at)
	var routes := {}
	for k in tav:
		if tav[k].instance in [BARTENDER_SCENE, DEALER_SCENE]:
			routes[tav[k].instance] = tav[k].props.get("arrive_route", PackedVector3Array())
	var bar = (load(ROUND_BAR_SCENE_PATH) as PackedScene).instantiate()
	world.add_child(bar)
	bar.global_position = RING_CENTER
	# the serve target is stool 08's seat root (φ +10°, facing serve_point_01); stool 10's (φ 90) lies between two stations
	var s08: Node = bar.get_node_or_null("Stools/Stool08")
	var sp08: Node3D = s08.find_child("SeatPoint", true, false) as Node3D if s08 else null
	var s10: Node = bar.get_node_or_null("Stools/Stool10")
	var sp10: Node3D = s10.find_child("SeatPoint", true, false) as Node3D if s10 else null
	var s03: Node = bar.get_node_or_null("Stools/Stool03")      # φ 270: midway between serve_point_04 and serve_point_05
	var sp03: Node3D = s03.find_child("SeatPoint", true, false) as Node3D if s03 else null
	check(sp08 != null and sp10 != null and sp03 != null, "precondition: stool 03's, 08's and 10's SeatPoints exist in RoundBar")
	var patron_script = load(PATRON_SCRIPT_PATH)
	var stool08: Vector3 = patron_script.seat_root(sp08.global_transform) if sp08 else RING_CENTER + Vector3(0.755, 0.0, 3.496)
	var stool10: Vector3 = patron_script.seat_root(sp10.global_transform) if sp10 else RING_CENTER + Vector3(3.55, 0.0, 0.0)
	var stool03: Vector3 = patron_script.seat_root(sp03.global_transform) if sp03 else RING_CENTER + Vector3(-3.55, 0.0, 0.0)
	var beer_saved: int = gm.beer_stock
	gm.beer_stock = 5
	check(get_nodes_in_group("patrons").is_empty() and get_nodes_in_group("mission_board").is_empty(),
		"Test 19's small worlds start clean (beer pinned, no patrons, no mission board)")
	var staff_data = _read_json(STAFF_DATA_PATH)
	var staff_roles: Dictionary = staff_data.get("roles", {}) if staff_data is Dictionary else {}
	var dt := 1.0 / 30.0

	var first = (load(BARTENDER_SCENE) as PackedScene).instantiate()
	first.manual_tick = true
	first.hired_at_start_override = 1
	first.bar_path = bar.get_path()
	first.door_path = door.get_path()
	world.add_child(first)
	first.tick(dt)
	# the serve radius from staff.json read here (his body's serve_r, Story 25.31), not from the script's accessor
	var bk_spec = staff_roles.get("bartender", {}).get("variants", {}).get(str(staff_roles.get("bartender", {}).get("default_variant", "")), {})
	var bk_serve_r: float = float(bk_spec.get("body", {}).get("serve_r", 1.76)) if bk_spec is Dictionary and bk_spec.get("body") is Dictionary else 1.76
	var s01: Vector3 = RING_CENTER + Vector3(0, 0, bk_serve_r)
	check(first.visible and first.global_position.distance_to(s01) < 0.02 and first.anim_state() == "Wipe"
		and first._stands.size() == 6 and absf(wrapf(float(first._stands[first.RESTOCK_INDEX].phi) - PI, -PI, PI)) < 0.01,
		"hired at start: he is at serve_point_01 wiping (at %s, %s); five serve stations and the restock station at φ 180 (%d stations)" % [first.global_position, first.anim_state(), first._stands.size()])
	_check_staff_body(first, "the Bartender", _staff_model_path(staff_roles, "bartender"), str(bk_spec.get("look", "")) in ["anime", "realistic"] if bk_spec is Dictionary else false)
	var bt_name: String = first.display_name
	first.set_autopilot(false)
	var cloth_hand: Node3D = first.model.find_child("Bartender_ClothHand", true, false) as Node3D if first.model else null
	var cloth_belt: Node3D = first.model.find_child("Bartender_ClothBelt", true, false) as Node3D if first.model else null
	first.place_at_station()
	first.tick(dt)
	var wipe_cloths: bool = cloth_hand != null and cloth_belt != null and first.anim_state() == "Wipe" and cloth_hand.visible and not cloth_belt.visible
	first.play("Idle")
	first.tick(dt)
	var idle_cloths: bool = cloth_hand != null and cloth_belt != null and not cloth_hand.visible and cloth_belt.visible
	check(wipe_cloths and idle_cloths, "his cloths: the hand cloth shows while he wipes and the belt cloth hides; otherwise the other way round")
	# the facing stool: a seated patron counts for the station nearest his stool, and only that one
	var dummy := Node3D.new()
	dummy.add_to_group("patrons")
	world.add_child(dummy)
	dummy.global_position = stool08
	var near_08: Array = range(5).filter(func(i): return first._patron_near(i))
	first._station = 2
	var picked := {}
	for i in 20:                                   # a picker that ignored him would pick 01 only one time in three
		picked[first._pick_station()] = true
	dummy.global_position = stool10
	var near_10: Array = range(5).filter(func(i): return first._patron_near(i))
	dummy.global_position = stool03
	var near_03: Array = range(5).filter(func(i): return first._patron_near(i))
	dummy.free()
	first._station = 0
	check(near_08 == [0] and picked.keys() == [0] and near_10.size() == 1,
		"a seated patron counts for the station his stool faces, only that one: stool 08 for serve_point_01 %s (picked from 03, 20 times: %s), the φ 90 stool for one station %s" % [near_08, picked.keys(), near_10])
	check(near_03 == [4],
		"the φ 270 stool, as near serve_point_04 (behind the pillar) as serve_point_05, counts for 05, the one the camera sees %s" % [near_03])
	first.queue_free()
	await process_frame

	# AC 6's fallbacks: an unknown variant uses the role's default; a missing body file loads the KayKit body with
	# CLIP_FALLBACK's clips on the tree's own loop modes, its hand items hidden; a body whose root is not a Node3D is refused
	var vn = (load(BARTENDER_SCENE) as PackedScene).instantiate()
	vn.manual_tick = true
	vn.hired_at_start_override = 0
	vn.variant = "nope"
	world.add_child(vn)
	var vn_path: String = vn.model.scene_file_path if vn.model else "no body"
	check(vn.model != null and not vn.using_fallback and vn_path == _staff_model_path(staff_roles, "bartender"),
		"an unknown variant falls back to the role's default_variant (%s)" % vn_path)
	vn.queue_free()
	var fb_wrong := []
	for spec in [[BARTENDER_SCRIPT, "bartender", "res://assets/characters/models/kaykit_adventurers/Barbarian.glb"],
			[DEALER_SCRIPT, "desk_manager", "res://assets/characters/models/kaykit_adventurers/Mage.glb"]]:
		var fb = Node3D.new()
		fb.set_script(_staff_variant_script(spec[0], {"model_path": "res://missing.glb", "fallback_model_path": spec[2]}))
		fb.role = spec[1]
		fb.manual_tick = true
		fb.hired_at_start_override = 0
		world.add_child(fb)
		for fw in _staff_fallback_wrong(fb):
			fb_wrong.append("%s: %s" % [spec[1], fw])
		fb.queue_free()
	check(fb_wrong.is_empty(), "a missing body file: the KayKit fallback body, each state on its CLIP_FALLBACK clip, looping on the tree's own nodes, its hand items hidden (wrong: %s)" % [fb_wrong.slice(0, 4)])
	var card_path := "res://scenes/ui/AdventurerCard.tscn"             # a UI scene: its root is a Control
	var card = (load(card_path) as PackedScene).instantiate() if ResourceLoader.exists(card_path) else null
	check(card != null and not (card is Node3D), "precondition: %s exists and its root is not a Node3D" % card_path.get_file())
	if card:
		card.free()
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var cr = Node3D.new()
	cr.set_script(_staff_variant_script(BARTENDER_SCRIPT, {"model_path": card_path, "fallback_model_path": ""}))
	cr.role = "bartender"
	cr.manual_tick = true
	cr.hired_at_start_override = 0
	world.add_child(cr)
	var cr_leaked := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - orphans
	var cr_ready: bool = cr.model == null and not cr.visible and cr_leaked == 0
	cr.arrive()
	cr._bark_cd = 1.0
	var cr_from: Vector3 = cr.global_position
	cr.walk(PackedVector3Array([cr_from + Vector3(1.0, 0.0, 0.0)]))
	cr.tick(dt)
	var cr_step: float = cr.global_position.distance_to(cr_from)
	check(cr_ready and cr.present and cr.model == null and cr_step > 0.005 and cr_step < 0.05 and cr._bark_cd < 1.0,
		"a body scene whose root is not a Node3D is refused: no model, nothing left behind (%d orphan nodes), _ready runs to the end (hidden); with no body a tick still walks him and runs his work tick (%.3f m)" % [cr_leaked, cr_step])
	cr.queue_free()
	await process_frame

	var bt = (load(BARTENDER_SCENE) as PackedScene).instantiate()
	bt.manual_tick = true
	bt.hired_at_start_override = 0
	bt.arrive_route = routes.get(BARTENDER_SCENE, PackedVector3Array())
	bt.bar_path = bar.get_path()
	bt.door_path = door.get_path()
	world.add_child(bt)
	var hidden_at_start: bool = not bt.visible
	gb.staff_hired.emit("t_dealer", "desk_manager")
	var other_ignored: bool = not bt.visible
	opened[0] = 0
	gb.staff_hired.emit("t_bar", "bartender")
	var arrived := [false]
	bt.arrived_at_station.connect(func(): arrived[0] = true)
	var why := []
	var route: PackedVector3Array = bt.arrive_route
	var n := 0
	var zero_bt := false
	var zero_bt_tried := false
	while not arrived[0] and n < 3000:
		bt.tick(dt)
		n += 1
		_bar_walk_why(bt, route, why)
		var zp: Vector3 = bt.global_position
		if not zero_bt_tried and Vector2(zp.x - RING_CENTER.x, zp.z - RING_CENTER.z).length() < 3.0 and bt.is_turning():
			zero_bt_tried = true                     # turning in place at his station (a negative step would turn him
			var xf: Transform3D = bt.global_transform    # back; a walk step of 0 or less moves nothing): a zero and a
			var cd0: float = bt._bark_cd                 # negative tick change nothing, nor the playhead or the bark timer
			var at0: float = bt.playback.get_current_play_position() if bt.playback else -1.0
			bt.tick(0.0)
			bt.tick(-0.25)                               # not -1.0: that is a whole period of the stool slide's ease
			zero_bt = bt.global_transform == xf and xf.is_finite() and bt._bark_cd == cd0 \
				and (bt.playback.get_current_play_position() if bt.playback else -1.0) == at0
	check(hidden_at_start and other_ignored and bt.visible and arrived[0] and opened[0] >= 1 and why.is_empty(),
		"the full game: hidden until hired, a hire for her ignored; hired, he walks in (door opened %d) and takes his station in %.0f s, Walk_Bar inside the ring %s" % [opened[0], n * dt, why.slice(0, 3)])
	var beer_before: int = gm.beer_stock
	var gold_before: int = gm.gold
	var handed := [0]
	var handed_in := [""]                        # the state he is in at the release
	var handed_at := [-1.0]                      # and how far into it (s)
	bt.drink_handed.connect(func(_t):
		handed[0] += 1
		handed_in[0] = bt.anim_state()
		handed_at[0] = bt.playback.get_current_play_position() if bt.playback else -1.0)
	var serve_pts := []
	for i in 5:
		serve_pts.append(bt._stands[i].pos if bt._stands.size() > i else Vector3.INF)
	var k_serve: int = bt.nearest_station(serve_pts, stool08)
	bt.serve_toward(stool08)
	var seq := []
	var pour_pos := Vector3.INF
	var serve_pos := Vector3.INF
	var saw_serving := false
	var tank_why := []
	var carrying := false                        # from the first Pour to the release, the carry walk included
	var hand_tilt := 0.0                         # the most his hand slot leans, a frame on (every 10th tick of the carry)
	n = 0
	while n < 2400 and not (handed[0] == 1 and bt.work_state() == "IDLE" and not bt.is_walking() and seq.has("Serve")):
		if carrying and handed[0] == 0 and n % 10 == 0:
			await process_frame                  # the slot follows handslot.r (the skeleton updates deferred: with no frame
			var slot = bt._tankard.get_parent() if is_instance_valid(bt._tankard) else null   # the tilt read back is the
			if slot is Node3D:                   # one just set); the tick below has to set the tankard upright again
				hand_tilt = maxf(hand_tilt, rad_to_deg((slot as Node3D).global_basis.y.normalized().angle_to(Vector3.UP)))
		bt.tick(dt)
		n += 1
		var s: String = bt.anim_state()
		if seq.is_empty() or seq[seq.size() - 1] != s:
			seq.append(s)
		if s == "Pour" and pour_pos == Vector3.INF:
			pour_pos = bt.global_position
		if s == "Serve" and serve_pos == Vector3.INF:
			serve_pos = bt.global_position
		if bt.work_state() == "SERVING":
			saw_serving = true
		if s == "Pour":
			carrying = true
		if carrying and handed[0] == 0:
			var tw := _tankard_wrong(bt)
			if tw != "":
				tank_why.append("%s: %s" % [s, tw])
	var dropped: bool = bt._tankard == null
	var pour_at := seq.find("Pour")
	var serve_at := seq.rfind("Serve")
	var stand_pour: Vector3 = bt._stands[bt.RESTOCK_INDEX].pos if bt._stands.size() == 6 else Vector3.INF
	var stand_serve: Vector3 = bt._stands[k_serve].pos if k_serve >= 0 and k_serve < bt._stands.size() else Vector3.INF
	var release_k: float = handed_at[0] / bt.state_length("Serve")     # the set-down is at k ≈ 0.6 of Serve (the clip table)
	check(handed[0] == 1 and handed_in[0] == "Serve" and release_k > 0.45 and release_k < 0.75 and pour_at >= 0 and serve_at > pour_at
		and gm.beer_stock == beer_before and gm.gold == gold_before and saw_serving and pour_pos.distance_to(stand_pour) < 0.05 and serve_pos.distance_to(stand_serve) < 0.05,
		"serve_toward: he pours at the taps (SERVING), then serves at the station nearest stool 08; drink_handed once, inside Serve at its set-down (k %.2f of %.2f s); no beer or gold moves (%s)" % [release_k, bt.state_length("Serve"), seq.slice(0, 8)])
	await process_frame                                    # the dropped tankard's slot is freed
	var slots := 0
	var bsks: Array = bt.model.find_children("*", "Skeleton3D", true, false) if bt.model else []
	for c in (bsks[0].get_children() if not bsks.is_empty() else []):
		if c is BoneAttachment3D and str(c.name).begins_with("TankardSlot"):
			slots += 1
	check(tank_why.is_empty() and hand_tilt > 5.0 and dropped and slots == 0,
		"the tankard: on handslot.r and upright every tick from Pour to the release (the carry walk included; a frame on, with the slot on his hand leaning up to %.0f°), then dropped, no slot left on his skeleton (%s, %d slots)" % [hand_tilt, tank_why.slice(0, 3), slots])
	# Stage D found it: already in Walk_Bar, a state asked for in the frame a walk starts (place_at_station's Wipe,
	# then serve_toward) must not stick - the tree's current node lags a pending travel by a frame
	bt.play("WalkBar")
	bt.tick(dt)
	bt.place_at_station()
	bt.serve_toward(stool08)
	var walk_states := {}
	for i in 30:
		bt.tick(dt)
		if bt.is_walking():
			walk_states[bt.anim_state()] = true
	check(walk_states.keys() == ["WalkBar"], "a state asked for in the frame a walk starts does not stick: he shuffles in Walk_Bar (%s)" % [walk_states.keys()])
	bt.enter_idle()
	gm.beer_stock = 0
	eb.beer_changed.emit(0)
	var restock_spot: Vector3 = RING_CENTER + Vector3(0, 0, -float(bt._body("restock_r", bt.RESTOCK_R)))
	n = 0
	while n < 2400 and not (bt.work_state() == "RESTOCKING" and bt.global_position.distance_to(restock_spot) < 0.05 and bt.anim_state() == "Restock"):
		bt.tick(dt)
		n += 1
	var restocked: bool = bt.work_state() == "RESTOCKING" and bt.global_position.distance_to(restock_spot) < 0.05
	gm.beer_stock = beer_before
	eb.beer_changed.emit(beer_before)
	n = 0
	while n < 2400 and bt.work_state() != "IDLE":
		bt.tick(dt)
		n += 1
	check(restocked and bt.work_state() == "IDLE", "no beer: he restocks at the restock station (r 1.98); beer back: he goes back to work")

	# The autopilot off (how Story 16.3 drives him): every call leaves a state that plays, and nothing undoes a call
	bt.set_autopilot(false)
	bt.place_at_station()                                  # from serve_point_01: restock(true) has to walk him to the kegs
	var took := [bt.restock(true)]                         # what each call that takes him returns (true)
	n = 0
	while n < 2400 and not (bt.global_position.distance_to(restock_spot) < 0.05 and bt.anim_state() == "Restock"):
		bt.tick(dt)
		n += 1
	var d1: bool = bt.work_state() == "RESTOCKING" and bt.anim_state() == "Restock" and bt.global_position.distance_to(restock_spot) < 0.05
	took.append(bt.restock(false))
	for i in 10:
		bt.tick(dt)
	var d2: bool = bt.work_state() == "IDLE" and bt.anim_state() == "Idle" and not bt.is_walking()
	bt.serve_toward(stool08)
	n = 0
	while n < 2400 and bt.anim_state() != "Pour":
		bt.tick(dt)
		n += 1
	var at_pour: bool = bt.anim_state() == "Pour" and bt._tankard != null     # the moment each call below is about, reached
	took.append(bt.enter_idle())
	for i in 10:
		bt.tick(dt)
	var d3: bool = at_pour and bt._tankard == null and bt.anim_state() == "Idle" and not bt.is_walking()
	bt.serve_toward(stool08)
	n = 0
	while n < 2400 and not (bt.is_walking() and bt.anim_state() == "WalkBar" and bt._tankard != null):   # carrying it
		bt.tick(dt)
		n += 1
	var carrying4: bool = bt.is_walking() and bt.anim_state() == "WalkBar" and bt._tankard != null
	bt.enter_idle()
	for i in 10:
		bt.tick(dt)
	var d4: bool = carrying4 and bt.anim_state() == "Idle" and not bt.is_walking()
	bt.serve_toward(stool08)
	n = 0
	while n < 2400 and not (bt.is_walking() and bt._tankard != null):
		bt.tick(dt)
		n += 1
	var had5: bool = bt.is_walking() and bt._tankard != null
	bt.restock(true)
	var d5: bool = had5 and bt._tankard == null
	check(d1 and d2 and d3 and d4 and d5,
		"the autopilot off: restock(true) restocks at the kegs; restock(false) and enter_idle mid-pour or mid-walk leave him standing in Idle (no frozen Pour, no Walk_Bar in place); restock drops the tankard %s" % [[d1, d2, d3, d4, d5]])
	var on_handed := func(_t): bt.restock(true)
	bt.drink_handed.connect(on_handed, CONNECT_ONE_SHOT)
	var h0: int = handed[0]
	bt.serve_toward(stool08)
	n = 0
	while n < 2400 and not (handed[0] > h0 and bt.global_position.distance_to(restock_spot) < 0.05 and bt.anim_state() == "Restock"):
		bt.tick(dt)
		n += 1
	for i in 90:
		bt.tick(dt)
	var kept_restocking: bool = handed[0] == h0 + 1 and bt.work_state() == "RESTOCKING" and bt.anim_state() == "Restock" \
		and bt.global_position.distance_to(restock_spot) < 0.05
	if bt.drink_handed.is_connected(on_handed):
		bt.drink_handed.disconnect(on_handed)
	bt.restock(false)
	check(kept_restocking, "a drink_handed handler that sends him to restock is not undone by the serve's tail: still RESTOCKING 3 s after he reached the kegs (%s, %s)" % [bt.work_state(), bt.anim_state()])
	bt.serve_toward(stool08)
	n = 0
	while n < 2400 and bt.anim_state() != "Pour":
		bt.tick(dt)
		n += 1
	for i in int(minf(1.0, 0.5 * bt.state_length("Pour")) / dt):
		bt.tick(dt)
	var h1: int = handed[0]
	bt.serve_toward(stool08)
	for i in 5:
		bt.tick(dt)
	var pour_again_at: float = bt.playback.get_current_play_position() if bt.playback else 9.0
	var restarted: bool = bt.anim_state() == "Pour" and pour_again_at < 0.3
	seq = []
	n = 0
	while n < 2400 and not (handed[0] > h1 and bt.work_state() == "IDLE" and not bt.is_walking()):
		bt.tick(dt)
		n += 1
		var s2: String = bt.anim_state()
		if seq.is_empty() or seq[seq.size() - 1] != s2:
			seq.append(s2)
	check(restarted and seq.has("Serve") and handed[0] == h1 + 1,
		"serve_toward again mid-Pour starts the Pour over (at %.2f s after 5 ticks), then serves; drink_handed once" % pour_again_at)
	bt.set_autopilot(true)

	# The autopilot's own choices: the dwell, the station with a seated patron, a bark there, one bubble at a time
	bt.enter_idle()                                        # at serve_point_01, no patron: he wipes there, then moves on
	n = 0
	while n < 900 and not bt.is_walking():
		bt.tick(dt)
		n += 1
	var dwell: float = n * dt                              # timed by his ticks, not read back from the draw
	var dwell_ok: bool = dwell >= 6.0 - 2.0 * dt and dwell <= 12.0 + 2.0 * dt
	var fan := Node3D.new()
	fan.add_to_group("patrons")
	world.add_child(fan)
	var best_root := Vector3.INF
	for r in bt._stool_roots:
		var rv: Vector3 = r
		if rv.distance_to(bt._stands[2].pos) < best_root.distance_to(bt._stands[2].pos):
			best_root = rv
	fan.global_position = best_root
	var hops := []
	for i in 10:                                           # his first hop from 01, ten times: a picker that ignored the
		bt.place_at_station()                              # patron would head for 03 only one time in three
		n = 0
		while n < 10 and bt.anim_state() != "Wipe":
			bt.tick(dt)
			n += 1
		bt._dwell = 0.0
		bt.tick(dt)
		var hop_to: Vector3 = bt._path[bt._path.size() - 1] if bt.is_walking() else Vector3.INF
		hops.append(hop_to.distance_to(bt._stands[2].pos) < 0.01)
	n = 0
	while n < 900 and not (bt._station == 2 and bt.anim_state() == "Wipe" and not bt.is_busy()):
		bt.tick(dt)
		n += 1
	var prefers: bool = hops.all(func(h): return h) and bt._station == 2 and bt.anim_state() == "Wipe"
	var lb0: int = bt._last_bark
	bt._bark_cd = 0.0
	bt.tick(dt)
	var bubble1 := _live_bubbles(bt)
	var lb1: int = bt._last_bark
	var one_bubble: bool = lb1 != lb0 and bubble1.size() == 1 and bt._bark_cd >= 45.0     # a new line, then 45-90 s quiet
	for i in 60:
		bt.tick(dt)
	var still_one: bool = bt._last_bark == lb1 and _live_bubbles(bt) == bubble1
	var bubbles_before := _live_bubbles(bt)
	paused = true
	bt.bark()
	paused = false
	var none_paused: bool = _live_bubbles(bt) == bubbles_before
	var over_was: bool = gm.game_over_active
	gm.game_over_active = true
	bt.bark()
	gm.game_over_active = over_was
	var none_over: bool = _live_bubbles(bt) == bubbles_before
	fan.free()
	check(dwell_ok and prefers and one_bubble and still_one and none_paused and none_over,
		"the autopilot prefers a station with a seated patron (his first hop, ten times out of ten), dwells 6-12 s, and barks there once (a new line, then quiet for 45 s or more); one bubble; none while paused or at Game Over (dwell %.1f s, %s)" % [dwell, [hops.count(true), prefers, one_bubble, still_one, none_paused, none_over]])

	var left := [false]
	bt.left_tavern.connect(func(): left[0] = true)
	gb.staff_fired.emit("t_bar", "bartender")
	var why_out := []
	n = 0
	while n < 4000 and not left[0]:
		bt.tick(dt)
		n += 1
		_bar_walk_why(bt, route, why_out)
		if n == 60:                                    # mid walk-out: the API is refused, he still leaves
			bt.enter_idle()
			bt.serve_toward(stool08)
			bt.restock(true)
	check(left[0] and not bt.visible and route.size() > 0 and bt.global_position.distance_to(route[0]) < 0.1 and why_out.is_empty(),
		"fired: he walks out the way he came and is gone from the porch (%.0f s) %s" % [n * dt, why_out.slice(0, 3)])
	for i in 10:
		bt.tick(dt)
	# Stage D found it: the tick that ends his walk-out must not run the autopilot (a new walk, a new hold on the door)
	check(door._holders.is_empty() and not bt.is_walking(), "gone: he lets go of the door and stays put (holders %d, walking %s)" % [door._holders.size(), bt.is_walking()])
	var served_gone = bt.serve_toward(stool08)
	for i in 10:
		bt.tick(dt)
	check(served_gone is bool and not served_gone and bt.work_state() != "SERVING" and not bt.is_walking() and not bt.visible,
		"gone: serve_toward is refused (false); he is not SERVING and does not walk (%s, %s)" % [served_gone, bt.work_state()])
	# AC 4's edges (the AC walk found them untested): fired during the walk-in he goes back the way he came;
	# hired during the walk-out he turns back
	left[0] = false
	gb.staff_hired.emit("t_bar", "bartender")
	var in_hall := false
	n = 0
	while n < 3000 and not in_hall:                        # in the hall on his route, by position (the walk speeds are re-measured)
		bt.tick(dt)
		n += 1
		var hp: Vector3 = bt.global_position
		in_hall = bt._route_phase == "in" and hp.z < 3.0 and Vector2(hp.x - RING_CENTER.x, hp.z - RING_CENTER.z).length() > 5.0
	var mid_in: Vector3 = bt.global_position
	gb.staff_fired.emit("t_bar", "bartender")
	var near_ring := INF
	var off_route := 0.0
	n = 0
	while n < 4000 and not left[0]:
		bt.tick(dt)
		n += 1
		near_ring = minf(near_ring, Vector2(bt.global_position.x - RING_CENTER.x, bt.global_position.z - RING_CENTER.z).length())
		off_route = maxf(off_route, _dist_to_route(bt.global_position, route))
	check(in_hall and left[0] and near_ring > 3.5 and off_route < 0.05 and door._holders.is_empty(),
		"fired during the walk-in (at %.1f, %.1f): he goes back along his route and leaves (closest to the ring %.2f m, off the route %.3f m)" % [mid_in.x, mid_in.z, near_ring, off_route])
	# Nothing takes him off his way in: in the hall and again on the flap leg (the take-station leg), serve_toward is
	# refused, enter_idle and the last pint (beer_changed 0) change nothing; he takes his station, then restocks
	arrived[0] = false
	gb.staff_hired.emit("t_bar", "bartender")
	var refused := []
	var refused_api := []                                  # what enter_idle and restock return there (false)
	var poked_hall := false
	var poked_flap := false
	var why_in := []
	var cut := false
	n = 0
	while n < 3000 and not arrived[0]:
		bt.tick(dt)
		n += 1
		var ip: Vector3 = bt.global_position
		var idv := Vector2(ip.x - RING_CENTER.x, ip.z - RING_CENTER.z)
		if not poked_hall and bt._route_phase == "in" and ip.z < 0.0:
			poked_hall = true
			refused.append(bt.serve_toward(stool08))
			refused_api.append(bt.enter_idle())
			refused_api.append(bt.restock(true))
			gm.beer_stock = 0
			eb.beer_changed.emit(0)
		elif poked_hall and not poked_flap and bt._route_phase == "station" and idv.length() < 3.2 and bt.is_walking():
			poked_flap = true                                  # the take-station leg, by its phase (not only its radius)
			refused.append(bt.serve_toward(stool08))
			refused_api.append(bt.enter_idle())
			refused_api.append(bt.restock(true))
			eb.beer_changed.emit(0)
		_bar_walk_why(bt, route, why_in)
		if idv.length() > 2.30 and idv.length() < 3.0 and absf(rad_to_deg(atan2(idv.x, idv.y))) < 170.0:
			cut = true                                     # through the counter, not the flap
	var refused_ok: bool = refused.size() == 2 and refused.all(func(r): return r is bool and not r)
	var restock_after := false
	n = 0
	while n < 2400 and not restock_after:
		bt.tick(dt)
		n += 1
		restock_after = bt.work_state() == "RESTOCKING" and bt.global_position.distance_to(restock_spot) < 0.05 and bt.anim_state() == "Restock"
	gm.beer_stock = beer_before
	eb.beer_changed.emit(beer_before)
	check(poked_hall and poked_flap and refused_ok and arrived[0] and why_in.is_empty() and not cut and restock_after,
		"nothing takes him off his way in (serve_toward refused %s, enter_idle and the last pint ignored, in the hall and on the flap leg): he keeps to his route and the flap, takes his station, then restocks %s" % [refused, why_in.slice(0, 3)])
	check(refused_api.size() == 4 and refused_api.all(func(r): return r is bool and not r) and took.size() == 3 and took.all(func(r): return r is bool and r),
		"enter_idle and restock report a refusal as serve_toward does: false on his way in (in the hall, on the flap leg), so 16.3 can re-issue its state on arrived_at_station; true when they take him %s %s" % [refused_api, took])
	bt.place_at_station()                                  # back at serve_point_01 for the walk-out below
	arrived[0] = false
	gb.staff_fired.emit("t_bar", "bartender")
	var start_out: Vector3 = bt.global_position
	for i in 240:                                          # into the walk-out, still inside the ring (his speed is his body's)
		bt.tick(dt)
		if bt.global_position.distance_to(start_out) > 1.0:
			break
	var in_ring_d := Vector2(bt.global_position.x - RING_CENTER.x, bt.global_position.z - RING_CENTER.z).length()
	gb.staff_hired.emit("t_bar", "bartender")
	var crossed := false
	n = 0
	while n < 3000 and not arrived[0]:
		bt.tick(dt)
		n += 1
		var d := Vector2(bt.global_position.x - RING_CENTER.x, bt.global_position.z - RING_CENTER.z)
		var phi_deg := absf(rad_to_deg(atan2(d.x, d.y)))
		if d.length() > 2.30 and d.length() < 3.0 and phi_deg < 170.0:
			crossed = true                                 # through the counter, not the flap
	check(in_ring_d < 2.3 and arrived[0] and not crossed and bt.work_state() == "IDLE",
		"hired while still leaving his station (r %.2f): he takes it again without crossing the counter" % in_ring_d)
	# fired in the tick he takes his station: the tree is mid-crossfade into Wipe, where a travel waits for the fade to end
	var mid_fade: bool = bt.playback != null and bt.playback.get_fading_from_node() != ""
	left[0] = false
	gb.staff_fired.emit("t_bar", "bartender")
	var why_back := []
	var hired_on_route := false
	var bar_walk_n := -1                                   # the ticks until his walk-out plays Walk_Bar
	n = 0
	while n < 4000 and not left[0]:
		bt.tick(dt)
		n += 1
		if bar_walk_n < 0 and bt.anim_state() == "WalkBar":
			bar_walk_n = n
		_bar_walk_why(bt, route, why_back)
		var op: Vector3 = bt.global_position
		if bt._route_phase == "out" and Vector2(op.x - RING_CENTER.x, op.z - RING_CENTER.z).length() > 5.0:
			hired_on_route = true                          # on the route back to the porch
			arrived[0] = false
			gb.staff_hired.emit("t_bar", "bartender")
			break
	off_route = 0.0
	n = 0
	while n < 4000 and not arrived[0]:
		bt.tick(dt)
		n += 1
		_bar_walk_why(bt, route, why_back)                 # the way back in too: the turn-back, the flap leg, the arc
		if Vector2(bt.global_position.x - RING_CENTER.x, bt.global_position.z - RING_CENTER.z).length() > 3.65:
			off_route = maxf(off_route, _dist_to_route(bt.global_position, route))
	check(hired_on_route and not left[0] and arrived[0] and off_route < 0.05 and why_back.is_empty(),
		"hired during the walk-out: he turns back along his route and takes his station, through the flap and round the arc in Walk_Bar (off the route %.3f m) %s" % [off_route, why_back.slice(0, 3)])
	check(mid_fade and bar_walk_n >= 1 and bar_walk_n <= 2,
		"a state asked for mid-crossfade lands at once: fired in the tick he takes his station (the Wipe's fade running %s), he walks out in Walk_Bar from the next tick, not once the fade is over (%d ticks)" % [mid_fade, bar_walk_n])
	bt.serve_toward(stool08)
	n = 0
	while n < 900 and bt._tankard == null:
		bt.tick(dt)
		n += 1
	var had_tankard: bool = bt._tankard != null
	gb.staff_fired.emit("t_bar", "bartender")
	check(had_tankard and bt._tankard == null and bt.work_state() != "SERVING" and bt._leaving,
		"fired mid-serve: he drops the tankard and is no longer SERVING (%s)" % bt.work_state())
	bt.queue_free()
	await process_frame
	# a staff member freed while holding the door lets go (_exit_tree)
	var w = (load(BARTENDER_SCENE) as PackedScene).instantiate()
	w.manual_tick = true
	w.hired_at_start_override = 0
	w.arrive_route = routes.get(BARTENDER_SCENE, PackedVector3Array())
	w.bar_path = bar.get_path()
	w.door_path = door.get_path()
	world.add_child(w)
	w.arrive()
	w.tick(dt)                                             # on the porch, 1.7 m from the door, walking
	var w_held: bool = w._holding_door and door._holders.size() == 1
	w.queue_free()
	await process_frame
	check(w_held and door._holders.is_empty(), "a staff member freed while holding the door lets go (_exit_tree)")

	var desk = (load(DESK_SCENE_PATH) as PackedScene).instantiate()
	world.add_child(desk)
	desk.global_position = DESK_WORLD
	var stool: Node3D = desk.get_node("Model").find_child("desk_stool", true, false)
	var wp: Node3D = desk.get_node("WorkPoint")
	var want_const: Vector3 = load(DEALER_SCRIPT).seated_root(wp.global_transform)      # the KayKit g13 numbers (the fallback)
	# Story 25.30: the body numbers follow the body loaded. The expected values come from staff.json read here (or the
	# script's constants on a fallback body), never from the dealer's own accessor
	var dconst_r: Dictionary = load(DEALER_SCRIPT).get_script_constant_map()
	# the role's default variant (whatever staff.json names), not a pinned variant name (review 2026-10-03)
	var dm_r = staff_roles.get("desk_manager", {})
	var se_r = dm_r.get("variants", {}).get(str(dm_r.get("default_variant", "")), {}) if dm_r is Dictionary and dm_r.get("variants") is Dictionary else {}
	var body_r: Dictionary = se_r.get("body", {}) if se_r is Dictionary and se_r.get("body") is Dictionary else {}
	# the g13 fallback case: silver_elf's own spec (look anime, the full body block) with its anime file missing. The
	# fallback body takes the script constants and no toon, and keeps its quill (only while she is seated)
	var fb_spec: Dictionary = (se_r as Dictionary).duplicate(true) if se_r is Dictionary else {}
	fb_spec["model_path"] = "res://missing.glb"
	if fb_spec.get("body") is Dictionary and absf(float(fb_spec.body.get("hip_back", 0.0)) - float(dconst_r.get("DEALER_HIP_BACK", 0.32))) < 0.005:
		fb_spec.body["hip_back"] = 0.45                  # so the case can fail if the fallback read the data
	var fg = Node3D.new()
	fg.set_script(_staff_variant_script(DEALER_SCRIPT, fb_spec))
	fg.role = "desk_manager"
	fg.manual_tick = true
	fg.hired_at_start_override = 1
	fg.desk_path = desk.get_path()
	fg.door_path = door.get_path()
	world.add_child(fg)
	fg.set_autopilot(false)
	fg.tick(dt)
	var fg_quill: Node3D = fg.model.find_child("Dealer_Quill", true, false) as Node3D if fg.model else null
	var fg_seated_quill: bool = fg_quill != null and fg_quill.is_visible_in_tree()
	var fg_pull: float = (fg._seat() - fg._standing_root()).length() if fg.model else -1.0
	var fg_head_ok := true
	for hn in ["Dealer_Body"]:                          # (her anime body: the circlet and ears are in it)
		var h: Node3D = fg.model.find_child(hn, true, false) as Node3D if fg.model else null
		if h == null or not h.is_visible_in_tree():
			fg_head_ok = false
	var fg_hands := []
	var fg_sks: Array = fg.model.find_children("*", "Skeleton3D", true, false) if fg.model else []
	if not fg_sks.is_empty():
		for a in fg.model.find_children("*", "BoneAttachment3D", true, false):
			var bi: int = (fg_sks[0] as Skeleton3D).find_bone((a as BoneAttachment3D).bone_name)
			var par: int = (fg_sks[0] as Skeleton3D).get_bone_parent(bi) if bi >= 0 else -1
			if par >= 0 and (fg_sks[0] as Skeleton3D).get_bone_name(par).begins_with("handslot") and str(a.name) != "Dealer_Quill" and (a as Node3D).visible:
				fg_hands.append(str(a.name))
	var fg_look := _staff_look_wrong(fg, false)
	var fg_at: float = fg.global_position.distance_to(want_const)
	fg.leave()                                            # she stands and walks to the approach: the quill goes
	var fg_walk_quill := true
	var fg_walked := false
	n = 0
	while n < 900 and not fg_walked:
		fg.tick(dt)
		n += 1
		if fg.is_walking():
			fg_walked = true
			fg_walk_quill = fg_quill != null and fg_quill.is_visible_in_tree()
	check(fg.using_fallback and fg.model != null and fg.model.scene_file_path == DEALER_FALLBACK_PATH and fg_at < 0.02 and absf(fg_pull - float(dconst_r.get("STOOL_PULL", 0.52))) < 0.005
		and fg_look.is_empty() and fg_seated_quill and fg_walked and not fg_walk_quill and fg_head_ok and fg_hands.is_empty(),
		"her realistic file missing: her anime v2 body, seated by the script's own numbers (%.3f m off, stool pull %.2f), not the data's; no toon (%s); her quill out while she writes, gone walking %s; her body shown, no hand items %s" % [fg_at, fg_pull, fg_look.slice(0, 2), [fg_seated_quill, fg_walk_quill], fg_hands])
	fg.queue_free()
	await process_frame
	if stool:
		stool.position = Vector3.ZERO
	# the demo's first frame (AC 4, AC 7): hired at start by GameManager, seated and writing, the stool home
	if stool:
		stool.position.z = -0.3                           # so the reset to home cannot pass by doing nothing
	var q0 = (load(DEALER_SCENE) as PackedScene).instantiate()
	q0.manual_tick = true
	q0.hired_at_start_override = -1
	q0.desk_path = desk.get_path()
	q0.door_path = door.get_path()
	world.add_child(q0)
	q0.tick(dt)
	var on_fb: bool = q0.using_fallback
	var want: Vector3 = want_const if on_fb else _dealer_seated_root(load(DEALER_SCRIPT), wp.global_transform, float(body_r.get("hip_back", NAN)))
	var pull_want: float = float(dconst_r.get("STOOL_PULL", 0.52)) if on_fb else float(body_r.get("stool_pull", NAN))
	var bubble_want: float = float(dconst_r.get("BUBBLE_SEATED", NAN)) if on_fb else float(body_r.get("bubble_seated", NAN))
	var q0_ovs := _staff_overrides(q0)
	var q0_face := Vector3(q0.global_basis.z.x, 0, q0.global_basis.z.z).normalized()
	var q0_quill: Node3D = q0.model.find_child("Dealer_Quill", true, false) as Node3D if q0.model else null
	check(gm.is_staff_hired("desk_manager") and q0.visible and q0.present and q0.global_position.distance_to(want) < 0.02
		and rad_to_deg(q0_face.angle_to(Vector3(0, 0, 1))) < 5.0 and stool != null and stool.position.length() < 0.01
		and q0.work_state() == "IDLE" and q0.anim_state() == "Write" and q0_quill != null and q0_quill.visible,
		"hired at start (GameManager says so): she is seated at her seat root facing the room, the stool home, writing, her quill out (%s)" % q0.anim_state())
	q0.queue_free()
	await process_frame
	var qd = (load(DEALER_SCENE) as PackedScene).instantiate()
	qd.manual_tick = true
	qd.hired_at_start_override = 0
	qd.arrive_route = routes.get(DEALER_SCENE, PackedVector3Array())
	qd.desk_path = desk.get_path()
	qd.door_path = door.get_path()
	world.add_child(qd)
	_check_staff_body(qd, "the Quest Dealer", _staff_model_path(staff_roles, "desk_manager"), true)
	var qd_ovs := _staff_overrides(qd)
	check(not qd_ovs.is_empty() and qd_ovs == q0_ovs and qd_ovs.all(func(m): return m is Material),
		"two anime dealers share one toon material per surface (the helper's cache; %d surfaces)" % qd_ovs.size())
	var want_names := [str(staff_roles.get("bartender", {}).get("display_name", "?")), str(staff_roles.get("desk_manager", {}).get("display_name", "?"))]
	check(bt_name == want_names[0] and qd.display_name == want_names[1] and bt_name != "" and qd.display_name != "",
		"display_name comes from staff.json (%s, %s)" % [bt_name, qd.display_name])
	var quill: Node3D = qd.model.find_child("Dealer_Quill", true, false) as Node3D if qd.model else null
	var q_arrived := [false]
	qd.arrived_at_station.connect(func(): q_arrived[0] = true)
	gb.staff_hired.emit("t_desk", "desk_manager")
	var stool_moved := false
	var q_seq := []
	var min_stool_z := INF
	var sat_down := false
	var ahead := false
	var end_x := NAN
	var seated_ticks := 0
	var pull_aim := -1.0
	var zero_qd := false
	var zero_qd_tried := false
	n = 0
	while n < 3000 and not q_arrived[0]:
		qd.tick(dt)
		n += 1
		if stool and stool.position.length() > 0.2:
			stool_moved = true
		var qs: String = qd.anim_state()
		if q_seq.is_empty() or q_seq[q_seq.size() - 1] != qs:
			q_seq.append(qs)
		if qs == "SitDown":
			sat_down = true
		if not sat_down and stool:
			min_stool_z = minf(min_stool_z, stool.position.z)
		if qd._route_phase != "in":
			if is_nan(end_x):
				end_x = qd.global_position.x
			if not qd._seated and qd.global_position.z > qd._standing_root().z + 0.01:
				ahead = true                               # standing, her root never ahead of the standing root (the desk top)
		if qd._seated:
			seated_ticks += 1
		if pull_aim < 0.0 and qd._wanted == "Interact":
			pull_aim = _stool_aim_deg(qd, stool)
		if not zero_qd_tried and not qd._slide.is_empty():
			zero_qd_tried = true                         # mid stool-slide: a zero and a negative tick change nothing
			var qxf: Transform3D = qd.global_transform
			var sz: Vector3 = stool.position if stool else Vector3.ZERO
			qd.tick(0.0)
			qd.tick(-0.25)
			zero_qd = qd.global_transform == qxf and qxf.is_finite() and (stool == null or stool.position == sz)
	var face := Vector3(qd.global_basis.z.x, 0, qd.global_basis.z.z).normalized()
	var k10_ok: bool = _is_subsequence(["Interact", "SitDown", "Available", "Write"], q_seq) and absf(min_stool_z + pull_want) < 0.02 \
		and not ahead and end_x < want.x - 0.3 and seated_ticks <= int(round(float(qd.SLIDE_TIME) / dt)) + 1
	check(q_arrived[0] and stool_moved and qd.global_position.distance_to(want) < 0.02 and rad_to_deg(face.angle_to(Vector3(0, 0, 1))) < 5.0
		and stool != null and stool.position.length() < 0.01 and qd.work_state() == "IDLE" and qd.anim_state() == "Write" and k10_ok,
		"hired, she walks in from the west, pulls the stool out, sits and shuffles in: seated %.3f m from her seat, facing the room, the stool home, writing (%s; %s, stool out to %.2f, shuffle %d ticks)" % [qd.global_position.distance_to(want), qd.anim_state(), q_seq, min_stool_z, seated_ticks])
	check(zero_bt and zero_qd, "a zero tick changes nothing (no NaN): his turn in place, her stool slide %s" % [[zero_bt, zero_qd]])
	var states_ok := true
	var quill_states := {}                                 # R-9 (25.31): the quill shows only while she writes
	for pair in [["BRIEFING", "Brief"], ["AVAILABLE", "Available"], ["IDLE", "Write"]]:
		qd.set_autopilot(false)
		qd.set_work_state(pair[0])
		for i in 20:
			qd.tick(dt)
		if qd.work_state() != pair[0] or qd.anim_state() != pair[1]:
			states_ok = false
		quill_states[pair[1]] = quill != null and quill.visible
	check(states_ok, "set_work_state drives Brief, Available and Write (Story 16.4's states)")
	var quill_in: bool = quill != null and qd._seated and quill.visible and quill_states == {"Brief": false, "Available": false, "Write": true}
	var pos_here: Vector3 = qd.global_position
	var state_here: String = qd.anim_state()
	gb.staff_hired.emit("t_desk_2", "desk_manager")
	for i in 60:
		qd.tick(dt)
	check(qd.visible and qd.global_position == pos_here and qd.anim_state() == state_here and not qd.is_walking(),
		"hired again while she is here: ignored (seated, %s)" % qd.anim_state())
	# her autopilot (what the demo runs until 16.4): BRIEFING while the popup is open (a bark on its rising edge, at most
	# one per 20 s) over AVAILABLE while the player is at the desk, else IDLE
	qd.set_autopilot(true)
	var popup := Control.new()
	popup.visible = false
	world.add_child(popup)
	var zone := Area3D.new()
	zone.collision_mask = 2
	var zshape := CollisionShape3D.new()
	zshape.shape = BoxShape3D.new()
	(zshape.shape as BoxShape3D).size = Vector3(2.0, 2.0, 1.2)
	zone.add_child(zshape)
	world.add_child(zone)
	zone.global_position = DESK_WORLD + Vector3(0, 1.0, 1.2)
	var player := CharacterBody3D.new()
	var pcap := CollisionShape3D.new()
	pcap.shape = CapsuleShape3D.new()
	player.add_child(pcap)
	player.collision_layer = 2
	player.add_to_group("player")
	world.add_child(player)
	player.global_position = DESK_WORLD + Vector3(0, 1.0, 1.2)
	for i in 6:
		await physics_frame
	qd._zone = zone
	qd._popup = popup
	for i in 20:
		qd.tick(dt)
	var avail: bool = qd.work_state() == "AVAILABLE" and qd.anim_state() == "Available"
	popup.visible = true
	for i in 3:
		qd.tick(dt)
	var brief: bool = qd.work_state() == "BRIEFING" and qd.anim_state() == "Brief" and qd._last_bark >= 0
	var bark1: int = qd._last_bark
	var bubbles := _live_bubbles(qd)
	var bubble_ok: bool = bubbles.size() == 1 and absf(bubbles[0].position.y - (bubble_want - PatronSpeechBubble.HEAD_HEIGHT)) < 0.01
	for i in 690:                                          # kept open 23 s: no second bark without a new opening
		qd.tick(dt)
	var held_quiet: bool = qd._last_bark == bark1 and qd.work_state() == "BRIEFING"
	popup.visible = false
	for i in 3:
		qd.tick(dt)
	popup.visible = true
	qd.tick(dt)                                            # opened again, 23 s after the bark: the next one
	var bark2: int = qd._last_bark
	var rebark: bool = bark2 != bark1
	popup.visible = false
	for i in 568:
		qd.tick(dt)
	popup.visible = true
	qd.tick(dt)                                            # opened again 19 s after that bark: none yet
	var no_rebark: bool = qd._last_bark == bark2
	popup.visible = false
	for i in 44:
		qd.tick(dt)
	popup.visible = true
	qd.tick(dt)                                            # and at 20.5 s: one
	var rebark_after: bool = qd._last_bark != bark2
	popup.visible = false
	player.global_position = Vector3(30.0, 1.0, 30.0)
	for i in 6:
		await physics_frame
	for i in 20:
		qd.tick(dt)
	var idle_again: bool = qd.work_state() == "IDLE" and qd.anim_state() == "Write"
	var idle_seen := "%s/%s" % [qd.work_state(), qd.anim_state()]
	qd._zone = null
	qd._popup = null
	popup.queue_free()
	zone.queue_free()
	player.queue_free()
	check(avail and brief and bubble_ok and held_quiet and rebark and no_rebark and rebark_after and idle_again,
		"her autopilot: AVAILABLE with the player at the desk; BRIEFING while the popup is open, with a bark on its rising edge only (one bubble, at seated height; none while it stays open 23 s), none on an opening 19 s after a bark, one at 20.5 s; IDLE once both are gone %s" % [[avail, brief, bubble_ok, held_quiet, rebark, no_rebark, rebark_after, idle_seen]])
	var q_left := [false]
	var q_left_n := [0]
	qd.left_tavern.connect(func():
		q_left[0] = true
		q_left_n[0] += 1)
	gb.staff_fired.emit("t_desk", "desk_manager")
	var push_aim := -1.0
	var quill_out := true
	n = 0
	while n < 3000 and not q_left[0]:
		qd.tick(dt)
		n += 1
		if push_aim < 0.0 and qd._wanted == "Interact":
			push_aim = _stool_aim_deg(qd, stool)
		if quill and qd.is_walking() and quill.visible:
			quill_out = false
	check(q_left[0] and not qd.visible and stool != null and stool.position.length() < 0.01, "fired, she stands, puts the stool back and leaves")
	check(pull_aim >= 0.0 and pull_aim < 10.0 and push_aim >= 0.0 and push_aim < 10.0,
		"Interact faces the stool (its mesh's centre): %.1f° off pulling it out, %.1f° off pushing it back (< 10°)" % [pull_aim, push_aim])
	check(quill_in and quill_out, "her quill (a prop, R-9) shows only while she writes: hidden in Brief and Available and while she walks %s" % [quill_states])
	for i in 10:
		qd.tick(dt)
	check(door._holders.is_empty() and not qd.is_walking(), "gone: she lets go of the door and stays put (holders %d)" % door._holders.size())
	var lefts_before: int = q_left_n[0]
	gb.staff_fired.emit("t_desk", "desk_manager")
	for i in 30:
		qd.tick(dt)
	check(not qd.visible and not qd.is_walking() and q_left_n[0] == lefts_before, "fired while gone: ignored (hidden, still, no second left_tavern)")
	# fired while pulling the stool out (at the approach, not yet seated): the stool goes back before she leaves
	q_arrived[0] = false
	gb.staff_hired.emit("t_desk", "desk_manager")
	n = 0
	while n < 3000 and not (stool != null and stool.position.z < -0.4 and not qd._seated):
		qd.tick(dt)
		n += 1
	var pulled_at: float = stool.position.z if stool else 0.0
	q_left[0] = false
	gb.staff_fired.emit("t_desk", "desk_manager")
	n = 0
	while n < 3000 and not q_left[0]:
		qd.tick(dt)
		n += 1
	check(pulled_at < -0.4 and q_left[0] and not q_arrived[0] and stool != null and stool.position.length() < 0.01,
		"fired while pulling the stool out (the stool at z %.2f): she puts it back, then leaves (stool %.3f m from home)" % [pulled_at, stool.position.length() if stool else -1.0])
	# fired while sitting down (Sit_Chair_Down), and during the shuffle in: she stands, puts the stool back, leaves
	for mode in ["SitDown", "the shuffle in"]:
		q_arrived[0] = false
		gb.staff_hired.emit("t_desk", "desk_manager")
		var reached := false
		n = 0
		while n < 3000 and not reached:
			qd.tick(dt)
			n += 1
			reached = qd.anim_state() == "SitDown" if mode == "SitDown" else (qd._seated and not qd._slide.is_empty())
		q_left[0] = false
		gb.staff_fired.emit("t_desk", "desk_manager")
		var ahead_out := false
		var seq_out := []                                  # her states after the fire
		n = 0
		while n < 3000 and not q_left[0]:
			qd.tick(dt)
			n += 1
			var so: String = qd.anim_state()
			if seq_out.is_empty() or seq_out[seq_out.size() - 1] != so:
				seq_out.append(so)
			if qd._route_phase != "out" and (qd.anim_state() == "Interact" or qd.is_walking()) and qd.global_position.z > qd._standing_root().z + 0.01:
				ahead_out = true                           # at the desk (not the route out to the door)
		var up_at := seq_out.find("StandUp")               # she stands up before she walks or reaches for the stool
		var moved_at := -1
		for i in seq_out.size():
			if seq_out[i] in ["Walk", "WalkBar", "Interact"]:
				moved_at = i
				break
		check(reached and q_left[0] and not q_arrived[0] and stool != null and stool.position.length() < 0.01 and not ahead_out
			and up_at >= 0 and moved_at > up_at,
			"fired during %s: she stands (StandUp before she walks or reaches for the stool), puts the stool back and leaves, never walking or reaching ahead of her standing spot (%s)" % [mode, seq_out])
	# a state asked for during the walk-in holds once she sits (the autopilot off); an unknown one is refused
	qd.set_autopilot(false)
	q_arrived[0] = false
	gb.staff_hired.emit("t_desk", "desk_manager")
	for i in 60:
		qd.tick(dt)
	var walking_in: bool = qd._route_phase == "in" and qd.is_walking()
	qd.set_work_state("BRIEFING")
	n = 0
	while n < 3000 and not q_arrived[0]:
		qd.tick(dt)
		n += 1
	for i in 20:
		qd.tick(dt)
	var kept: bool = q_arrived[0] and qd.work_state() == "BRIEFING" and qd.anim_state() == "Brief"
	qd.set_work_state("BOGUS")
	for i in 3:
		qd.tick(dt)
	check(walking_in and kept and qd.work_state() == "BRIEFING" and qd.anim_state() == "Brief",
		"set_work_state during her walk-in holds once she is seated (Brief); an unknown state is refused (%s, %s)" % [qd.work_state(), qd.anim_state()])
	qd.set_autopilot(true)
	for i in 3:
		qd.tick(dt)
	# re-hired while leaving her seat: mid shuffle-out she slides straight back in; standing up, she sits straight back down
	q_left[0] = false
	gb.staff_fired.emit("t_desk", "desk_manager")
	for i in 8:
		qd.tick(dt)
	var mid_out: bool = qd._seated and not qd._slide.is_empty()
	q_arrived[0] = false
	gb.staff_hired.emit("t_desk", "desk_manager")
	var saw_interact := false
	n = 0
	while n < 3000 and not q_arrived[0]:
		qd.tick(dt)
		n += 1
		if qd.anim_state() == "Interact":
			saw_interact = true
	for i in 3:
		qd.tick(dt)
	check(mid_out and q_arrived[0] and not q_left[0] and not saw_interact and qd.global_position.distance_to(want) < 0.02
		and stool != null and stool.position.length() < 0.01 and qd.anim_state() == "Write",
		"re-hired mid shuffle-out: she slides straight back in (no Interact), seated, the stool home, writing (%s)" % qd.anim_state())
	gb.staff_fired.emit("t_desk", "desk_manager")
	n = 0
	while n < 3000 and qd.anim_state() != "StandUp":
		qd.tick(dt)
		n += 1
	var standing_up: bool = qd.anim_state() == "StandUp"
	q_arrived[0] = false
	gb.staff_hired.emit("t_desk", "desk_manager")
	var seq_b := []
	var ahead_b := false
	n = 0
	while n < 3000 and not q_arrived[0]:
		qd.tick(dt)
		n += 1
		var sb: String = qd.anim_state()
		if seq_b.is_empty() or seq_b[seq_b.size() - 1] != sb:
			seq_b.append(sb)
		if sb in ["Idle", "Walk", "WalkBar", "Interact", "StandUp"] and qd.global_position.z > qd._standing_root().z + 0.02:
			ahead_b = true
	check(standing_up and q_arrived[0] and not q_left[0] and seq_b.has("SitDown") and not seq_b.has("Interact") and not ahead_b
		and stool != null and stool.position.length() < 0.01 and qd.global_position.distance_to(want) < 0.02,
		"re-hired while standing up: she sits straight back down (no Interact), never ahead of her standing spot, seated with the stool home (%s)" % [seq_b])
	# a state asked for on her way in does not outlive a fire there (the autopilot off): hired again, she writes
	qd.set_autopilot(false)
	q_left[0] = false
	gb.staff_fired.emit("t_desk", "desk_manager")
	n = 0
	while n < 3000 and not q_left[0]:
		qd.tick(dt)
		n += 1
	q_arrived[0] = false
	gb.staff_hired.emit("t_desk", "desk_manager")
	for i in 60:
		qd.tick(dt)
	var in_again: bool = qd._route_phase == "in" and qd.is_walking()
	qd.set_work_state("BRIEFING")
	q_left[0] = false
	gb.staff_fired.emit("t_desk", "desk_manager")          # fired on her way in: back out along the route, the desk never reached
	n = 0
	while n < 3000 and not q_left[0]:
		qd.tick(dt)
		n += 1
	var out_again: bool = q_left[0] and not q_arrived[0]
	gb.staff_hired.emit("t_desk", "desk_manager")
	n = 0
	while n < 3000 and not q_arrived[0]:
		qd.tick(dt)
		n += 1
	for i in 20:
		qd.tick(dt)
	check(in_again and out_again and q_arrived[0] and qd.work_state() == "IDLE" and qd.anim_state() == "Write",
		"fired on her way in after a set_work_state, then hired again: she sits down writing (IDLE), not in the state from before the fire (%s, %s)" % [qd.work_state(), qd.anim_state()])
	qd.set_autopilot(true)
	_check_sit_refit(world)
	gm.beer_stock = beer_saved
	eb.beer_changed.emit(beer_saved)
	world.queue_free()
	await process_frame
	print("  [Test 19] %.1f s of real time (AC 8: ≤ 10 s)" % ((Time.get_ticks_msec() - _t19_ms) / 1000.0))


## A staff node's loaded body (Test 19): staff.json's own model (no fallback), every tree state bound to its own
## clip, the tree owning each state's loop mode, and no physics body or Area3D brought in with the model.
func _check_staff_body(x, who: String, want_path: String, anime := false) -> void:
	var bound := _staff_bound_wrong(x)
	var path: String = x.model.scene_file_path if x.model else "no body"
	check(x.model != null and not x.using_fallback and path == want_path and bound.is_empty(),
		"%s: its own body from staff.json (%s), every state bound to its own clip, no CLIP_FALLBACK (wrong: %s)" % [who, path.get_file(), bound])
	var loops := _staff_loops_wrong(x)
	check(loops.is_empty(), "%s: the tree owns every state's loop mode, whatever the import says (the loops loop, the one-shots play once, each on its clip's own length) (wrong: %s)" % [who, loops])
	check(x.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s: the loaded body adds no physics body or Area3D (AC 6)" % who)
	var look := _staff_look_wrong(x, anime)
	check(look.is_empty(), ("%s: the anime look on every surface (toon, no specular, no metal, roughness > 0, opaque, the shared outline as next_pass), the imported materials untouched (wrong: %s)" if anime
		else "%s: its imported materials as they are, no toon override (wrong: %s)") % [who, look.slice(0, 4)])


## What is wrong with a loaded staff body's look (Test 19, Story 25.30; F48): the anime body's surfaces carry the
## toon override (shared, never the imported material edited) with the shared outline as next_pass; any other body
## has no override. Fails when fewer than two surfaces were inspected (never vacuous).
static func _staff_look_wrong(x, anime: bool) -> Array:
	if x.model == null:
		return ["no body"]
	var outline: Material = load(ANIME_OUTLINE) if ResourceLoader.exists(ANIME_OUTLINE) else null
	var out := []
	var n := 0
	for mi in x.model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in (mesh.get_surface_count() if mesh else 0):
			n += 1
			var tag := "%s/%d" % [mi.name, s]
			var ov: Material = (mi as MeshInstance3D).get_surface_override_material(s)
			var src: Material = mesh.surface_get_material(s)
			if src is BaseMaterial3D and ((src as BaseMaterial3D).diffuse_mode == BaseMaterial3D.DIFFUSE_TOON or src.next_pass != null):
				out.append(tag + " imported material edited")
			if not anime:
				if ov != null:
					out.append(tag + " overridden")
				continue
			if not ov is StandardMaterial3D:
				out.append(tag + " not toned")
				continue
			var m := ov as StandardMaterial3D
			if m.diffuse_mode != BaseMaterial3D.DIFFUSE_TOON or m.specular_mode != BaseMaterial3D.SPECULAR_DISABLED or m.metallic > 0.0 \
					or m.metallic_specular > 0.0 or m.roughness <= 0.0 or m.emission_enabled or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				out.append(tag + " look")
			if outline == null or m.next_pass != outline:
				out.append(tag + " no outline")
	if anime:
		var o := outline as StandardMaterial3D
		if o == null or o.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or o.cull_mode != BaseMaterial3D.CULL_FRONT or not o.grow \
				or o.grow_amount <= 0.0 or o.metallic > 0.0 or o.emission_enabled or o.roughness <= 0.0 or o.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			out.append("the outline material")
	if n < 2:
		out.append("only %d surfaces inspected" % n)
	return out


## The anime base's sit re-fit on the loaded dealer (Test 19, Story 25.30 AC 1/N3): Sit_Chair_Idle's hips at
## AN_SIT_HIPS_Y and KayKit's 0.40 behind the root (RealisticPatron's convention), the feet planted, the
## seated shoulders above the desk (N2), and Down / StandUp meeting Sit_Chair_Idle's pose. Posed by hand: the
## tree off, the player seeked.
func _check_sit_refit(world: Node) -> void:
	var sr = (load(DEALER_SCENE) as PackedScene).instantiate()
	sr.manual_tick = true
	sr.hired_at_start_override = 0
	world.add_child(sr)
	var why := []
	# the body staff.json loads: REAL-2 (25.31, look realistic) or the anime base (25.30)
	var sd = _read_json(STAFF_DATA_PATH)
	var dm_v = sd.get("roles", {}).get("desk_manager", {}) if sd is Dictionary else {}
	var dv = dm_v.get("variants", {}).get(str(dm_v.get("default_variant", "")), {}) if dm_v is Dictionary and dm_v.get("variants") is Dictionary else {}
	var rl: bool = dv is Dictionary and str(dv.get("look", "")) == "realistic"
	var hips_want: float = RL_SIT_HIPS_Y_W if rl else AN_SIT_HIPS_Y
	var shoulder_min: float = RL_SEATED_SHOULDER_MIN_W if rl else AN_SEATED_SHOULDER_MIN
	var sk: Skeleton3D = null
	if sr.model:
		var sks: Array = sr.model.find_children("*", "Skeleton3D", true, false)
		sk = sks[0] as Skeleton3D if not sks.is_empty() else null
	var ap: AnimationPlayer = sr.anim
	var no_bones: Array = ["hips", "foot.l", "foot.r", "upperarm.l", "upperarm.r"].filter(func(b): return sk == null or sk.find_bone(b) < 0)
	if sk == null or ap == null or sr.tree == null or not (ap.has_animation("Sit_Chair_Idle") and ap.has_animation("Sit_Chair_Down") and ap.has_animation("Sit_Chair_StandUp")):
		why.append("no body, skeleton or sit clips")
	elif not no_bones.is_empty():
		why.append("bones missing %s" % [no_bones])   # a missing bone reads as the origin and would pass the feet check
	else:
		sr.tree.active = false
		var to_model: Transform3D = sr.model.global_transform.affine_inverse() * sk.global_transform
		var bone_at := func(clip: String, t: float, bone: String) -> Vector3:
			ap.play(clip)
			ap.seek(t, true)
			return to_model * sk.get_bone_global_pose(sk.find_bone(bone)).origin
		var idle_len: float = ap.get_animation("Sit_Chair_Idle").length
		var hips0: Vector3 = bone_at.call("Sit_Chair_Idle", 0.0, "hips")
		for t in [0.0, idle_len * 0.5]:
			var hp: Vector3 = bone_at.call("Sit_Chair_Idle", t, "hips")
			if absf(hp.y - hips_want) > 0.03 or absf(hp.z + 0.40) > 0.02:
				why.append("hips (%.3f, %.3f) at t %.2f" % [hp.y, hp.z, t])
			for f in ["foot.l", "foot.r"]:
				var rest_y: float = (to_model * sk.get_bone_global_rest(sk.find_bone(f)).origin).y
				var fy: float = (bone_at.call("Sit_Chair_Idle", t, f) as Vector3).y
				if absf(fy - rest_y) > 0.03:
					why.append("%s %.3f (rest %.3f)" % [f, fy, rest_y])
			for u in ["upperarm.l", "upperarm.r"]:
				var uy: float = (bone_at.call("Sit_Chair_Idle", t, u) as Vector3).y
				if uy < shoulder_min:
					why.append("%s %.3f" % [u, uy])
		var down_end: Vector3 = bone_at.call("Sit_Chair_Down", ap.get_animation("Sit_Chair_Down").length, "hips")
		var up_start: Vector3 = bone_at.call("Sit_Chair_StandUp", 0.0, "hips")
		if down_end.distance_to(hips0) > 0.01 or up_start.distance_to(hips0) > 0.01:
			why.append("Down ends %.3f / StandUp starts %.3f from the seat pose" % [down_end.distance_to(hips0), up_start.distance_to(hips0)])
		ap.stop()
	check(why.is_empty(), "the sit re-fit on her %s body: Sit_Chair_Idle's hips at %.2f and 0.40 behind the root, the feet planted, the shoulders ≥ %.2f (%s), Down and StandUp meeting it (wrong: %s)" % ["realistic (REAL-2)" if rl else "anime", hips_want, shoulder_min, "measured: the desk call is Raphael's" if rl else "the desk top + 0.20", why.slice(0, 4)])
	sr.queue_free()


## Test 19, review fixes (2026-10-03): body numbers that would freeze or misplace her fall back to the script's
## constants; a missing anime-look script or an unknown look leaves the body as imported (no crash); with both
## bodies missing a stock KayKit body stands in; anime_look tones what a surface really draws.
func test_staff_review_fixes() -> void:
	print("[Test 19] Staff review fixes: body numbers, the look's guards, the last-resort body, anime_look overrides")
	var data = _read_json(STAFF_DATA_PATH)
	var dm = data.get("roles", {}).get("desk_manager", {}) if data is Dictionary else {}
	var spec = dm.get("variants", {}).get(str(dm.get("default_variant", ""))) if dm is Dictionary and dm.get("variants") is Dictionary else null
	if not spec is Dictionary:
		check(false, "staff.json: the desk_manager's default variant")
		return
	var world := Node3D.new()
	root.add_child(world)
	var make := func(s: Dictionary, look_path: String):
		var x = Node3D.new()
		x.set_script(_staff_variant_script(STAFF_BASE_SCRIPT, s))
		x.role = "desk_manager"
		x.manual_tick = true
		x.hired_at_start_override = 0
		if look_path != "":
			x.anime_look_path = look_path
		world.add_child(x)
		return x
	var a = make.call(spec.duplicate(true), "")
	a._spec["body"] = {"hall_speed": 0, "bar_speed": -0.5, "hip_back": INF, "stool_pull": 0.45, "seated_front": -0.276, "idle_front": "x"}
	var got := [a._body("hall_speed", 0.82), a._body("bar_speed", 0.48), a._body("hip_back", 0.32), a._body("stool_pull", 0.52),
		a._body("seated_front", -0.3), a._body("idle_front", 0.2)]
	check(a.model != null and not a.using_fallback and got == [0.82, 0.48, 0.32, 0.45, -0.276, 0.2],
		"body numbers: 0 / negative / infinite / non-numbers fall back to the script's constants, good ones (and a negative offset) stay %s" % [got])
	var b = make.call(spec.duplicate(true), "res://missing_anime_look.gd")
	var unknown: Dictionary = spec.duplicate(true)
	unknown["look"] = "chibi"
	var c = make.call(unknown, "")
	check(b.model != null and c.model != null and _staff_overrides(b).all(func(m): return m == null) and _staff_overrides(c).all(func(m): return m == null),
		"the anime look's script missing, or an unknown look: the body loads as imported, nothing crashes")
	var lost: Dictionary = spec.duplicate(true)
	lost["model_path"] = "res://missing_body_a.glb"
	lost["fallback_model_path"] = "res://missing_body_b.glb"
	var d = make.call(lost, "")
	var last_resort := str(load(STAFF_BASE_SCRIPT).get_script_constant_map().get("LAST_RESORT_BODY", ""))
	check(d.model != null and d.using_fallback and last_resort != "" and d.model.scene_file_path == last_resort,
		"both bodies missing: a stock KayKit body stands in (%s), never an invisible dealer" % [d.model.scene_file_path if d.model else "none"])
	world.queue_free()
	await process_frame

	var look = load(ANIME_LOOK_SCRIPT)
	var m := Node3D.new()
	var src := StandardMaterial3D.new()
	src.metallic = 0.5
	src.roughness_texture = PlaceholderTexture2D.new()
	src.metallic_texture = PlaceholderTexture2D.new()
	var mi1 := MeshInstance3D.new()
	mi1.mesh = BoxMesh.new()
	(mi1.mesh as BoxMesh).material = src
	var hand := StandardMaterial3D.new()          # an override set by hand (not ours): it is what the surface draws
	mi1.set_surface_override_material(0, hand)
	var mi2 := MeshInstance3D.new()
	mi2.mesh = BoxMesh.new()
	var whole := StandardMaterial3D.new()
	whole.roughness_texture = PlaceholderTexture2D.new()
	mi2.material_override = whole                 # covers every surface: a surface override would never show
	m.add_child(mi1)
	m.add_child(mi2)
	var n1: int = look.apply(m)
	var ov1 = mi1.get_surface_override_material(0)
	var ov2 = mi2.material_override
	var n2: int = look.apply(m)
	check(n1 == 2 and n2 == 0 and look.is_toon(ov1) and look.is_toon(ov2) and ov1.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON
		and ov1.roughness_texture == null and ov1.metallic_texture == null and ov2.roughness_texture == null
		and hand.diffuse_mode != BaseMaterial3D.DIFFUSE_TOON and src.roughness_texture != null,
		"anime_look: a hand-set override and a material_override are toned (%d, again %d), the toon drops the roughness/metal maps, sources untouched" % [n1, n2])
	m.free()
	print("")


# --- Test 20: Dialogue (Story 10.2) ---
# Dialogue Manager conversations in one reusable DialogueBox. Den Fa is the first talker: his E opens
# den_fa.dialogue (first contact once a run, then three early openings). .dialogue files read the game
# only through a thin bridge (counters, reputation, flags) and are linted against it; speakers.json
# maps a line's speaker to a name and a portrait, with a drawn plate while 25.17's portraits are
# missing. The box reads E/Enter/Space/Esc first (_input) so none of them reaches the 3D world, the
# pause menu or a zone while it is open. Never calls hire_adventurer, handle_adventurer_death or
# load_save_data (C5: they spend gold, write the codex, reload the world); GameManager fields a check
# sets are restored.
func test_dialogue() -> void:
	print("[Test 20] Dialogue")
	_t20_ms = Time.get_ticks_msec()
	var gm = root.get_node_or_null("GameManager")
	var dm = root.get_node_or_null("DataManager")
	var snap := {}
	if gm != null:
		for k in GM_DIALOGUE_FIELDS:
			var v = gm.get(k)
			snap[k] = v.duplicate(true) if v is Array or v is Dictionary else v
	_check_dialogue_bridge(gm, dm)
	_check_speakers()
	var files := _check_dialogue_files()
	_check_dialogue_guards()
	var den_res = files.get("den_fa")
	if gm != null and den_res != null:
		await _check_den_fa_walks(gm, den_res)
		await _check_box_layout(den_res)
		await _check_box_robustness()
		await _check_den_fa_box(gm)
	else:
		check(false, "the walks and the box need GameManager and a compiled den_fa.dialogue")
	if gm != null:
		for k in snap:
			gm.set(k, snap[k])
	var secs := (Time.get_ticks_msec() - _t20_ms) / 1000.0
	check(secs <= 10.0, "Test 20 runs in %.1f s of real time (AC 9: ≤ 10 s)" % secs)
	print("")


## The bridge reads GameManager live; the two run counters and the flags save, load and reset (AC 4).
func _check_dialogue_bridge(gm, dm) -> void:
	var bs = load(BRIDGE_SCRIPT) if ResourceLoader.exists(BRIDGE_SCRIPT) else null
	check(bs is GDScript and (bs as GDScript).get_global_name() == "", "dialogue_bridge.gd exists, with no class_name (S8)")
	if not bs is GDScript or gm == null or dm == null or not gm.has_method("_count_hire") or not gm.has_method("_dialogue_save_data"):
		check(false, "the bridge and GameManager's dialogue helpers (_count_hire, _count_death, _dialogue_save_data, _load_dialogue_data, _reset_dialogue_state)")
		return
	var b = (bs as GDScript).new()
	var has_index: bool = gm.has_method("get_reputation_tier_index")
	check(has_index, "GameManager.get_reputation_tier_index(): one function gives the tier index (review patch)")
	var expect := func() -> Dictionary:
		var idx: int = gm.get_reputation_tier_index() if has_index else -1
		return {"reputation": gm.tavern_reputation, "reputation_tier": str(gm.get_reputation_tier().get("label", "")),
			"reputation_tier_index": idx, "day": gm.current_day, "roster_size": gm.adventurers.size(),
			"adventurers_hired": gm.adventurers_hired_this_run, "deaths_this_run": gm.deaths_this_run, "gold": gm.gold,
			"is_demo": str(dm.get_config("profile", "full")) == "demo"}
	var wrong := func() -> Array:
		var want: Dictionary = expect.call()
		return BRIDGE_VALUES.filter(func(k): return typeof(b.get(k)) != typeof(want[k]) or b.get(k) != want[k])
	gm.tavern_reputation = 0
	gm.current_day = 1
	gm.gold = 120
	gm.adventurers = [{"name": "A"}, {"name": "B"}]
	gm.adventurers_hired_this_run = 0
	gm.deaths_this_run = 0
	gm.dialogue_flags = {}
	var fresh: Array = wrong.call()
	check(fresh.is_empty() and b.reputation_tier == "Unknown" and b.reputation_tier_index == 0 and b.roster_size == 2 and b.adventurers_hired == 0,
		"the bridge on a fresh run: every value matches GameManager (wrong: %s)" % [fresh])
	gm._count_hire()
	gm.adventurers.append({"name": "C"})
	var after_hire: Array = wrong.call()
	gm._count_death()
	var after_death: Array = wrong.call()
	gm.tavern_reputation = 25
	var known: Array = [b.reputation_tier, b.reputation_tier_index]
	gm.tavern_reputation = 210
	var honored: Array = [b.reputation_tier, b.reputation_tier_index]
	var after_rep: Array = wrong.call()
	gm.current_day += 1
	var after_day: Array = wrong.call()
	check(after_hire.is_empty() and after_death.is_empty() and after_rep.is_empty() and after_day.is_empty()
		and b.adventurers_hired == 1 and b.deaths_this_run == 1 and b.day == 2 and known == ["Known", 1] and honored == ["Honored", 4],
		"after a hire, a death, reputation changes and a day: the bridge reads them live (tiers %s, %s)" % [known, honored])
	b.set("day", 99)
	b.set("deaths_this_run", 7)
	check(gm.current_day == 2 and gm.deaths_this_run == 1 and b.day == 2, "the bridge's values are read-only: a .dialogue can't write GameManager")
	var unseen: bool = b.seen("t20_flag")
	b.mark_seen("t20_flag")
	check(not unseen and b.seen("t20_flag") and gm.dialogue_flags.get("t20_flag") == true and not b.seen("t20_other"),
		"mark_seen / seen: a conversation flag, kept in GameManager.dialogue_flags")

	var saved = JSON.parse_string(JSON.stringify(gm._dialogue_save_data()))   # as the save file stores it
	gm._reset_dialogue_state()
	var reset_ok: bool = gm.adventurers_hired_this_run == 0 and gm.deaths_this_run == 0 and gm.dialogue_flags.is_empty()
	gm._load_dialogue_data(saved if saved is Dictionary else {})
	check(reset_ok and gm.adventurers_hired_this_run == 1 and gm.deaths_this_run == 1 and typeof(gm.deaths_this_run) == TYPE_INT
		and typeof(gm.adventurers_hired_this_run) == TYPE_INT and gm.dialogue_flags.get("t20_flag") == true,
		"the counters and flags reset, then survive a save → JSON → load round trip as ints (%s)" % [saved])
	gm._load_dialogue_data({"gold": 5})
	var old_ok: bool = gm.adventurers_hired_this_run == 0 and gm.deaths_this_run == 0 and gm.dialogue_flags is Dictionary and gm.dialogue_flags.is_empty()
	gm._load_dialogue_data({"dialogue_flags": "junk", "deaths_this_run": 3.0})
	check(old_ok and gm.dialogue_flags is Dictionary and gm.dialogue_flags.is_empty() and gm.deaths_this_run == 3,
		"an old save without the keys loads 0 / 0 / no flags; a bad flags entry loads as none")
	gm.deaths_this_run = 5
	gm._load_dialogue_data({"adventurers_hired_this_run": null, "deaths_this_run": "junk", "dialogue_flags": {"t20_after_null": true}})
	check(gm.adventurers_hired_this_run == 0 and gm.deaths_this_run == 0 and gm.dialogue_flags.get("t20_after_null") == true,
		"a present-but-null (or junk) counter loads as 0 and doesn't abort the load: the flags after it still load (review patch)")
	if has_index and gm.has_method("reputation_tier_list"):
		var raw := [{"threshold": 50, "label": "Trusted"}, {"threshold": 25, "label": "Known"}, {"threshold": 100, "label": "Respected"}]
		var list: Array = gm.reputation_tier_list(raw)
		var agree := []
		for rep in [0, 10, 25, 49, 50, 99, 100, 500]:
			var i: int = gm.reputation_tier_index_for(rep, list)
			agree.append("%d:%s" % [rep, str(list[i].get("label", "?"))])
		var keep_rep: int = gm.tavern_reputation
		gm.tavern_reputation = 60
		var live_ok: bool = b.reputation_tier_index == gm.get_reputation_tier_index() and b.reputation_tier == str(gm.get_reputation_tier().get("label", "")) \
			and b.reputation_tier == "Trusted" and b.reputation_tier_index == 2
		gm.tavern_reputation = keep_rep
		check(agree == ["0:Unknown", "10:Unknown", "25:Known", "49:Known", "50:Trusted", "99:Trusted", "100:Respected", "500:Respected"]
			and list.size() == 4 and live_ok,
			"unsorted tiers with no threshold-0 entry: sorted, the base tier first, label and index from one list (%s)" % [agree])
	else:
		check(false, "GameManager.reputation_tier_list() / reputation_tier_index_for(): tiers sorted once, label and index agree")
	var src := FileAccess.get_file_as_string(GAME_MANAGER_PATH)
	var hire := _func_body(src, "hire_adventurer")
	var calls := {
		"hire_adventurer → _count_hire() after the roster append": hire.find("_count_hire()") > hire.find("adventurers.append(new_adventurer)") and hire.find("adventurers.append(new_adventurer)") > 0,
		"handle_adventurer_death → _count_death()": _func_body(src, "handle_adventurer_death").contains("_count_death()"),
		"get_save_data → _dialogue_save_data()": _func_body(src, "get_save_data").contains("_dialogue_save_data()"),
		"load_save_data → _load_dialogue_data(data)": _func_body(src, "load_save_data").contains("_load_dialogue_data(data)"),
		"reset_game_state → _reset_dialogue_state()": _func_body(src, "reset_game_state").contains("_reset_dialogue_state()"),
	}
	var missing := calls.keys().filter(func(k): return not calls[k])
	check(missing.is_empty(), "GameManager wires the helpers in (missing: %s)" % [missing])


## speakers.json and the portrait slot's fallback plate (AC 6).
func _check_speakers() -> void:
	var data = _read_json(SPEAKERS_PATH)
	var sp: Dictionary = data.get("speakers", {}) if data is Dictionary and data.get("speakers") is Dictionary else {}
	var bad := []
	for id in ["den_fa", "quest_dealer", "bartender", "elder", "bard"]:
		var e = sp.get(id)
		if not e is Dictionary or str(e.get("name", "")) == "" or not Color.html_is_valid(str(e.get("colour", ""))) \
				or str(e.get("portrait", "")) != "res://assets/characters/portraits/npc/%s.png" % id:
			bad.append(id)
	var others := sp.keys().filter(func(k): return not (sp[k] is Dictionary and str(sp[k].get("name", "")) != ""
		and str(sp[k].get("portrait", "")).begins_with("res://") and Color.html_is_valid(str(sp[k].get("colour", "")))))
	check(data is Dictionary and str(data.get("_note", "")) != "" and bad.is_empty() and others.is_empty(),
		"speakers.json: a _note; den_fa, quest_dealer, bartender, elder and bard (and every other entry) have a name, a portrait under portraits/npc/<id>.png and a colour (wrong: %s)" % [bad + others])
	# Story 25.17 replaced the folder-wide allowlist prefix with per-path entries: Test 22 checks them.
	var bx = load(BOX_SCRIPT) if ResourceLoader.exists(BOX_SCRIPT) else null
	check(bx is GDScript and (bx as GDScript).get_global_name() == "", "dialogue_box.gd exists, with no class_name (S8)")
	if not bx is GDScript or not (bx as GDScript).get_script_method_list().any(func(m): return m.name == "portrait_texture"):
		check(false, "dialogue_box.gd: speaker_id(), display_name(), initials() and portrait_texture()")
		return
	check(bx.speaker_id("Den Fa", PackedStringArray()) == "den_fa" and bx.speaker_id("The Elder", PackedStringArray(["speaker=elder"])) == "elder"
		and bx.speaker_id("Quest Dealer", PackedStringArray(["mood=calm"])) == "quest_dealer",
		"the speaker id: the line's character name lower-cased with spaces to _, or its [#speaker=id] tag")
	check(bx.display_name("den_fa", "Den Fa") == str(sp.get("den_fa", {}).get("name", "?")) and bx.display_name("t20_nobody", "Nobody Here") == "Nobody Here",
		"the name shown: speakers.json's, or the raw character name for an unknown speaker")
	# The plates end to end, through portrait_texture() and the box's _show_speaker(). The cast's portraits exist
	# since Story 25.17 (and the Elder's and the Bard's will), so two synthetic speakers whose PNGs are missing stand
	# in (Story 25.17 review): a mask plate in Den Fa's dark teal (one pale featureless oval, no initials) and a
	# colour plate with initials; each drawn once, cached, warned once a run. They leave the box's table at the end.
	var teal := Color.html(str(sp.get("den_fa", {}).get("colour", "#000000")))
	var fakes := {
		"t20_masked": {"name": "T20 Masked", "portrait": "res://assets/characters/portraits/npc/t20_masked.png", "colour": "#" + teal.to_html(false), "plate": "mask"},
		"t20_plated": {"name": "The T20 Plated", "portrait": "res://assets/characters/portraits/npc/t20_plated.png", "colour": "#5c3458"}}
	var table: Dictionary = bx.speakers()
	for k in fakes:
		table[k] = fakes[k]
	var absent_ok: bool = fakes.values().all(func(f): return not ResourceLoader.exists(str(f.portrait)))
	var m1 = bx.portrait_texture("t20_masked")
	var m2 = bx.portrait_texture("t20_masked")
	var plate_ok := false
	if m1 is ImageTexture:
		var img: Image = (m1 as ImageTexture).get_image()
		var c := img.get_size() / 2
		var inside := [img.get_pixel(c.x, c.y), img.get_pixel(c.x, c.y - 30), img.get_pixel(c.x, c.y + 30), img.get_pixel(c.x - 18, c.y)]
		var corner := img.get_pixel(12, 12)
		plate_ok = img.get_size() == Vector2i(160, 160) and inside.all(func(p): return p == inside[0]) and inside[0].get_luminance() > 0.7 \
			and corner.is_equal_approx(teal) and teal.get_luminance() < 0.35
	var p1 = bx.portrait_texture("t20_plated")
	var p2 = bx.portrait_texture("t20_plated")
	var plated_ok: bool = p1 is ImageTexture and (p1 as ImageTexture).get_image().get_pixel(12, 12).to_html(false) == "5c3458"   # 8-bit: no float round trip
	var shown := {}
	var box_scene = load(BOX_SCENE) if ResourceLoader.exists(BOX_SCENE) else null
	if box_scene is PackedScene:
		var vp := SubViewport.new()
		vp.disable_3d = true
		root.add_child(vp)
		var box = (box_scene as PackedScene).instantiate()
		vp.add_child(box)
		for id in fakes:
			box._show_speaker(DialogueLine.new({"id": "t20_%s" % id, "next_id": "", "type": DMConstants.TYPE_DIALOGUE,
				"character": str(fakes[id].name), "text": "Hm.", "tags": PackedStringArray(["speaker=%s" % id])}))
			shown[id] = [box.portrait.texture, box.initials_label.visible, box.initials_label.text, box.character_label.text]
		box.close("test")
		vp.queue_free()
	for k in fakes:
		table.erase(k)
	check(absent_ok and plate_ok and m1 == m2 and bx.warned_portraits.get("t20_masked", 0) == 1 and shown.get("t20_masked", []) == [m1, false, "TM", "T20 Masked"],
		"a mask speaker whose portrait is missing: through portrait_texture() and the box, a 160 px plate in Den Fa's dark teal with one pale featureless oval, no initials, cached, warned once (%s)" % [shown.get("t20_masked")])
	check(plated_ok and p1 == p2 and bx.warned_portraits.get("t20_plated", 0) == 1 and shown.get("t20_plated", []) == [p1, true, "TP", "The T20 Plated"],
		"a speaker whose portrait is missing: through portrait_texture() and the box, a drawn plate in its colour with its initials, cached, warned once (%s; corner %s, warned %d)" % [
		shown.get("t20_plated"), (p1 as ImageTexture).get_image().get_pixel(12, 12).to_html(false) if p1 is ImageTexture else p1, bx.warned_portraits.get("t20_plated", 0)])
	var u = bx.portrait_texture("t20_nobody")
	var u2 = bx.portrait_texture("t20_nobody")
	check(u is ImageTexture and u == u2 and bx.warned_portraits.get("t20_nobody", 0) == 1 and bx.initials("The Quest Dealer") == "QD" and bx.initials("Den Fa") == "DF",
		"an unknown speaker: a neutral plate, one warning; plates carry initials (QD, DF)")


## Every .dialogue compiles headless and passes the bridge lint (C2); the settings; the old lines file is gone.
func _check_dialogue_files() -> Dictionary:
	var out := {}
	var files: Array[String] = []
	var dir := DirAccess.open(DIALOGUE_DIR)
	if dir != null:
		for f in dir.get_files():
			if f.get_extension() == "dialogue":
				files.append(DIALOGUE_DIR + f)
	check(files.has(DEN_FA_DIALOGUE), "data/dialogue/ holds den_fa.dialogue (%s)" % [files.map(func(f): return f.get_file())])
	var broken := []
	for f in files:
		var r = DMCompiler.compile_string(FileAccess.get_file_as_string(f), f)
		if not r.errors.is_empty():
			broken.append("%s: %d" % [f.get_file(), r.errors.size()])
		elif f == DEN_FA_DIALOGUE:
			out["den_fa"] = r
	var titles: Dictionary = out["den_fa"].titles if out.has("den_fa") else {}
	check(broken.is_empty() and DEN_FA_TITLES.all(func(t): return titles.has(t)),
		"every .dialogue compiles headless (errors: %s); den_fa has %s (titles %s)" % [broken, DEN_FA_TITLES, titles.keys()])

	var bridge_script = load(BRIDGE_SCRIPT) if ResourceLoader.exists(BRIDGE_SCRIPT) else null
	var names := []
	if bridge_script is GDScript:
		for p in (bridge_script as GDScript).get_script_property_list():
			names.append(p.name)
		for m in (bridge_script as GDScript).get_script_method_list():
			names.append(m.name)
	names = names.filter(func(n): return not str(n).begins_with("_") and not str(n).ends_with(".gd"))
	var banned := []
	var project := FileAccess.get_file_as_string("res://project.godot")
	var autoloads := project.substr(project.find("[autoload]"))
	autoloads = autoloads.substr(0, autoloads.find("\n[", 2))
	for m in RegEx.create_from_string("(?m)^(\\w+)=").search_all(autoloads):
		banned.append(m.get_string(1))
	for c in ProjectSettings.get_global_class_list():
		banned.append(str(c.get("class", "")))
	var control: Array = _dialogue_lint("if bridge.deats_this_run > 0\n\tX: {{GameManager.gold}} [if bridge.day > 1]\ndo bridge.mark_seen(\"x\")\n", names)
	var control2: Array = _dialogue_lint("using SaveSystem\ndo advance_day()\nX: Hi {{self.locals}}. [if toggle_pause_menu()]\n- Go [if not bridge.seen(\"a\") and bridge.day >= 2]\n"
		+ "do wait(\"ui_accept\")\ndo wait(1.5)\nset bridge.day = 3\nif true and bridge.gold > 0 or null == null\n\tX: \"GameManager\" is only a word here.\n", names)
	control2.sort()
	var problems := []
	for f in files:
		for p in _dialogue_lint(FileAccess.get_file_as_string(f), names):
			problems.append("%s: %s" % [f.get_file(), p])
	check(names.has("deaths_this_run") and names.has("mark_seen") and banned.has("GameManager") and control == ["bridge.deats_this_run", "GameManager"],
		"the lint knows the bridge's names and the autoloads and catches a typo and an autoload (%s)" % [control])
	check(control2 == ["advance_day", "self", "toggle_pause_menu", "using SaveSystem", "wait(action)"],
		"the lint: an expression may start only from bridge., literals and keywords: the scene's methods, self, using and wait() on an action are caught (%s)" % [control2])
	check(problems.is_empty(), "lint: every bridge.x in a .dialogue is the bridge's, no other root name, using or wait(action) in a condition, mutation or {{…}} (%s)" % [problems])
	var den_text := FileAccess.get_file_as_string(DEN_FA_DIALOGUE)
	var lower := den_text.to_lower()
	var voice_bad := ["thee", "thou", "thy ", "bard", "beneath the mask", "under the mask"].filter(func(w): return lower.contains(w))
	check(den_text.begins_with("# DRAFT") and voice_bad.is_empty(),
		"den_fa.dialogue is marked DRAFT for Raphael and keeps his voice rules (no %s)" % [voice_bad])

	check(FileAccess.file_exists(DEN_FA_DIALOGUE + ".import"), "den_fa.dialogue.import is there (imported, committed)")
	var runner = load(RUNNER_SCRIPT) if ResourceLoader.exists(RUNNER_SCRIPT) else null
	check(runner is GDScript and (runner as GDScript).get_global_name() == "", "dialogue_runner.gd exists, with no class_name (S8)")
	var loaded = runner.load_dialogue(DEN_FA_DIALOGUE) if runner is GDScript else null
	check(loaded is DialogueResource and DEN_FA_TITLES.all(func(t): return (loaded as DialogueResource).titles.has(t)),
		"the runner loads den_fa.dialogue (the imported resource, or its text compiled) with every title")
	out["runner"] = runner
	var fallback = runner.load_dialogue("res://test/fixtures/dialogue_not_imported.txt") if runner is GDScript else null
	var again = runner.load_dialogue("res://test/fixtures/dialogue_not_imported.txt") if runner is GDScript else null
	check(fallback is DialogueResource and (fallback as DialogueResource).titles.has("hello") and again == fallback,
		"a .dialogue Godot hasn't imported yet (a fresh checkout) is compiled from its text, once (AC 8)")
	var exported_path := "res://data/dialogue/t20_exported.dialogue"   # an export ships the imported resource, not the source text
	var virt: Resource = runner.compile_text("~ hello\nX: Hi.\n=> END\n", "t20_exported") if runner is GDScript else null
	if virt != null:
		virt.take_over_path(exported_path)
	var exported = runner.load_dialogue(exported_path) if runner is GDScript and virt != null else null
	check(virt != null and not FileAccess.file_exists(exported_path) and ResourceLoader.exists(exported_path) and exported == virt,
		"an exported build (a loadable resource, no .dialogue source file) still loads: ResourceLoader first, the text only as the fallback (review patch)")
	check(ProjectSettings.get_setting("dialogue_manager/editor/translations/update_pot_files_automatically", true) == false
		and ProjectSettings.get_setting("dialogue_manager/runtime/advanced/ignore_missing_state_values", false) == false,
		"project.godot: the POT auto-update is off, missing state values stay errors")
	var den_src := FileAccess.get_file_as_string(DEN_FA_SCRIPT_PATH)
	check(not FileAccess.file_exists("res://data/dialogue/den_fa_lines.json") and not den_src.contains("den_fa_lines") and not den_src.contains("PatronSpeechBubble")
		and not den_src.contains("LINES_PATH"), "the placeholder lines file is retired: gone, and Den Fa no longer says lines in a bubble")
	return out


## Problems in one .dialogue text. Every expression (if/elif/while/match/when/do/set lines, [if …], [do …] /
## [set …] and {{…}}) may start only from `bridge.`, literals and keywords: a bridge.<name> the bridge doesn't
## have, any other root name (an autoload, a class, the box itself via self, the scene's methods such as
## advance_day() or toggle_pause_menu()), `using` and wait() on an action (the box takes the action before
## Dialogue Manager's waiter sees it) are problems.
static func _dialogue_lint(text: String, bridge_names: Array) -> Array:
	const ROOTS := ["bridge", "true", "false", "null", "and", "or", "not", "in", "wait"]
	var exprs := []
	var problems := []
	var inline_if := RegEx.create_from_string("\\[if ([^\\]]*)\\]")
	var inline_do := RegEx.create_from_string("\\[(?:do!?|set) ([^\\]]*)\\]")
	var braces := RegEx.create_from_string("\\{\\{(.*?)\\}\\}")
	for raw in text.split("\n"):
		var l := raw.strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		if l == "using" or l.begins_with("using "):
			problems.append(("using " + l.substr(5).strip_edges()).strip_edges())
			continue
		for kw in ["if ", "elif ", "while ", "match ", "when ", "do ", "do! ", "set "]:
			if l.begins_with(kw):
				exprs.append(l.substr(kw.length()))
		for re in [inline_if, inline_do, braces]:
			for m in (re as RegEx).search_all(l):
				exprs.append(m.get_string(1))
	var member := RegEx.create_from_string("bridge\\s*\\.\\s*(\\w+)")
	var word := RegEx.create_from_string("[A-Za-z_]\\w*")
	var wait_action := RegEx.create_from_string("\\bwait\\s*\\(\\s*[\"'\\[]")
	for e in exprs:
		if wait_action.search(e) != null and not problems.has("wait(action)"):
			problems.append("wait(action)")
		var bare := RegEx.create_from_string("\"[^\"]*\"|'[^']*'").sub(e, "\"\"", true)   # names inside strings don't count
		for m in member.search_all(bare):
			if not bridge_names.has(m.get_string(1)) and not problems.has("bridge.%s" % m.get_string(1)):
				problems.append("bridge.%s" % m.get_string(1))
		for m in word.search_all(bare):
			var before := bare.substr(0, m.get_start()).strip_edges(false, true)
			if before.ends_with(".") or (before != "" and before[before.length() - 1].is_valid_int()):
				continue   # a member (bridge.day, x.y) or a number's suffix (1e3)
			var w := m.get_string()
			if not ROOTS.has(w) and not problems.has(w):
				problems.append(w)
	return problems


## Each Den Fa title walked to its end with the bridge in three states, every reply in turn (AC 5, AC 9).
func _check_den_fa_walks(gm, res) -> void:
	var dmgr = root.get_node_or_null("DialogueManager")
	var runner = load(RUNNER_SCRIPT) if ResourceLoader.exists(RUNNER_SCRIPT) else null
	if res == null or dmgr == null or runner == null:
		check(false, "the Den Fa walks: den_fa.dialogue compiled, the DialogueManager autoload, the runner")
		return
	var resource = runner.compile_text(FileAccess.get_file_as_string(DEN_FA_DIALOGUE), DEN_FA_DIALOGUE)
	var gated := {"first_contact": "lost someone already", "early_1": "saying your guild's name", "early_3": "9 days."}
	var states := [
		["fresh run", 0, 0, 1, {}],
		["a death, Trusted, day 9", 1, 50, 9, {}],
		["flags already seen", 0, 0, 1, {"den_fa_first_contact": true}],
	]
	var why := []
	var walks := 0
	var replies_seen := {}
	var first_marked := false
	for st in states:
		for title in DEN_FA_TITLES:
			for pick in 3:
				gm.deaths_this_run = st[1]
				gm.tavern_reputation = st[2]
				gm.current_day = st[3]
				gm.dialogue_flags = (st[4] as Dictionary).duplicate()
				var w: Dictionary = await _walk_dialogue(dmgr, resource, title, pick, runner.new_bridge())
				walks += 1
				if not w.ended:
					why.append("%s/%s/%d: no end" % [st[0], title, pick])
				for r in w.replies:
					replies_seen["%s:%s" % [title, r]] = true
				var joined := "\n".join(w.texts)
				if gated.has(title):
					var want: bool = st[0] == "a death, Trusted, day 9"
					if joined.contains(gated[title]) != want:
						why.append("%s/%s: gated line '%s' %s" % [st[0], title, gated[title], "missing" if want else "shown"])
				if title == "first_contact" and st[0] == "fresh run" and gm.dialogue_flags.get("den_fa_first_contact") == true:
					first_marked = true
				if w.menus == 0:
					break   # no replies in this title: one walk is all of it
	# The replies in these titles, each title counted from its own start to the next title's, wherever it sits
	# in the file (Story 10.3 review: no dependence on title order; the Mid/Late titles are Test 21's).
	var menus_total := 0
	var title_starts := []
	for t in (res.titles as Dictionary).keys():
		if str(res.titles[t]).is_valid_int():
			title_starts.append(int(res.titles[t]))
	for t in DEN_FA_TITLES:
		var from := int(res.titles.get(t, -1))
		var to := 1 << 30
		for s in title_starts:
			if s > from:
				to = mini(to, s)
		for id in (res.lines as Dictionary).keys():
			if from >= 0 and str(res.lines[id].get("type", "")) == "response" and str(id).is_valid_int() and int(id) >= from and int(id) < to:
				menus_total += 1
	check(why.is_empty() and walks >= 24, "%d walks: every title ends in every state and reply; gated lines only where allowed %s" % [walks, why.slice(0, 4)])
	check(first_marked and replies_seen.size() == menus_total and menus_total >= 5,
		"first contact marks itself seen; every reply was picked (%d of %d)" % [replies_seen.size(), menus_total])
	var fc_text := FileAccess.get_file_as_string(DEN_FA_DIALOGUE)
	var fc_at := fc_text.find("\n~ first_contact\n")
	var fc := fc_text.substr(fc_at, fc_text.find("\n~ early_1\n") - fc_at) if fc_at >= 0 else ""
	var fc_replies := 0
	for l in fc.split("\n"):
		if l.begins_with("- "):
			fc_replies += 1
	var early_titles: int = runner.count_numbered(resource, "early_")
	check(fc.contains("do bridge.mark_seen(\"den_fa_first_contact\")") and fc.find("do bridge.mark_seen") < fc.find("Den Fa:") and fc_replies >= 2 and early_titles >= 3,
		"first contact marks itself seen on its first line (S5) and offers %d flavour replies; %d early openings (≥ 3)" % [fc_replies, early_titles])


## One walk of a title: always the reply at `pick` (or the last); the texts said, replies picked, menus met.
func _walk_dialogue(dmgr, resource, title: String, pick: int, bridge) -> Dictionary:
	var states := [{"bridge": bridge}]
	var texts := []
	var replies := []
	var menus := 0
	var line = await dmgr.get_next_dialogue_line(resource, title, states)
	var steps := 0
	while line != null and steps < 40:
		steps += 1
		texts.append(line.text)
		if line.responses.size() > 0:
			menus += 1
			var allowed: Array = line.responses.filter(func(r): return r.is_allowed)
			var r = allowed[mini(pick, allowed.size() - 1)]
			replies.append(r.text)
			line = await dmgr.get_next_dialogue_line(resource, r.next_id, states)
		else:
			line = await dmgr.get_next_dialogue_line(resource, line.next_id, states)
	return {"texts": texts, "replies": replies, "menus": menus, "ended": line == null}


## The box on its own, in a 1920×1080 viewport: layer, process mode, the voice player, the house style,
## the layout with a 6-reply menu and a line 30 % longer than the longest authored line (AC 2, AC 7).
func _check_box_layout(den_res) -> void:
	var runner = load(RUNNER_SCRIPT) if ResourceLoader.exists(RUNNER_SCRIPT) else null
	var scene = load(BOX_SCENE) if ResourceLoader.exists(BOX_SCENE) else null
	if not scene is PackedScene or runner == null or den_res == null:
		check(false, "DialogueBox.tscn loads")
		return
	var longest := ""
	for line in (den_res.lines as Dictionary).values():
		if str(line.get("type", "")) == "dialogue" and str(line.get("text", "")).length() > longest.length():
			longest = str(line.text)
	var long_text := longest
	while long_text.length() < int(ceil(longest.length() * 1.3)):
		long_text += " and more"
	var fixture: Resource = runner.compile_text("~ long\nDen Fa: %s\n- Reply one\n- Reply two\n- Reply three\n- Reply four\n- Reply five\n- Reply six\n=> END\n" % long_text, "t20_layout")
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.disable_3d = true
	root.add_child(vp)
	var box = (scene as PackedScene).instantiate()
	vp.add_child(box)
	var sfx: AudioStreamPlayer = box.get_node_or_null("%AudioStreamPlayer")
	check(box.layer == 110 and box.process_mode == Node.PROCESS_MODE_ALWAYS and sfx != null and sfx.bus == &"SFX" and sfx.stream == null and not sfx.autoplay,
		"the box: CanvasLayer 110 (over the prompt UI's 100, under Settings/Codex), runs while paused, a silent voice player on SFX (layer %d)" % box.layer)
	var theme: Theme = box.balloon.theme if box.get("balloon") != null else null
	var panel = theme.get_stylebox("panel", "PanelContainer") if theme != null else null
	check(panel is StyleBoxFlat and (panel as StyleBoxFlat).bg_color.is_equal_approx(Color(0.12, 0.11, 0.10)) and (panel as StyleBoxFlat).border_color.is_equal_approx(Color(0.8, 0.65, 0.3, 0.6))
		and (panel as StyleBoxFlat).border_width_top == 2 and (panel as StyleBoxFlat).corner_radius_top_left == 8
		and theme.get_color("default_color", "DialogueSpeaker").is_equal_approx(Color(0.9, 0.75, 0.4)) and box.character_label.theme_type_variation == &"DialogueSpeaker"
		and not FileAccess.get_file_as_string(BOX_SCRIPT).contains("add_theme_"),
		"the house panel style (the morning briefing's), all in the box's one Theme: no colour code in the script")
	box.start(fixture, "long", [{"bridge": runner.new_bridge()}])
	var t0 := Time.get_ticks_msec()
	while not box.responses_menu.visible and Time.get_ticks_msec() - t0 < 3000:
		if box.dialogue_label.is_typing:
			box.dialogue_label.skip_typing()
		await process_frame
	await process_frame
	await process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(vp.size))
	var band: Rect2 = (box.get_node("%Band") as Control).get_global_rect()
	var label: Rect2 = box.dialogue_label.get_global_rect()
	var items: Array = box.responses_menu.get_menu_items()
	var why := []
	if not screen.encloses(band):
		why.append("band %s off screen" % band)
	if band.size.x < 0.6 * screen.size.x:
		why.append("band %.0f px wide" % band.size.x)
	if band.position.y < screen.size.y * 0.3 or band.end.y < screen.size.y - 100:
		why.append("band not at the bottom %s" % band)
	if not band.encloses(label) or box.dialogue_label.get_content_height() > label.size.y + 1:
		why.append("text clipped or outside (%d > %.0f)" % [box.dialogue_label.get_content_height(), label.size.y])
	if items.size() != 6 or not items.all(func(i): return band.encloses((i as Control).get_global_rect())):
		why.append("%d replies, some outside the band" % items.size())
	var portrait_rect: Rect2 = box.portrait.get_global_rect()
	if box.portrait.texture == null or portrait_rect.size.x < 150 or portrait_rect.end.x > label.position.x or not band.encloses(portrait_rect):
		why.append("portrait slot %s" % portrait_rect)
	if box.character_label.text != "Den Fa":
		why.append("name '%s'" % box.character_label.text)
	check(why.is_empty(), "layout at 1920×1080: a bottom band (%.0f px wide), portrait left of the text, a %d-char line (1.3× the longest) and 6 replies inside it %s"
		% [band.size.x, long_text.length(), why])
	var focused := box.get_viewport().gui_get_focus_owner()
	check(not items.is_empty() and focused == items[0], "the first reply has the focus")
	var blocker = box.get_node_or_null("%MouseBlocker")
	box.balloon.hide()                    # what a long mutation does: the balloon goes, the blocker stays
	var blocker_ok: bool = blocker is Control and (blocker as Control).visible and (blocker as Control).mouse_filter == Control.MOUSE_FILTER_STOP \
		and (blocker as Control).get_global_rect().encloses(screen) and blocker.get_index() < box.balloon.get_index()
	check(blocker_ok, "a full-screen mouse blocker under the balloon stays while the balloon hides for a long mutation: clicks never reach the HUD or the world (review patch)")
	box.balloon.show()
	box.close("test")
	var plain = (scene as PackedScene).instantiate()   # a line with no replies: the continue arrow once it is typed
	vp.add_child(plain)
	plain.start(runner.compile_text("~ plain\nDen Fa: Short.\n=> END\n", "t20_plain"), "plain", [{"bridge": runner.new_bridge()}])
	await process_frame
	await process_frame
	var arrow_while_typing: bool = plain.progress.visible
	plain.dialogue_label.skip_typing()
	await process_frame
	check(not arrow_while_typing and plain.progress.visible and not plain.responses_menu.visible, "the continue arrow shows once a line without replies has typed out")
	plain.close("test")
	vp.queue_free()
	await process_frame


## Review patches (2026-10-03) on the box alone: a line whose replies are all hidden; the start is deferred so
## callers connect before anything can close; Dialogue Manager stalling after the first line (the progress
## watchdog); a box closed while next() is pending stays until it returns; a timed line closed early; a box
## freed by its world still says `closed`.
func _check_box_robustness() -> void:
	var runner = load(RUNNER_SCRIPT) if ResourceLoader.exists(RUNNER_SCRIPT) else null
	var scene = load(BOX_SCENE) if ResourceLoader.exists(BOX_SCENE) else null
	if runner == null or not scene is PackedScene:
		check(false, "the box robustness checks need the runner and DialogueBox.tscn")
		return
	var host := Node.new()
	host.name = "T20Host"
	root.add_child(host)
	var new_box := func():
		var b = (scene as PackedScene).instantiate()
		host.add_child(b)
		return b
	var typed := func(b) -> void:      # wait for the current line, finishing its typing
		var t0 := Time.get_ticks_msec()
		while is_instance_valid(b) and not b.is_closed() and Time.get_ticks_msec() - t0 < 2000:
			if b.dialogue_line != null and not b.dialogue_label.is_typing:
				break
			if b.dialogue_line != null:
				b.dialogue_label.skip_typing()
			await process_frame
		await process_frame
	var src := FileAccess.get_file_as_string(BOX_SCRIPT)

	# Every reply hidden: the line is an ordinary line (no empty menu, the continue arrow; E goes on; Esc closes even on [#required]).
	var none_res: Resource = runner.compile_text("~ none\nX: Pick. [#required]\n- A [if false]\n\tX: Never.\n- B [if false]\n\tX: Never.\nX: After.\n=> END\n", "t20_none")
	var nb = new_box.call()
	nb.start(none_res, "none", [{"bridge": runner.new_bridge()}])
	await typed.call(nb)
	var none_menu: bool = nb.responses_menu.visible or not nb.responses_menu.get_menu_items().is_empty()
	var none_arrow: bool = nb.progress.visible
	nb._advance()
	await typed.call(nb)
	var after: String = nb.dialogue_line.text if is_instance_valid(nb) and nb.dialogue_line != null else ""
	if is_instance_valid(nb):
		nb.close("test")
	var nb2 = new_box.call()
	nb2.start(none_res, "none", [{"bridge": runner.new_bridge()}])
	await typed.call(nb2)
	nb2._cancel()
	var esc_closed: bool = not is_instance_valid(nb2) or nb2.is_closed()
	check(not none_menu and none_arrow and after == "After." and esc_closed,
		"all replies hidden: no empty menu, the continue arrow, E goes on ('%s'), Esc ends it even on a [#required] line (review patch)" % after)

	# The start is deferred: an empty title still returns the box; the caller connects, then it closes once, with no line shown.
	var empty_res: Resource = runner.compile_text("~ nothing\n=> END\n", "t20_nothing")
	var eb = runner.open(host, empty_res, "nothing")
	var eb_opened: bool = eb != null and eb.has_signal("first_line")   # (a freed box reads as null later)
	var ev := {"closed": 0, "first": 0}
	if eb != null:
		eb.closed.connect(func(): ev.closed += 1)
		if eb.has_signal("first_line"):
			eb.connect("first_line", func(): ev.first += 1)
	for i in 4:
		await process_frame
	check(eb_opened and ev.closed == 1 and ev.first == 0 and not runner.is_open(),
		"a title with nothing to say: the box opens deferred, so the caller hears `closed` once, and never `first_line` (review patch; %s)" % [ev])

	# Dialogue Manager stalls after the first line: the progress watchdog closes the box; it stays (out of the
	# groups) until the pending next() returns, then frees itself; another box can open meanwhile.
	var hang = _hang_script().new()
	var slow_res: Resource = runner.compile_text("~ slow\nX: First.\nif t20_hang.hang()\n\tX: Never.\nX: Never either.\n=> END\n", "t20_slow")
	var wb = new_box.call()
	var default_timeout = wb.get("progress_timeout_ms")
	wb.set("progress_timeout_ms", 300)
	wb.start(slow_res, "slow", [{"bridge": runner.new_bridge(), "t20_hang": hang}])
	await typed.call(wb)
	var first_ok: bool = wb.dialogue_line != null and wb.dialogue_line.text == "First."
	wb._advance()
	await create_timer(0.6).timeout
	var stalled_closed: bool = is_instance_valid(wb) and wb.is_closed()
	var kept: bool = is_instance_valid(wb) and not wb.is_queued_for_deletion() and not wb.is_in_group("dialogue_open") and not wb.is_in_group("blocks_player")
	var other = runner.open(host, runner.compile_text("~ hi\nX: Hi.\n=> END\n", "t20_hi"), "hi")
	var other_ok: bool = other != null
	if other != null:
		other.close("test")
	hang.release.emit(true)
	for i in 3:
		await process_frame
	check(first_ok and default_timeout == 10000 and stalled_closed and kept and other_ok and not is_instance_valid(wb) and not src.contains("START_TIMEOUT"),
		"Dialogue Manager stalls after a line: closed by the progress watchdog (10 s by default, %s); kept until the pending next() returns, then freed; another box can open (review patch)" % [default_timeout])

	# A timed line ([next=…]) closed before its time: nothing resumes on the freed box (a timer connected to a method, no await).
	var tb = new_box.call()
	tb.start(runner.compile_text("~ timed\nX: Tick. [next=0.2]\nX: Tock.\n=> END\n", "t20_timed"), "timed", [{"bridge": runner.new_bridge()}])
	await typed.call(tb)
	tb.close("test")
	await create_timer(0.35).timeout
	check(not is_instance_valid(tb) and not src.contains("await get_tree().create_timer") and not src.contains("await audio_stream_player.finished"),
		"a timed line closed early: the box is gone and no await resumes on it (the line timer and the voice end call methods) (review patch)")

	# Freed by its world (a scene change) while open: talkers still hear `closed`.
	var world := Node.new()
	root.add_child(world)
	var fb = (scene as PackedScene).instantiate()
	world.add_child(fb)
	fb.start(runner.compile_text("~ plain\nX: Plain.\n=> END\n", "t20_plain2"), "plain", [{"bridge": runner.new_bridge()}])
	await typed.call(fb)
	var freed := [0]
	fb.closed.connect(func(): freed[0] += 1)
	world.free()
	await process_frame
	check(freed[0] == 1 and get_nodes_in_group("dialogue_open").is_empty(), "a box freed with its world says `closed` once and leaves no group behind (review patch)")
	host.queue_free()
	await process_frame


## An object for Test 20's stall fixture: hang() waits until `release` is emitted (Dialogue Manager awaits it).
static func _hang_script() -> GDScript:
	var gs := GDScript.new()
	gs.source_code = """extends RefCounted
signal release(v)
func hang():
	var v = await release
	return v
"""
	gs.reload()
	return gs


## Every other E (and Esc) reader stands down while a box is open (AC 3; the box takes the keys first, these
## are the second guard) and the player's polled jump skips the frame a box closed (S2).
func _check_dialogue_guards() -> void:
	var read := func(path: String) -> String:
		return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var bodies := {
		"ZonePromptUI._gate_open": _func_body(read.call("res://scripts/game/ZonePromptUI.gd"), "_gate_open"),
		"den_fa.can_talk": _func_body(read.call(DEN_FA_SCRIPT_PATH), "can_talk"),
		"the_cat.can_be_petted": _func_body(read.call(CAT_SCRIPT_PATH), "can_be_petted"),
		"zone_interactions._input": _func_body(read.call("res://scripts/game/zone_interactions.gd"), "_input"),
		"exit_zone_interior._unhandled_input": _func_body(read.call(EXIT_ZONE_SCRIPT_PATH), "_unhandled_input"),
		"main_tavern._input": _func_body(read.call("res://scripts/game/main_tavern.gd"), "_input"),
		"player._unhandled_input (the ui_accept serve)": _func_body(read.call("res://scripts/player/player.gd"), "_unhandled_input"),
	}
	var missing := bodies.keys().filter(func(k): return not _code_lines(str(bodies[k])).contains("dialogue_open"))
	var pl: String = read.call("res://scripts/player/player.gd")
	var jump_ok := _code_lines(_func_body(pl, "_jump_blocked")).contains("blocks_player") and _code_lines(_func_body(pl, "_jump_blocked")).contains("just_closed()") \
		and _code_lines(_func_body(pl, "_physics_process")).contains("_jump_blocked()")
	check(missing.is_empty() and jump_ok, "while a box is open every other E/Esc reader stands down (code, not comments), and the player's jump skips a box's closing frame (missing: %s, jump %s)" % [missing, jump_ok])
	var mt := _code_lines(str(bodies["main_tavern._input"])).split("\n")   # the debug keys too: F10 would wipe the run's flags mid-conversation
	var guard_at := -1
	var f9_at := -1
	for i in mt.size():
		if guard_at < 0 and mt[i].contains("dialogue_open") and not mt[i].contains("ui_cancel"):
			guard_at = i
		if f9_at < 0 and mt[i].contains("KEY_F9"):
			f9_at = i
	check(guard_at >= 0 and f9_at > guard_at, "main_tavern._input stands down for every key while a box is open (B, F9, F10 too), before the debug keys (guard line %d, F9 line %d)" % [guard_at, f9_at])
	var tab_ok := BOX_ACTIONS_EXTRA.all(func(a): return _code_lines(read.call(BOX_SCRIPT)).contains("\"%s\"" % a))
	check(tab_ok, "the box also takes Tab / Shift+Tab (ui_focus_next/prev: the roster's toggle and the reply focus) while it is open")


## E on Den Fa in a small tavern-like world (the 3D world inside a SubViewportContainer, as MainTavern):
## one box opens; while it is open no E/Enter/Space/Esc/jump reaches the scene root or the 3D world (two
## spies), no zone owns E, the prompt is hidden, the real player can't move or jump; replies by keyboard;
## Esc ends it; the closing key does nothing else; failures leave nothing open (AC 1, 3, 8; S11).
func _check_den_fa_box(gm) -> void:
	var runner = load(RUNNER_SCRIPT) if ResourceLoader.exists(RUNNER_SCRIPT) else null
	if runner == null or not ResourceLoader.exists(BOX_SCENE) or not ResourceLoader.exists(PLAYER_SCENE):
		check(false, "the Den Fa box world: the runner, DialogueBox.tscn and Player.tscn")
		return
	var world := Node3D.new()
	world.name = "T20World"
	root.add_child(world)
	current_scene = world
	var root_spy := Node.new()            # first child: where main_tavern._input (Esc, B, F9, F10) sits in the order
	root_spy.name = "RootSpy"
	root_spy.set_script(_input_spy_script())
	world.add_child(root_spy)
	var ui = load("res://scripts/game/ZonePromptUI.gd").new()
	world.add_child(ui)
	var svc := SubViewportContainer.new()
	svc.size = Vector2(320, 180)
	world.add_child(svc)
	var sv := SubViewport.new()
	sv.size = Vector2i(320, 180)
	svc.add_child(sv)
	var ground := StaticBody3D.new()
	var gshape := CollisionShape3D.new()
	gshape.shape = BoxShape3D.new()
	(gshape.shape as BoxShape3D).size = Vector3(30, 1, 30)
	ground.add_child(gshape)
	ground.position = Vector3(0, -0.4, -6)  # top at y 0.1, the tavern floor
	sv.add_child(ground)
	var fire := Area3D.new()
	var fire_shape := CollisionShape3D.new()
	fire_shape.shape = BoxShape3D.new()
	(fire_shape.shape as BoxShape3D).size = Vector3(2.7, 2.2, 2.8)
	fire_shape.position = Vector3(0, 1.1, 0)
	fire.add_child(fire_shape)
	fire.position = Vector3(-3.55, 0, -9.3)
	sv.add_child(fire)
	ui.register_zone(fire, "Press E - Tend Fire", FIRE_ANCHOR)
	var cat = (load(CAT_SCENE_PATH) as PackedScene).instantiate()
	sv.add_child(cat)
	cat.position = CAT_WORLD
	var marker := Marker3D.new()
	sv.add_child(marker)
	marker.transform = _hearth_sit_point_world()
	var den = (load(DEN_FA_SCENE_PATH) as PackedScene).instantiate()
	sv.add_child(den)
	var player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	sv.add_child(player)
	player.global_position = Vector3(-3.4, 0.95, -4.0)
	var world_spy := Node.new()           # in the 3D world: where Den Fa, the cat, the fire, the bar and ExitArea read keys
	world_spy.name = "WorldSpy"
	world_spy.set_script(_input_spy_script())
	sv.add_child(world_spy)
	var settle := func(frames: int) -> void:
		for i in frames:
			await physics_frame
		await process_frame
	await settle.call(40)
	if not den.has_method("_pick_title") or den.get("dialogue_path") == null:
		check(false, "den_fa.gd: dialogue_path and _pick_title()")
		current_scene = null
		world.queue_free()
		await process_frame
		return
	den.sit_at(marker)
	await settle.call(4)
	var talk: Area3D = den.get_node("TalkZone")
	var zones := {"fire": fire, "cat": cat._zone, "den_fa": talk}
	var owners := func() -> Array:
		return zones.keys().filter(func(k): return ui.owns_e(zones[k]))
	var boxes := func() -> Array:
		return get_nodes_in_group("dialogue_open")

	gm.den_fa_state = "early"          # Story 10.3: these checks are his Early conversation (restored with the snapshot)
	gm.dialogue_flags = {"den_fa_first_contact": true}
	var picks := []
	for i in 12:
		picks.append(den._pick_title())
	var repeats := 0
	for i in range(1, picks.size()):
		if picks[i] == picks[i - 1]:
			repeats += 1
	var distinct := {}
	for p in picks:
		distinct[p] = true
	gm.dialogue_flags = {}
	var fresh: String = den._pick_title()
	check(fresh == "first_contact" and repeats == 0 and distinct.size() == 3 and picks.all(func(p): return ["early_1", "early_2", "early_3"].has(p)),
		"his title: first contact until it is seen, then early_1…3, never the same opening twice in a row (%s)" % [picks.slice(0, 6)])
	var gaps: Resource = runner.compile_text("~ early_1\nDen Fa: One.\n=> END\n\n~ early_4\nDen Fa: Four.\n=> END\n", "t20_gaps")
	var gap_picks := {}
	for i in 24:
		gap_picks[den._pick_title(gaps)] = true
	var gap_titles := gap_picks.keys()
	gap_titles.sort()
	var nothing: Resource = runner.compile_text("~ other\nDen Fa: Hm.\n=> END\n", "t20_no_titles")
	var none1: String = den._pick_title(nothing)
	var none2: String = den._pick_title(nothing)
	check(gap_titles == ["early_1", "early_4"] and none1 == "" and none2 == "" and den.get("_warned_no_titles") == true,
		"a file without first_contact falls back to its early openings, the real ones (early_1 and early_4 across a gap: %s); none at all: no title, warned once (review patch)" % [gap_titles])

	await _press("ui_cancel")             # with no box open the spies do see keys
	var control_ok: bool = root_spy.count("ui_cancel") > 0 and world_spy.count("ui_cancel") > 0
	root_spy.seen.clear()
	world_spy.seen.clear()
	player.global_position = Vector3(-3.4, 0.95, -7.9)
	await settle.call(10)
	check(control_ok and owners.call() == ["den_fa"] and ui.prompt_label.visible and ui.prompt_label.text == den.PROMPT and player.is_on_floor(),
		"beside Den Fa, on the floor: E and the prompt are his; the spies see keys while no box is open")
	var talks := [0]
	den.talked.connect(func(_s): talks[0] += 1)
	gm.deaths_this_run = 0
	await _press("interact")
	var open_now: Array = boxes.call()
	var box = open_now[0] if open_now.size() == 1 else null
	var bubbles: int = den.get_children().filter(func(c): return c is PatronSpeechBubble).size()
	check(box != null and box.start_from_title == "first_contact" and box.get_parent() == world and talks[0] == 1 and bubbles == 0,
		"a real E beside him opens one box (first contact, in the current scene), talked once, no speech bubble (%d boxes)" % open_now.size())
	if box == null:
		_close_test_world(world)
		await process_frame
		return
	root_spy.seen.clear()                 # the opening press reached the world (that is how he heard it); from here on nothing may
	world_spy.seen.clear()
	await settle.call(2)
	check(not ui.prompt_label.visible and owners.call().is_empty() and not den.can_talk() and not cat.can_be_petted()
		and gm.dialogue_flags.get("den_fa_first_contact") == true,
		"while it is open: the prompt is hidden, no zone owns E (fire, cat, Den Fa); first contact is already marked seen")
	var p0: Vector3 = player.global_position
	Input.action_press("move_forward")
	Input.action_press("jump")
	await settle.call(8)
	Input.action_release("move_forward")
	Input.action_release("jump")
	var moved := Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
	var rose: float = player.global_position.y - p0.y
	await _press("interact")              # a second E: finishes the typing, never a second box or talk
	check(moved < 0.01 and rose < 0.02 and boxes.call().size() == 1 and talks[0] == 1,
		"the player can't move (%.3f m) or jump (%.3f m); a second E opens nothing and doesn't talk again" % [moved, rose])
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(box) and not box.responses_menu.visible and Time.get_ticks_msec() - t0 < 4000:
		await _press("interact")
	var items: Array = box.responses_menu.get_menu_items() if is_instance_valid(box) else []
	var focus_first = root.gui_get_focus_owner()
	await _press("ui_focus_next")         # Tab: the roster's toggle; under the box it neither reaches the HUD nor moves the reply focus
	var focus_after_tab = root.gui_get_focus_owner()
	await _press("ui_down")
	var focus_second = root.gui_get_focus_owner()
	await _press("interact")
	await settle.call(2)
	var said: String = box.dialogue_line.text if is_instance_valid(box) and box.dialogue_line != null else ""
	check(items.size() == 3 and focus_first == items[0] and focus_second == items[1] and said.contains("pillar"),
		"three flavour replies, the first focused; ↓ then E picks the second ('%s')" % said)
	check(focus_after_tab == items[0], "Tab while the box is open: the box takes it, the reply focus stays (review patch)")
	var closes := [0]
	if is_instance_valid(box):
		box.closed.connect(func(): closes[0] += 1)
	await _press("ui_cancel")
	if is_instance_valid(box) and not box.is_closed():
		await _press("ui_cancel")
	var gone_now: bool = boxes.call().is_empty()
	await settle.call(1)
	check(closes[0] == 1 and gone_now, "Esc finishes the typing, then ends the conversation (closed once)")
	check(root_spy.total() == 0 and world_spy.total() == 0,
		"while it was open, no E, Enter, Space, Esc or jump reached the scene root (pause menu, debug keys) or the 3D world (%s / %s)" % [root_spy.seen, world_spy.seen])
	check(ui.prompt_label.visible and ui.prompt_label.text == den.PROMPT and owners.call() == ["den_fa"] and talks[0] == 1 and boxes.call().is_empty() and den._cooldown > 2.0,
		"once it closes: the prompt and E are his again a frame later, nothing reopened, his cooldown starts at the close (%.1f s)" % den._cooldown)

	den._process(den.COOLDOWN + 0.1)      # his cooldown runs out the way it does in play (his own _process)
	await _press("interact")              # an early conversation, advanced with Space: Space is ui_accept AND jump
	var box2 = boxes.call()[0] if boxes.call().size() == 1 else null
	var title2: String = str(box2.start_from_title) if box2 != null else ""
	root_spy.seen.clear()
	world_spy.seen.clear()
	var y0: float = player.global_position.y
	var ys := []
	t0 = Time.get_ticks_msec()
	while is_instance_valid(box2) and not box2.is_closed() and Time.get_ticks_msec() - t0 < 6000:
		await _press_key(KEY_SPACE)
		ys.append(player.global_position.y)
	for i in 12:
		await physics_frame
		ys.append(player.global_position.y)
	var top: float = ys.max() if not ys.is_empty() else INF
	check(title2.begins_with("early_") and boxes.call().is_empty() and talks[0] == 2 and top - y0 < 0.02,
		"again, after first contact: an early opening (%s); Space advances it to the end and the closing Space doesn't jump (rose %.3f m, talked %d)" % [title2, top - y0, talks[0]])
	check(root_spy.total() == 0 and world_spy.total() == 0, "Space never reached the world either (%s / %s)" % [root_spy.seen, world_spy.seen])

	den._process(den.COOLDOWN + 0.1)      # once more, ended with E: the E that closes it reaches nothing and opens nothing
	await _press("interact")
	var box3 = boxes.call()[0] if boxes.call().size() == 1 else null
	var box3_opened: bool = box3 != null
	root_spy.seen.clear()
	world_spy.seen.clear()
	t0 = Time.get_ticks_msec()
	while is_instance_valid(box3) and not box3.is_closed() and Time.get_ticks_msec() - t0 < 6000:
		await _press("interact")
	await settle.call(3)
	check(box3_opened and boxes.call().is_empty() and talks[0] == 3 and root_spy.total() == 0 and world_spy.total() == 0 and den._cooldown > den.COOLDOWN - 0.5,
		"E to the end of a conversation: the closing E reaches neither the scene root nor the world, nothing reopens, his cooldown restarts (talked %d; %s / %s)" % [talks[0], root_spy.seen, world_spy.seen])

	var fx: Resource = runner.compile_text(DIALOGUE_FIXTURE, "t20_fixture")
	var fbox = runner.open(den, fx, "start") if fx != null else null
	var second = runner.open(den, fx, "start") if fx != null else null
	t0 = Time.get_ticks_msec()
	while is_instance_valid(fbox) and not fbox.responses_menu.visible and Time.get_ticks_msec() - t0 < 3000:
		if fbox.dialogue_label.is_typing:
			fbox.dialogue_label.skip_typing()
		await process_frame
	var fitems: Array = fbox.responses_menu.get_menu_items() if is_instance_valid(fbox) else []
	var texts: Array = fitems.map(func(i): return i.text)
	await _press("ui_cancel")
	var held: bool = is_instance_valid(fbox) and not fbox.is_closed()
	check(fbox != null and second == null and boxes.call().size() == 1 and texts == ["Allow", "Refuse"] and held,
		"the fixture: a reply whose condition fails is hidden %s; Esc does nothing on a [#required] choice; a second open is refused" % [texts])
	await _press("interact")
	await settle.call(2)
	var after: String = fbox.dialogue_line.text if is_instance_valid(fbox) and fbox.dialogue_line != null else ""
	await _press("ui_cancel")
	if is_instance_valid(fbox) and not fbox.is_closed():
		await _press("ui_cancel")
	check(after == "Allowed." and boxes.call().is_empty(), "E confirms the focused choice ('%s'); on an ordinary line Esc ends it" % after)

	# A screen over the conversation (review patch): the box lets the keys through while the tree is paused or
	# another player-blocking screen / mission board is up; nothing opens over such a screen, while paused or at Game Over.
	var two: Resource = runner.compile_text("~ c\nX: One.\nX: Two.\n=> END\n", "t20_cover")
	var cb = runner.open(den, two, "c")
	var cb_opened: bool = cb != null
	t0 = Time.get_ticks_msec()
	while is_instance_valid(cb) and (cb.dialogue_line == null or cb.dialogue_label.is_typing) and Time.get_ticks_msec() - t0 < 2000:
		if cb.dialogue_line != null:
			cb.dialogue_label.skip_typing()
		await process_frame
	var cover := Control.new()
	cover.name = "T20Cover"
	cover.add_to_group("blocks_player")
	world.add_child(cover)
	await _press("interact")
	var under_cover: String = cb.dialogue_line.text if is_instance_valid(cb) and cb.dialogue_line != null else ""
	cover.visible = false
	paused = true
	await _press("ui_cancel")
	var held_paused: bool = is_instance_valid(cb) and not cb.is_closed()
	paused = false
	if is_instance_valid(cb):
		cb.close("test")
	await process_frame
	cover.visible = true
	cover.remove_from_group("blocks_player")
	cover.add_to_group("mission_board")
	var over_board = runner.open(den, two, "c")
	cover.queue_free()
	await process_frame
	paused = true
	var while_paused = runner.open(den, two, "c")
	paused = false
	gm.game_over_active = true
	var at_game_over = runner.open(den, two, "c")
	gm.game_over_active = false
	for b in boxes.call():
		b.close("test")
	check(cb_opened and under_cover == "One." and held_paused and over_board == null and while_paused == null and at_game_over == null,
		"a screen over the box: E doesn't advance it ('%s'), Esc doesn't close it while paused (%s); nothing opens over a mission board, while paused or at Game Over (%s) (review patch)"
		% [under_cover, held_paused, [over_board == null, while_paused == null, at_game_over == null]])

	# He stands up or walks off: his open conversation closes first and the player is free (review patch).
	den.talk()
	await settle.call(3)
	var stood_open: int = boxes.call().size()
	den.stand()
	await settle.call(1)
	var after_stand: int = boxes.call().size()
	den.sit_at(marker)
	await settle.call(2)
	den.talk()
	await settle.call(3)
	var walk_open: int = boxes.call().size()
	den.walk_route(PackedVector3Array([den.global_position + Vector3(0.3, 0, 0)]))
	await settle.call(1)
	var after_walk: int = boxes.call().size()
	den.sit_at(marker)
	await settle.call(2)
	check(stood_open == 1 and after_stand == 0 and walk_open == 1 and after_walk == 0 and den._seated,
		"Den Fa stands up or walks off mid-conversation: his box closes first (open %d → %d, %d → %d) (review patch)" % [stood_open, after_stand, walk_open, after_walk])

	var missing = runner.start(den, "res://data/dialogue/t20_missing.dialogue", "x")
	var no_title = runner.start(den, DEN_FA_DIALOGUE, "t20_no_such_title")
	var bad = runner.compile_text("~ x\nX: hi\n- a\n\tX: [if \n=> nowhere\n", "t20_bad")
	await settle.call(3)
	var talks_before: int = talks[0]
	den._process(den.COOLDOWN + 0.1)
	den.dialogue_path = "res://data/dialogue/t20_missing.dialogue"
	await _press("interact")
	var failed_boxes: int = boxes.call().size()
	den._process(den.COOLDOWN + 0.1)
	den.dialogue_path = DIALOGUE_BROKEN_FIXTURE
	await _press("interact")
	var broken_boxes: int = boxes.call().size()
	den._process(den.COOLDOWN + 0.1)
	den.dialogue_path = DIALOGUE_SILENT_FIXTURE
	gm.dialogue_flags = {}
	await _press("interact")
	await settle.call(3)
	var silent_boxes: int = boxes.call().size()
	var silent_talks: int = talks[0]
	den.dialogue_path = DEN_FA_DIALOGUE
	await _press("interact")              # still inside the cooldown the silent conversation restarted: nothing opens
	var early_press: int = boxes.call().size()
	den._process(den.COOLDOWN + 0.1)
	await _press("interact")
	await settle.call(2)
	var reopened: int = boxes.call().size()
	check(missing == null and no_title == null and bad == null and failed_boxes == 0 and broken_boxes == 0 and silent_boxes == 0
		and silent_talks == talks_before and early_press == 0 and reopened == 1 and talks[0] == talks_before + 1,
		"Den Fa's E on a missing file, a file that won't compile, a first contact that says nothing: no box, no talked; within his cooldown E does nothing, after it E talks again (talked %d → %d)" % [talks_before, talks[0]])
	root.get_node("GameBus").game_over_triggered.emit("t20 test")
	await settle.call(2)
	var p1: Vector3 = player.global_position
	Input.action_press("move_forward")
	await settle.call(8)
	Input.action_release("move_forward")
	var walked := Vector2(player.global_position.x - p1.x, player.global_position.z - p1.z).length()
	check(boxes.call().is_empty() and walked > 0.05, "Game Over closes the box; the player walks (%.2f m)" % walked)
	_close_test_world(world)
	await process_frame


# --- Test 21: Den Fa's states (Story 10.3) ---
# GameManager holds Den Fa's state (early -> mid -> late), moved forward only, by adjust_reputation() across the
# reputation tiers named in game_config.json's den_fa_state_tiers (Known, Trusted), saved with the run's dialogue
# data and re-evaluated on load; GuildBus says when it moves. His conversation picks first contact, then the
# state's entry title once, then its openings without repeats. Never calls hire_adventurer,
# handle_adventurer_death or load_save_data; every GameManager field it sets is restored.
func test_den_fa_states() -> void:
	print("[Test 21] Den Fa's states")
	var gm = root.get_node_or_null("GameManager")
	var dm = root.get_node_or_null("DataManager")
	var gb = root.get_node_or_null("GuildBus")
	if gm == null or dm == null or gb == null or not gm.has_method("den_fa_state_for") or not gm.has_method("den_fa_tier_indexes"):
		check(false, "GameManager.den_fa_state_for() / den_fa_tier_indexes() and the GuildBus, DataManager autoloads")
		return
	var snap := {}
	for k in GM_DEN_FA_FIELDS:
		var v = gm.get(k)
		snap[k] = v.duplicate(true) if v is Array or v is Dictionary else v
	_check_den_fa_state_table(gm)
	var th := _check_den_fa_tier_config(gm, dm)
	_check_den_fa_reputation(gm, gb, th)
	_check_den_fa_state_save(gm, gb, th)
	_check_den_fa_debug_panel()
	await _check_den_fa_state_talk(gm, th)
	for k in snap:
		gm.set(k, snap[k])
	print("")


## den_fa_state_for(current, tier_index, mid_index, late_index): every (current, tier) pair; never backwards (DS-2).
func _check_den_fa_state_table(gm) -> void:
	var bad := []
	for cur in DEN_FA_STATE_ORDER + ["bogus", ""]:
		for tier in range(0, 5):
			var want_rank := 2 if tier >= 2 else (1 if tier >= 1 else 0)
			var want: String = DEN_FA_STATE_ORDER[maxi(DEN_FA_STATE_ORDER.find(cur), want_rank)]
			var got: String = gm.den_fa_state_for(cur, tier, 1, 2)
			if got != want:
				bad.append("%s@%d=%s" % [cur, tier, got])
	var equal := [gm.den_fa_state_for("early", 0, 1, 1), gm.den_fa_state_for("early", 1, 1, 1), gm.den_fa_state_for("mid", 4, 1, 1),
		gm.den_fa_state_for("late", 0, 1, 1)]
	check(bad.is_empty() and equal == ["early", "late", "late", "late"],
		"den_fa_state_for: early/mid/late by the tier reached, never backwards from mid or late, an unknown state counts as early; mid == late jumps straight to late (wrong: %s, equal %s)" % [bad, equal])


## The shipped config and the pure resolver (injected tier lists): unknown names, inverted or equal tiers fall
## back to Known/Trusted with a warning; the GameManager wrapper warns once. Returns the thresholds {mid, late}.
func _check_den_fa_tier_config(gm, dm) -> Dictionary:
	var cfg = dm.get_config("den_fa_state_tiers")
	check(cfg is Dictionary and cfg.get("mid") == "Known" and cfg.get("late") == "Trusted" and str(cfg.get("_comment", "")) != "",
		"game_config.json: den_fa_state_tiers {mid: Known, late: Trusted} with a _comment (DS-1)")
	var tiers: Array = gm.reputation_tier_list(dm.get_config("reputation_tiers", []))
	var ok: Dictionary = gm.den_fa_tier_indexes({"mid": "Known", "late": "Trusted"}, tiers)
	var custom: Dictionary = gm.den_fa_tier_indexes({"mid": "Trusted", "late": "Honored"}, tiers)
	var bad_cfgs := {"unknown": {"mid": "Famous", "late": "Trusted"}, "inverted": {"mid": "Trusted", "late": "Known"},
		"equal": {"mid": "Known", "late": "Known"}, "missing": null, "late unknown": {"mid": "Known"}}
	var wrong := []
	for k in bad_cfgs:
		var r: Dictionary = gm.den_fa_tier_indexes(bad_cfgs[k], tiers)
		if r.get("mid") != 1 or r.get("late") != 2 or not str(r.get("warning", "")).begins_with("[GameManager]"):
			wrong.append("%s %s" % [k, r])
	var odd_tiers: Array = gm.reputation_tier_list([{"threshold": 10, "label": "A"}, {"threshold": 20, "label": "B"}])
	var odd: Dictionary = gm.den_fa_tier_indexes({"mid": "X", "late": "Y"}, odd_tiers)
	check(ok.get("mid") == 1 and ok.get("late") == 2 and ok.get("warning") == "" and custom.get("mid") == 2 and custom.get("late") == 4
		and custom.get("warning") == "" and wrong.is_empty() and int(odd.get("late", 0)) > int(odd.get("mid", 0)) and str(odd.get("warning", "")) != "",
		"the resolver: tier names to indexes; an unknown name, inverted or equal tiers, no config: Known/Trusted and a [GameManager] warning, never a crash (wrong: %s; odd tiers %s)" % [wrong, odd])
	check(str(odd.get("warning", "")).contains("using mid A, late B") and not str(odd.get("warning", "")).contains("Known"),
		"without Known/Trusted in the list the warning names the tiers really used (%s)" % odd.get("warning", ""))
	# Review patch: fewer than 3 tiers (one tier, none, or a list without a third) can't hold Mid and Late: he
	# stays Early at every tier, and the warning says so (it doesn't claim Known/Trusted).
	var short_lists := {"one tier": [{"threshold": 0, "label": "Only"}], "empty": [], "missing": null,
		"two tiers": [{"threshold": 0, "label": "Unknown"}, {"threshold": 25, "label": "Known"}]}
	var short_wrong := []
	for k in short_lists:
		var lst: Array = gm.reputation_tier_list(short_lists[k])
		var r: Dictionary = gm.den_fa_tier_indexes({"mid": "Known", "late": "Trusted"}, lst)
		var states := []
		for i in range(0, lst.size() + 2):
			states.append(gm.den_fa_state_for("early", i, int(r.get("mid", 0)), int(r.get("late", 0))))
		var w := str(r.get("warning", ""))
		if not states.all(func(s): return s == "early") or not w.begins_with("[GameManager]") or not w.contains("stays early") or w.contains("using mid"):
			short_wrong.append("%s %s %s" % [k, states, r])
	check(short_wrong.is_empty(), "fewer than 3 reputation tiers: Mid and Late are unreachable (he stays Early) and the warning says so (wrong: %s)" % [short_wrong])
	gm._den_fa_tier_warnings = 0
	gm._den_fa_tiers_from({"mid": "Famous"}, dm.get_config("reputation_tiers", []))
	gm._den_fa_tiers_from({"mid": "Famous"}, dm.get_config("reputation_tiers", []))
	check(gm._den_fa_tier_warnings == 1, "a bad den_fa_state_tiers warns once a run, not on every reputation change (%d)" % gm._den_fa_tier_warnings)
	gm._den_fa_tier_warnings = 0
	return {"mid": int(tiers[ok.mid].get("threshold", 25)), "late": int(tiers[ok.late].get("threshold", 50))}


## adjust_reputation() moves him Early -> Mid -> Late at the configured thresholds, one den_fa_state_changed per
## transition (a spy on GuildBus); a drop never moves him back; one big jump steps early -> mid, then mid -> late.
func _check_den_fa_reputation(gm, gb, th: Dictionary) -> void:
	var sig_ok: bool = gb.has_signal("den_fa_state_changed") and gb.get_signal_list().any(func(sg): return sg.name == "den_fa_state_changed" and sg.args.size() == 2)
	check(sig_ok, "GuildBus.den_fa_state_changed(old_state, new_state) exists")
	if not sig_ok:
		return
	var events := []
	var spy := func(a, b): events.append([a, b])
	gb.den_fa_state_changed.connect(spy)
	gm.tavern_reputation = 0
	gm.den_fa_state = "early"
	var m: int = th.mid
	var l: int = th.late
	var trail := []
	for d in [m - 1, 1, l - m - 1, 1, -l, 1000, -5000]:
		gm.adjust_reputation(d)
		trail.append("%d:%s" % [gm.tavern_reputation, gm.den_fa_state])
	var want := ["%d:early" % (m - 1), "%d:mid" % m, "%d:mid" % (l - 1), "%d:late" % l, "0:late", "1000:late", "0:late"]
	var steps := events.duplicate()
	events.clear()
	gm.tavern_reputation = 0
	gm.den_fa_state = "early"
	gm.adjust_reputation(l + 5)
	var jump := events.duplicate()
	gb.den_fa_state_changed.disconnect(spy)
	check(trail == want and steps == [["early", "mid"], ["mid", "late"]] and jump == [["early", "mid"], ["mid", "late"]] and gm.den_fa_state == "late",
		"adjust_reputation: Early -> Mid at %d, Mid -> Late at %d, one signal per transition, a drop never moves him back, a jump across both tiers steps through Mid (two signals, in order) (%s; %s; %s)" % [m, l, trail, steps, jump])


## den_fa_state saves with the run's dialogue data, loads (old saves: re-evaluated; unknown: early + warning; never
## backwards from the saved state) and resets for a New Game. Loading and resetting are silent: the GuildBus signal
## means "earned in play" (review patch: a spy sees nothing); the reset also re-arms the once-a-run tier warning.
func _check_den_fa_state_save(gm, gb, th: Dictionary) -> void:
	var events := []
	var spy := func(a, b): events.append([a, b])
	gb.den_fa_state_changed.connect(spy)
	gm.tavern_reputation = th.mid
	gm.den_fa_state = "mid"
	var saved = JSON.parse_string(JSON.stringify(gm._dialogue_save_data()))
	gm._reset_dialogue_state()
	var reset_state: String = gm.den_fa_state
	gm._load_dialogue_data(saved if saved is Dictionary else {})
	var round_trip: String = gm.den_fa_state
	gm.tavern_reputation = th.late
	gm._load_dialogue_data({})
	var old_high: String = gm.den_fa_state
	gm.tavern_reputation = 0
	gm._load_dialogue_data({})
	var old_low: String = gm.den_fa_state
	gm._load_dialogue_data({"den_fa_state": "late"})
	var kept_late: String = gm.den_fa_state
	gm._load_dialogue_data({"den_fa_state": "sideways"})
	var unknown_low: String = gm.den_fa_state
	gm.tavern_reputation = th.mid
	gm._load_dialogue_data({"den_fa_state": 7})
	var unknown_mid: String = gm.den_fa_state
	gm.tavern_reputation = th.late
	gm.den_fa_state = "late"
	gm._den_fa_tier_warnings = 1
	gm._reset_dialogue_state()
	var warn_rearmed: bool = gm._den_fa_tier_warnings == 0
	gb.den_fa_state_changed.disconnect(spy)
	check(events.is_empty() and old_high == "late" and unknown_mid == "mid" and warn_rearmed,
		"loading a save (even one that moves him: %s, %s) and a New Game emit no den_fa_state_changed (%s); the New Game re-arms the once-a-run tier warning (%s)"
		% [old_high, unknown_mid, events, warn_rearmed])
	check(saved is Dictionary and saved.get("den_fa_state") == "mid" and reset_state == "early" and round_trip == "mid" and old_high == "late"
		and old_low == "early" and kept_late == "late" and unknown_low == "early" and unknown_mid == "mid" and gm.den_fa_state == "early",
		"den_fa_state: saved (%s), reset to early, loaded back (Continue keeps %s); an old save is re-evaluated (%s / %s); a saved late stays late at 0 reputation (%s); an unknown value loads as early, then re-evaluated (%s / %s)"
		% [saved.get("den_fa_state") if saved is Dictionary else "?", round_trip, old_high, old_low, kept_late, unknown_low, unknown_mid])


## The debug panel goes through the reputation authority (review patch): no direct tavern_reputation writes
## ("Unlock Tier 3" and the full reset use adjust_reputation, so Den Fa's state follows), and the full reset
## clears the run's dialogue state (den_fa_state, flags, counters). A source check: pressing its buttons would
## rewrite GameManager wholesale.
func _check_den_fa_debug_panel() -> void:
	var src := FileAccess.get_file_as_string(DEBUG_PANEL_SCRIPT)
	var direct := RegEx.create_from_string("tavern_reputation\\s*=(?!=)").search_all(src)
	var reset := _func_body(src, "_full_reset")
	check(src != "" and direct.is_empty() and src.contains("adjust_reputation(50 - GameManager.tavern_reputation)")
		and reset.contains("GameManager.adjust_reputation(-GameManager.tavern_reputation)") and reset.contains("GameManager._reset_dialogue_state()"),
		"debug_panel.gd: reputation only through adjust_reputation (%d direct writes); the full reset also resets the dialogue state" % direct.size())


## The bridge's den_fa_state (AC 3); den_fa.dialogue's Mid and Late titles: compiled, lint-clean, in his voice,
## walked in their state through every reply, entries marking themselves seen (AC 3); his title picking per
## state (AC 4).
func _check_den_fa_state_talk(gm, th: Dictionary) -> void:
	var runner = load(RUNNER_SCRIPT) if ResourceLoader.exists(RUNNER_SCRIPT) else null
	var bs = load(BRIDGE_SCRIPT) if ResourceLoader.exists(BRIDGE_SCRIPT) else null
	var dmgr = root.get_node_or_null("DialogueManager")
	if runner == null or not bs is GDScript or dmgr == null:
		check(false, "Test 21 needs the runner, the bridge and the DialogueManager autoload")
		return
	var b = runner.new_bridge()
	gm.den_fa_state = "mid"
	var read_mid = b.get("den_fa_state")
	b.set("den_fa_state", "late")
	var names := []
	for pr in (bs as GDScript).get_script_property_list():
		names.append(pr.name)
	for mt in (bs as GDScript).get_script_method_list():
		names.append(mt.name)
	check(read_mid == "mid" and gm.den_fa_state == "mid" and b.get("den_fa_state") == "mid" and names.has("den_fa_state")
		and _dialogue_lint("if bridge.den_fa_state == \"mid\"\n\tDen Fa: Hm.\n", names).is_empty(),
		"the bridge reads den_fa_state live, can't write it, and the lint knows the name")

	var text := FileAccess.get_file_as_string(DEN_FA_DIALOGUE)
	var compiled = DMCompiler.compile_string(text, DEN_FA_DIALOGUE)
	var titles: Dictionary = compiled.titles if compiled.errors.is_empty() else {}
	var resource: Resource = runner.compile_text(text, DEN_FA_DIALOGUE)
	var mid_n: Array = runner.numbered_titles(resource, "mid_") if resource != null else []
	var late_n: Array = runner.numbered_titles(resource, "late_") if resource != null else []
	var sections := {}                    # title -> its text
	for part in ("\n" + text).split("\n~ "):
		var head := part.get_slice("\n", 0).strip_edges()
		if head != "" and not head.begins_with("#"):
			sections[head] = part
	var den_lines := func(t: String) -> Array:
		return Array(str(sections.get(t, "")).split("\n")).filter(func(l): return l.strip_edges().begins_with("Den Fa:"))
	var late_asks := []
	for t in ["late_enter"] + late_n:
		for l in den_lines.call(t):
			if l.contains("?"):
				late_asks.append(l.strip_edges())
	var mid_refs := {}
	for t in ["mid_enter"] + mid_n:
		for m in RegEx.create_from_string("bridge\\.(\\w+)").search_all(str(sections.get(t, ""))):
			mid_refs[m.get_string(1)] = true
	check(compiled.errors.is_empty() and titles.has("mid_enter") and titles.has("late_enter") and mid_n.size() >= 2 and late_n.size() >= 2
		and text.begins_with("# DRAFT") and text.get_slice("\n", 0).contains("10.3"),
		"den_fa.dialogue: compiles; mid_enter, late_enter, %d mid and %d late openings (≥ 2 each); still marked DRAFT, now naming Story 10.3" % [mid_n.size(), late_n.size()])
	mid_refs.erase("mark_seen")          # the entry's own flag isn't noticing the guild
	check(late_asks.is_empty() and mid_refs.size() >= 2 and not mid_refs.has("den_fa_state"),
		"his voice: Late states things, he never asks (%s); Mid notices the guild through the bridge (%s)" % [late_asks, mid_refs.keys()])

	# Every title is walked under two guild conditions (review patch: both sides of every gate, whatever the
	# title's menus): a quiet run (no deaths, nobody hired, reputation fallen back to the base tier, which Mid
	# survives by DS-2) and a run with a death, hires and the Mid tier. Gated text -> the condition that shows it.
	var gates := {
		"mid_enter": [["didn't come back", "deaths"]],
		"mid_1": [["hired, this run", "hired"]],
		"mid_3": [["they call your guild now", "tier"], ["You paid for some of it", "deaths"]],
	}
	var conds := [["quiet", 0, 0, 0], ["deaths, hires, Mid tier", 1, 3, th.mid]]   # name, deaths, hired, reputation
	var why := []
	var menus := {"mid": 0, "late": 0}
	var replies_seen := {}
	var replies_total := 0
	var entries_marked := {}
	var gates_met := {}
	for state in ["mid", "late"]:
		var list: Array = [state + "_enter"] + (mid_n if state == "mid" else late_n)
		for title in list:
			replies_total += Array(str(sections.get(title, "")).split("\n")).filter(func(l): return l.strip_edges().begins_with("- ")).size()
			for ci in conds.size():
				var cond: Array = conds[ci]
				var on := {"deaths": cond[1] > 0, "hired": cond[2] > 0, "tier": cond[3] >= th.mid}
				for pick in 3:
					gm.den_fa_state = state
					gm.dialogue_flags = {"den_fa_first_contact": true}
					gm.deaths_this_run = cond[1]
					gm.adventurers_hired_this_run = cond[2]
					gm.tavern_reputation = cond[3]
					var w: Dictionary = await _walk_dialogue(dmgr, resource, title, pick, runner.new_bridge())
					var joined := "\n".join(w.texts)
					if not w.ended or w.texts.is_empty():
						why.append("%s/%s: no end or no line" % [cond[0], title])
					if joined.contains("0 hired"):
						why.append("%s/%s: counts nobody hired" % [cond[0], title])
					for g in gates.get(title, []):
						if joined.contains(g[0]) != on[g[1]]:
							why.append("%s/%s: '%s' %s" % [cond[0], title, g[0], "missing" if on[g[1]] else "shown"])
						gates_met["%s:%s:%s" % [title, g[0], on[g[1]]]] = true
					if title.ends_with("_enter") and gm.dialogue_flags.get("den_fa_" + title) == true:
						entries_marked[title] = true
					if pick == 0 and ci == 0:
						menus[state] += w.menus
					for r in w.replies:
						replies_seen["%s:%s" % [title, r]] = true
					if w.menus == 0:
						break
	check(why.is_empty() and entries_marked.keys() == ["mid_enter", "late_enter"] and menus.mid >= 1 and menus.late >= 1 and replies_seen.size() == replies_total
		and gates_met.size() == 8,
		"every Mid and Late title walked to its end in its state, every reply taken (%d of %d), every gated line on both sides (%d of 8); a flavour-reply menu in each state %s; the entries mark themselves seen %s %s"
		% [replies_seen.size(), replies_total, gates_met.size(), menus, entries_marked.keys(), why.slice(0, 4)])
	await _check_den_fa_picking(gm, runner, resource, mid_n, late_n, th)


## His title per state (AC 4): first contact, then the entries up to his state once each, earliest first, then
## its openings without repeats (memory per state); talked(state); a jump plays both entries in order; an entry
## without its mark_seen line still plays once; a state with no titles falls back to early_N with one warning.
func _check_den_fa_picking(gm, runner, resource: Resource, mid_n: Array, late_n: Array, th: Dictionary) -> void:
	var world := Node3D.new()
	world.name = "T21World"
	root.add_child(world)
	current_scene = world
	var marker := Marker3D.new()
	world.add_child(marker)
	marker.transform = _hearth_sit_point_world()
	var den = (load(DEN_FA_SCENE_PATH) as PackedScene).instantiate()
	world.add_child(den)
	for i in 3:
		await process_frame
	den.sit_at(marker)
	var early_n: Array = runner.numbered_titles(resource, "early_")
	var order := []
	gm.dialogue_flags = {}
	for state in ["early", "mid", "late"]:
		gm.den_fa_state = state
		order.append(den._pick_title(resource))
	gm.dialogue_flags = {"den_fa_first_contact": true}
	for state in ["mid", "late"]:
		gm.den_fa_state = state
		order.append(den._pick_title(resource))
		order.append(den._pick_title(resource))   # not seen yet: the entry again
	gm.dialogue_flags["den_fa_mid_enter"] = true
	order.append(den._pick_title(resource))       # late, Mid's entry seen: Late's
	check(order == ["first_contact", "first_contact", "first_contact", "mid_enter", "mid_enter", "mid_enter", "mid_enter", "late_enter"],
		"the order: first contact in any state until it is seen, then every entry up to his state, earliest first, until each is seen (Late plays mid_enter first if it was never seen) (%s)" % [order])
	var runs := {}
	gm.dialogue_flags = {"den_fa_first_contact": true, "den_fa_mid_enter": true, "den_fa_late_enter": true}
	for state in ["early", "mid", "late"]:
		gm.den_fa_state = state
		var picks := []
		for i in 50:
			picks.append(den._pick_title(resource))
		var repeats := 0
		for i in range(1, picks.size()):
			if picks[i] == picks[i - 1]:
				repeats += 1
		var pool: Array = {"early": early_n, "mid": mid_n, "late": late_n}[state]
		var distinct := {}
		for t in picks:
			distinct[t] = true
		runs[state] = [repeats, picks.all(func(t): return pool.has(t)), distinct.size() == pool.size()]
	check(runs.values().all(func(r): return r == [0, true, true]),
		"50 picks per state: only that state's openings, all of them, never the same one twice in a row ([repeats, in pool, all used]: %s)" % [runs])
	var after_early := {}
	for trial in 40:
		gm.den_fa_state = "early"
		for i in 20:
			if den._pick_title(resource) == early_n[0]:
				break
		gm.den_fa_state = "mid"
		after_early[den._pick_title(resource)] = true
	check(after_early.has(mid_n[0]) and after_early.size() == mid_n.size(),
		"the no-repeat memory is per state: right after %s, Mid can open with %s (%s)" % [early_n[0], mid_n[0], after_early.keys()])

	var said := []
	den.talked.connect(func(st): said.append(st))
	var titles_opened := []
	gm.dialogue_flags = {"den_fa_first_contact": true}
	gm.den_fa_state = "mid"
	for i in 2:
		titles_opened.append(await _den_fa_talk_once(den, said))
	gm.den_fa_state = "late"
	for i in 2:
		titles_opened.append(await _den_fa_talk_once(den, said))
	check(titles_opened.size() == 4 and titles_opened[0] == "mid_enter" and mid_n.has(titles_opened[1]) and titles_opened[2] == "late_enter" and late_n.has(titles_opened[3])
		and said == ["mid", "mid", "late", "late"] and gm.dialogue_flags.get("den_fa_mid_enter") == true and gm.dialogue_flags.get("den_fa_late_enter") == true,
		"talking: Mid's entry plays once, then a Mid opening; in Late, Late's entry once, then a Late opening (each entry marks itself seen); talked(state) says the state (%s, %s)" % [titles_opened, said])

	# Review patch: a jump across both tiers (one reputation change) steps him through Mid, and his next
	# conversations play both entries in order before any opening.
	var events := []
	var spy := func(a, b): events.append([a, b])
	var gb = root.get_node("GuildBus")
	gb.den_fa_state_changed.connect(spy)
	gm.dialogue_flags = {"den_fa_first_contact": true}
	gm.tavern_reputation = 0
	gm.den_fa_state = "early"
	gm.adjust_reputation(int(th.late) + 5)
	gb.den_fa_state_changed.disconnect(spy)
	var jumped := []
	for i in 3:
		jumped.append(await _den_fa_talk_once(den, said))
	check(events == [["early", "mid"], ["mid", "late"]] and jumped.size() == 3 and jumped[0] == "mid_enter" and jumped[1] == "late_enter" and late_n.has(jumped[2]),
		"a jump from Early past Trusted: two signals in order (%s); then mid_enter, late_enter, a Late opening (%s)" % [events, jumped])

	# Review patch: an entry title without its own mark_seen line still plays only once: den_fa.gd marks it.
	den.dialogue_path = DIALOGUE_UNMARKED_ENTER_FIXTURE
	gm.dialogue_flags = {"den_fa_first_contact": true}
	gm.den_fa_state = "mid"
	var unmarked := [await _den_fa_talk_once(den, said)]
	var marked_by_him: bool = gm.dialogue_flags.get("den_fa_mid_enter") == true
	unmarked.append(await _den_fa_talk_once(den, said))
	den.dialogue_path = DEN_FA_DIALOGUE
	var fixture_text := FileAccess.get_file_as_string(DIALOGUE_UNMARKED_ENTER_FIXTURE)
	check(fixture_text.contains("~ mid_enter") and not fixture_text.contains("mark_seen") and unmarked == ["mid_enter", "mid_1"] and marked_by_him,
		"an entry title with no mark_seen line (fixture): he marks it seen himself once its first line shows, so it plays once (%s)" % [unmarked])

	var thin: Resource = runner.compile_text("~ first_contact\nDen Fa: Hi.\n=> END\n\n~ early_1\nDen Fa: One.\n=> END\n\n~ early_2\nDen Fa: Two.\n=> END\n", "t21_thin")
	gm.den_fa_state = "late"
	gm.dialogue_flags = {"den_fa_first_contact": true}
	var thin_picks := [den._pick_title(thin), den._pick_title(thin), den._pick_title(thin)]
	var warned = den.get("_warned_states")
	check(thin_picks.all(func(t): return t in ["early_1", "early_2"]) and thin_picks[0] != thin_picks[1] and warned is Dictionary and warned.get("late") == true and warned.size() == 1,
		"a file with no titles for his state falls back to the early openings, warned once (%s, %s)" % [thin_picks, warned])
	# Review patch: his warnings name the resource that lacks the titles, not dialogue_path.
	var imported = runner.load_dialogue(DEN_FA_DIALOGUE)
	var pick_src := _func_body(FileAccess.get_file_as_string(DEN_FA_SCRIPT_PATH), "_pick_title")
	var has_src: bool = den.has_method("_source_of")
	check(has_src and den._source_of(thin) == "t21_thin" and imported != null and den._source_of(imported) == imported.resource_path
		and den._source_of(imported) != "" and pick_src.contains("_source_of(resource)") and not pick_src.contains("dialogue_path, state]")
		and not pick_src.contains("he has nothing to say\" % dialogue_path"),
		"his fallback warnings name the resource missing the titles (%s; %s)" % [den._source_of(thin) if has_src else "?", den._source_of(imported) if has_src and imported != null else "?"])
	current_scene = null
	world.queue_free()
	await process_frame


## One real talk() to Den Fa (Test 21): waits for his first line (talked grows `said`), returns the title the box
## opened ("none" without exactly one box) and closes it.
func _den_fa_talk_once(den, said: Array) -> String:
	var n := said.size()
	den.talk()
	var t0 := Time.get_ticks_msec()
	while said.size() <= n and Time.get_ticks_msec() - t0 < 2000:
		await process_frame
	var open: Array = get_nodes_in_group("dialogue_open")
	var title := str(open[0].start_from_title) if open.size() == 1 else "none"
	for bx in open:
		bx.close("test")
	await process_frame
	return title


func _close_test_world(world: Node) -> void:
	for b in get_nodes_in_group("dialogue_open"):
		b.close("test")
	current_scene = null
	world.queue_free()


## Press and release an action through the real input pipeline (Input.parse_input_event).
func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


## Press and release a physical key (Space is both ui_accept and jump).
func _press_key(key: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
		await process_frame


## A node that counts presses (and echoes) of the dialogue box's keys (interact, ui_accept, ui_cancel, jump, Tab)
## reaching it. Releases don't count: the release of the key that closed a box arrives after it is gone.
static func _input_spy_script() -> GDScript:
	var gs := GDScript.new()
	gs.source_code = """extends Node
var seen := {}
func _note(e: InputEvent, where: String) -> void:
	for a in ["interact", "ui_accept", "ui_cancel", "jump", "ui_focus_next", "ui_focus_prev"]:
		if e.is_action(a) and e.is_pressed():
			seen[where + ":" + a] = int(seen.get(where + ":" + a, 0)) + 1
func _input(e: InputEvent) -> void:
	_note(e, "input")
func _unhandled_input(e: InputEvent) -> void:
	_note(e, "unhandled")
func count(a: String) -> int:
	return int(seen.get("input:" + a, 0)) + int(seen.get("unhandled:" + a, 0))
func total() -> int:
	var n := 0
	for k in seen:
		n += int(seen[k])
	return n
"""
	gs.reload()
	return gs


## The text of one top-level function (from its `func` line to the next top-level func), "" if absent.
## GDScript source without its comments (whole-line and trailing `#`, outside strings): a guard named only in a
## comment doesn't count.
static func _code_lines(src: String) -> String:
	var out := PackedStringArray()
	for line in src.split("\n"):
		var in_str := ""
		var cut := line.length()
		for i in line.length():
			var c := line[i]
			if in_str != "":
				if c == in_str:
					in_str = ""
			elif c == "\"" or c == "'":
				in_str = c
			elif c == "#":
				cut = i
				break
		var code := line.substr(0, cut)
		if code.strip_edges() != "":
			out.append(code)
	return "\n".join(out)


static func _func_body(src: String, fname: String) -> String:
	var a := src.find("\nfunc %s(" % fname)
	if a < 0:
		return ""
	var b := src.find("\nfunc ", a + 1)
	return src.substr(a, (b - a) if b > 0 else -1)


## The override material of every surface of a loaded staff body, in order (Test 19: two anime instances share them).
static func _staff_overrides(x) -> Array:
	var out := []
	if x.model:
		for mi in x.model.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for s in (mesh.get_surface_count() if mesh else 0):
				out.append((mi as MeshInstance3D).get_surface_override_material(s))
	return out


## The states of a staff node's AnimationTree not bound to their own clip (Test 19).
static func _staff_bound_wrong(x) -> Array:
	if x.tree == null:
		return ["no tree"]
	var sm := x.tree.tree_root as AnimationNodeStateMachine
	var states: Dictionary = x._states()
	var out := []
	for s in states:
		var node = sm.get_node(s) if sm and sm.has_node(s) else null
		if not (node is AnimationNodeAnimation and str((node as AnimationNodeAnimation).animation) == str(states[s])):
			out.append(s)
	return out


## The states whose tree node does not set its own loop mode (use_custom_timeline; linear for STAFF_LOOPS) on the
## clip's own timeline: timeline_length the clip's length, unstretched (else a loop wraps at 1 s, a one-shot is cut).
static func _staff_loops_wrong(x) -> Array:
	if x.tree == null:
		return ["no tree"]
	var sm := x.tree.tree_root as AnimationNodeStateMachine
	var states: Dictionary = x._states()
	var out := []
	for s in states:
		var node: AnimationNodeAnimation = sm.get_node(s) as AnimationNodeAnimation if sm and sm.has_node(s) else null
		var loop_want: int = Animation.LOOP_LINEAR if STAFF_LOOPS.has(str(states[s])) else Animation.LOOP_NONE
		var clip_len: float = x.anim.get_animation(node.animation).length if node and x.anim and x.anim.has_animation(node.animation) else 1.0
		if node == null or not node.use_custom_timeline or node.loop_mode != loop_want \
				or absf(node.timeline_length - clip_len) > 0.001 or node.stretch_time_scale:
			out.append(s)
	return out


## What is wrong with a staff node on the KayKit fallback body (Test 19): each state plays its own clip when
## the body has it, else CLIP_FALLBACK's; the tree sets the loop modes; the hand-slot items are hidden.
static func _staff_fallback_wrong(x) -> Array:
	if not x.using_fallback or x.anim == null or x.tree == null:
		return ["not on the fallback body"]
	var out := []
	var sm := x.tree.tree_root as AnimationNodeStateMachine
	var states: Dictionary = x._states()
	for s in states:
		var clip := str(states[s])
		var clip_want: String = clip if x.anim.has_animation(clip) else str(x.CLIP_FALLBACK.get(clip, "Idle"))
		var node = sm.get_node(s) if sm and sm.has_node(s) else null
		var got: String = str((node as AnimationNodeAnimation).animation) if node is AnimationNodeAnimation else "nothing"
		if got != clip_want or not x.anim.has_animation(got):
			out.append("%s plays %s" % [s, got])
	out.append_array(_staff_loops_wrong(x))
	var sks: Array = x.model.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		var sk := sks[0] as Skeleton3D
		for a in x.model.find_children("*", "BoneAttachment3D", true, false):
			var b := sk.find_bone((a as BoneAttachment3D).bone_name)
			var par: int = sk.get_bone_parent(b) if b >= 0 else -1
			if par >= 0 and sk.get_bone_name(par).begins_with("handslot") and (a as Node3D).visible:
				out.append("%s shows" % a.name)
	return out


## A staff script with its body spec overridden (Test 19's fallback cases).
static func _staff_variant_script(base_path: String, spec: Dictionary) -> GDScript:
	var gs := GDScript.new()
	gs.source_code = "extends \"%s\"\n\nfunc _variant_spec() -> Dictionary:\n\treturn %s\n" % [base_path, var_to_str(spec)]
	gs.reload()
	return gs


## A role's default body in staff.json (Test 19).
static func _staff_model_path(roles: Dictionary, role: String) -> String:
	var r = roles.get(role)
	if not (r is Dictionary and r.get("variants") is Dictionary):
		return ""
	var v = r.variants.get(str(r.get("default_variant", "")))
	return str(v.get("model_path", "")) if v is Dictionary else ""


## One tick of the Bartender's walk (Test 19): inside r 3.0 he is on the ring's arc or on the φ 180 flap leg,
## inside r 3.2 a walk is Walk_Bar, and outside r 3.65 he keeps to his arrive_route; reasons go into `why`.
static func _bar_walk_why(bt, route: PackedVector3Array, why: Array) -> void:
	var p: Vector3 = bt.global_position
	var d := Vector2(p.x - RING_CENTER.x, p.z - RING_CENTER.z)
	if d.length() < 3.0:
		var phi := rad_to_deg(atan2(d.x, d.y))
		var on_flap := absf(absf(phi) - 180.0) <= 2.0
		# Story 25.31: his serve stands sit past the ring (his body's serve_r): the last leg runs out along the stand's angle
		var on_leg := false
		for i in mini(5, bt._stands.size()):
			var sphi := rad_to_deg(float(bt._stands[i].phi))
			var sr: float = Vector2(bt._stands[i].pos.x - RING_CENTER.x, bt._stands[i].pos.z - RING_CENTER.z).length()
			if absf(wrapf(phi - sphi, -180.0, 180.0)) <= 1.0 and d.length() <= maxf(sr, float(bt.walk_radius_at(deg_to_rad(phi)))) + 0.05:
				on_leg = true
		if not on_flap and not on_leg and absf(d.length() - float(bt.walk_radius_at(deg_to_rad(phi)))) > 0.05:
			why.append("off the arc at %.0f° r %.2f" % [phi, d.length()])
	if d.length() < 3.2 and bt.is_walking() and bt.anim_state() != "WalkBar":
		why.append("walking in %s inside the ring" % bt.anim_state())
	elif d.length() >= 3.65 and _dist_to_route(p, route) > 0.05:
		why.append("off his route at (%.2f, %.2f)" % [p.x, p.z])


## What is wrong with the Bartender's tankard while he holds it (Test 19): "" when it is on handslot.r, upright.
static func _tankard_wrong(bt) -> String:
	var tk = bt._tankard
	if not is_instance_valid(tk):
		return "no tankard"
	var att: Node = (tk as Node).get_parent()
	if not (att is BoneAttachment3D and (att as BoneAttachment3D).bone_name == "handslot.r"):
		return "not on handslot.r"
	var tilt := rad_to_deg((tk as Node3D).global_basis.y.normalized().angle_to(Vector3.UP))
	if tilt > 5.0:
		return "tilted %.1f°" % tilt
	var sc: float = (tk as Node3D).global_basis.get_scale().y
	return "scale %.2f (want %.2f)" % [sc, float(bt.tankard_scale())] if absf(sc - float(bt.tankard_scale())) > 0.02 else ""


## The flat angle (degrees) between where a staff member faces and the centre of the stool's mesh (Test 19).
static func _stool_aim_deg(x: Node3D, stool: Node3D) -> float:
	if stool == null:
		return 180.0
	var mi := stool as MeshInstance3D
	if mi == null:
		var ms := stool.find_children("*", "MeshInstance3D", true, false)
		mi = ms[0] as MeshInstance3D if not ms.is_empty() else null
	var c: Vector3 = mi.global_transform * mi.get_aabb().get_center() if mi else stool.global_position
	var to := Vector3(c.x - x.global_position.x, 0.0, c.z - x.global_position.z)
	var f := Vector3(x.global_basis.z.x, 0.0, x.global_basis.z.z)
	return rad_to_deg(f.angle_to(to)) if to.length() > 0.001 and f.length() > 0.001 else 180.0


## The speech bubbles a staff member shows (not already on their way out).
static func _live_bubbles(x: Node) -> Array:
	return x.get_children().filter(func(c): return c is PatronSpeechBubble and not c.is_queued_for_deletion())


## Whether `want` appears in `seq` in order (other entries may sit between).
static func _is_subsequence(want: Array, seq: Array) -> bool:
	var i := 0
	for s in seq:
		if i < want.size() and s == want[i]:
			i += 1
	return i == want.size()


## A minimal front door for Test 19 (the real one is built inline in MainTavern): the script and the
## three children it needs.
static func _make_door() -> Node3D:
	var door := Node3D.new()
	var trigger := Area3D.new()
	trigger.name = "Trigger"
	trigger.collision_mask = 3
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(3, 2.5, 4)
	shape.position = Vector3(0, 1.25, 0)
	trigger.add_child(shape)
	door.add_child(trigger)
	for h in ["HingeLeft", "HingeRight"]:
		var n := Node3D.new()
		n.name = h
		door.add_child(n)
	door.set_script(load(FRONT_DOOR_SCRIPT))
	return door


static func _strip_scripts(n: Node) -> void:
	n.set_script(null)
	for c in n.get_children():
		_strip_scripts(c)


## The flat distance from a point to a polyline (Test 19).
static func _dist_to_route(p: Vector3, route: PackedVector3Array) -> float:
	var best := INF
	for i in route.size() - 1:
		var a := Vector2(route[i].x, route[i].z)
		var b := Vector2(route[i + 1].x, route[i + 1].z)
		best = minf(best, Vector2(p.x, p.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b)))
	return best


## The Hearth's SitPoint in MainTavern world space (the Hearth instance composed with Hearth.tscn).
static func _hearth_sit_point_world() -> Transform3D:
	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var hs := _scene_nodes(HEARTH_SCENE_PATH)
	for k in tav:
		if tav[k].instance == HEARTH_SCENE_PATH and hs.has("SitPoint"):
			return (tav[k].world as Transform3D) * (hs.SitPoint.world as Transform3D)
	return Transform3D.IDENTITY


static func _flip_patron_script() -> GDScript:
	var gs := GDScript.new()
	gs.source_code = "extends Node3D\nvar served := false\nfunc can_be_served_by(_p: Vector3) -> bool:\n\treturn not served\nfunc serve_patron() -> void:\n\tserved = true\n"
	gs.reload()
	return gs

## Every villager's post and the path of every walker's loop, sampled every 0.5 m (for Test 17).
static func _villager_path_points(ext: Dictionary) -> Array:
	var out := []
	for k in ext:
		if not (str(k).begins_with("Villagers/") and str(k).count("/") == 1):
			continue
		var o: Vector3 = (ext[k].world as Transform3D).origin
		out.append(Vector2(o.x, o.z))
		var wps: PackedVector3Array = ext[k].props.get("waypoints", PackedVector3Array())
		for i in wps.size():
			var a := Vector2(wps[i].x, wps[i].z)
			var b := Vector2(wps[(i + 1) % wps.size()].x, wps[(i + 1) % wps.size()].z)
			var steps := maxi(int(ceil(a.distance_to(b) / 0.5)), 1)
			for t in steps:
				out.append(a.lerp(b, float(t) / steps))
	return out

## Radius (xz) of a scene's trimesh collider: the smallest vertex radius (inner = true) or the largest.
static func _shape_radius(nodes: Dictionary, inner: bool) -> float:
	for k in nodes:
		var sh = nodes[k].props.get("shape")
		if sh is ConcavePolygonShape3D:
			var best := INF if inner else 0.0
			for v in (sh as ConcavePolygonShape3D).get_faces():
				var r := Vector2(v.x, v.z).length()
				best = minf(best, r) if inner else maxf(best, r)
			return best
	return -1.0

## Whether any polygon of a baked navmesh covers (x, z), at any height. Since the review of 2026-10-03 the mesh
## has no islands on solid props (region_min_size drops them; Test 7 checks it is one connected piece), so no
## test needs a floor-level height filter any more.
static func _nav_contains(nav: NavigationMesh, x: float, z: float) -> bool:
	return not _nav_polys_at(nav, x, z).is_empty()


## The polygons of a baked navmesh whose XZ outline contains (x, z), at any height.
static func _nav_polys_at(nav: NavigationMesh, x: float, z: float) -> Array:
	var v := nav.get_vertices()
	var out := []
	for i in nav.get_polygon_count():
		var poly := nav.get_polygon(i)
		var inside := false
		for a in poly.size():
			var p1 := v[poly[a]]
			var p2 := v[poly[(a + 1) % poly.size()]]
			if (p1.z > z) != (p2.z > z) and x < p1.x + (z - p1.z) * (p2.x - p1.x) / (p2.z - p1.z):
				inside = not inside
		if inside:
			out.append(i)
	return out


## The highest vertex of one navmesh polygon.
static func _nav_poly_top(nav: NavigationMesh, i: int) -> float:
	var v := nav.get_vertices()
	var top := -INF
	for k in nav.get_polygon(i):
		top = maxf(top, v[k].y)
	return top


## A connected-piece id per polygon: polygons sharing an edge (matched by vertex position, to the mm) join.
static func _nav_components(nav: NavigationMesh) -> PackedInt32Array:
	var v := nav.get_vertices()
	var n := nav.get_polygon_count()
	var edges := {}   # "a|b" (sorted vertex keys) -> polygons
	for i in n:
		var poly := nav.get_polygon(i)
		for a in poly.size():
			var k1 := str(v[poly[a]].snapped(Vector3.ONE * 0.001))
			var k2 := str(v[poly[(a + 1) % poly.size()]].snapped(Vector3.ONE * 0.001))
			var key := k1 + "|" + k2 if k1 < k2 else k2 + "|" + k1
			if not edges.has(key):
				edges[key] = []
			edges[key].append(i)
	var adj := []
	adj.resize(n)
	for i in n:
		adj[i] = []
	for key in edges:
		for a in edges[key]:
			for b in edges[key]:
				if a != b:
					adj[a].append(b)
	var comp := PackedInt32Array()
	comp.resize(n)
	comp.fill(-1)
	var next := 0
	for s in n:
		if comp[s] != -1:
			continue
		var stack := [s]
		comp[s] = next
		while not stack.is_empty():
			var p: int = stack.pop_back()
			for q in adj[p]:
				if comp[q] == -1:
					comp[q] = next
					stack.append(q)
		next += 1
	return comp


## MainTavern's stored TavernNavigation mesh, read through SceneState (no instancing); null if missing.
static func _tavern_navmesh() -> NavigationMesh:
	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	for k in tav:
		if str(k).ends_with("TavernNavigation"):
			return tav[k].props.get("navigation_mesh") as NavigationMesh
	return null


static func _scene_has_shape(scene_path: String, shape_class: String) -> bool:
	var nodes := _scene_nodes(scene_path)
	return nodes.values().any(func(n): return n.props.get("shape") != null and n.props.get("shape").get_class() == shape_class)


static func _hf_height(hf: Dictionary, x: float, z: float) -> float:
	var step := float(hf.step)
	var fx := (x - float(hf.x0)) / step
	var fz := (z - float(hf.z0)) / step
	var i := clampi(int(floor(fx)), 0, int(hf.nx) - 2)
	var j := clampi(int(floor(fz)), 0, int(hf.nz) - 2)
	var tx := clampf(fx - i, 0.0, 1.0)
	var tz := clampf(fz - j, 0.0, 1.0)
	var H: Array = hf.heights
	var a := lerpf(float(H[j][i]), float(H[j][i + 1]), tx)
	var b := lerpf(float(H[j + 1][i]), float(H[j + 1][i + 1]), tx)
	return lerpf(a, b, tz)


static func _hf_stream_x(hf: Dictionary, z: float) -> float:
	var s: Array = hf.get("stream", [])
	if s.is_empty():
		return INF   # no stream: nothing is "in" it (Test 9 checks the fixture has one)
	for k in s.size() - 1:
		if float(s[k][0]) <= z and z <= float(s[k + 1][0]):
			var t := (z - float(s[k][0])) / maxf(float(s[k + 1][0]) - float(s[k][0]), 0.0001)
			return lerpf(float(s[k][1]), float(s[k + 1][1]), t)
	return float(s[0][1]) if z < float(s[0][0]) else float(s[-1][1])


static func _dist_to_polyline(p: Vector2, pts: Array) -> float:
	var best := INF
	for k in pts.size() - 1:
		var a := Vector2(pts[k][0], pts[k][1])
		var b := Vector2(pts[k + 1][0], pts[k + 1][1])
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


static func _is_edge_material(mat) -> bool:
	return mat is ShaderMaterial and (mat as ShaderMaterial).shader != null \
		and (mat as ShaderMaterial).shader.resource_path == EDGE_SHADER_PATH


# --- Test 22: Dialogue portraits (Story 25.17) ---
# The portrait studio (scenes/dev/PortraitStudio.tscn, a windowed run: it needs the GPU) renders each speaker's
# portrait from speakers.json's portrait_source into assets/characters/portraits/npc/<id>.png. Headless, this
# checks its outputs and its data, not by rendering: every portrait that exists is a 512 × 512 opaque, non-blank
# texture imported lossless with mipmaps; every speaker has its portrait or an allowlisted path with an owner;
# every portrait_source resolves (the body, its clip and its bone; a staff variant in staff.json); the box shows
# the PNGs, not plates; the studio is a dev scene (no class_name, not a player_scene, quits before the autosave).
func test_dialogue_portraits() -> void:
	print("[Test 22] Dialogue portraits")
	var data = _read_json(SPEAKERS_PATH)
	var sp: Dictionary = data.get("speakers", {}) if data is Dictionary and data.get("speakers") is Dictionary else {}
	var staff = _read_json(STAFF_DATA_PATH)
	var allow = _read_json(ASSET_ALLOWLIST_PATH)
	check(not sp.is_empty() and staff is Dictionary and allow is Dictionary, "speakers.json, staff.json and the allowlist load")
	if sp.is_empty() or not staff is Dictionary or not allow is Dictionary:
		print("")
		return

	# The allowlist: no folder-wide entry; the portraits not rendered yet are listed per path, owned by their story.
	var exact := {}
	for e in allow.get("missing_paths", []):
		exact[str(e.get("path", ""))] = str(e.get("owner", "")) if str(e.get("reason", "")) != "" else ""
	var folder := (allow.get("missing_prefixes", []) as Array).filter(func(e): return PORTRAIT_DIR.begins_with(str(e.get("prefix", "?"))) \
		or str(e.get("prefix", "")).begins_with(PORTRAIT_DIR))
	check(folder.is_empty(), "no allowlist prefix covers %s (the folder-wide entry is gone: %s)" % [PORTRAIT_DIR, folder])
	var planned_bad := []
	for id in PORTRAITS_PLANNED:
		var e = sp.get(id)
		var path: String = PORTRAIT_DIR + str(id) + ".png"
		if not e is Dictionary or str(e.get("portrait", "")) != path or e.has("portrait_source") \
				or not str(exact.get(path, "")).contains(PORTRAITS_PLANNED[id]):
			planned_bad.append(id)
	check(planned_bad.is_empty(), "the Elder and the Bard (no body yet): no portrait_source, their PNG allowlisted per path, owned by Story 25.11 / 25.12 (wrong: %s)" % [planned_bad])
	var uncovered := []
	for id in sp:
		var path: String = str(sp[id].get("portrait", "")) if sp[id] is Dictionary else ""
		if not _res_exists(path) and str(exact.get(path, "")) == "":
			uncovered.append(id)
	check(uncovered.is_empty(), "every speaker has its portrait file or an allowlisted path with an owner (neither: %s)" % [uncovered])

	# The portraits: 512 × 512, opaque, not blank, imported per DP-5.
	var absent := PORTRAITS_RENDERED.filter(func(id): return not _res_exists(PORTRAIT_DIR + id + ".png"))
	check(absent.is_empty(), "den_fa.png, quest_dealer.png and bartender.png exist (missing: %s)" % [absent])
	for id in sp:
		var path: String = str(sp[id].get("portrait", "")) if sp[id] is Dictionary else ""
		if _res_exists(path):
			_check_portrait_png(id, path)

	# The sources: each resolves to a body that has the clip and the bone; the camera numbers are sane.
	var studio = load(PORTRAIT_STUDIO_SCRIPT) if ResourceLoader.exists(PORTRAIT_STUDIO_SCRIPT) else null
	var studio_ok: bool = studio is GDScript and (studio as GDScript).get_global_name() == "" \
		and ["resolve_source", "source_error", "plan", "autosave_seconds", "guard_seconds"].all(func(f): return (studio as GDScript).get_script_method_list().any(func(m): return m.name == f))
	check(studio_ok, "portrait_studio.gd exists, with no class_name, and resolve_source() / source_error() / plan() / autosave_seconds() / guard_seconds()")
	var unsourced := PORTRAITS_RENDERED.filter(func(id): return not (sp.get(id) is Dictionary and sp[id].get("portrait_source") is Dictionary))
	check(unsourced.is_empty(), "den_fa, quest_dealer and bartender have a portrait_source (missing: %s)" % [unsourced])
	var qd_src = sp.get("quest_dealer", {}).get("portrait_source", {}) if sp.get("quest_dealer") is Dictionary else {}
	var elf: Dictionary = staff.get("roles", {}).get("desk_manager", {}).get("variants", {}).get("silver_elf", {})
	check(qd_src is Dictionary and str(qd_src.get("staff_variant", "")) == "desk_manager/silver_elf" and not qd_src.has("model") and not elf.is_empty(),
		"the Quest Dealer's source follows staff.json's desk_manager › silver_elf variant (a variant swap re-renders her)")
	if studio_ok:
		for id in sp:
			if sp[id] is Dictionary and sp[id].get("portrait_source") is Dictionary:
				_check_portrait_source(studio, id, sp[id].portrait_source, staff)
	# Staff speakers follow their staff.json variant, never a raw model (a body swap such as 25.31's re-renders the
	# right body): the Quest Dealer (desk_manager) and every speaker named after a staff role (the Bartender).
	var roles: Dictionary = staff.get("roles", {}) if staff.get("roles") is Dictionary else {}
	var staff_speakers := {"quest_dealer": "desk_manager"}
	for id in sp:
		if roles.has(id):
			staff_speakers[id] = id
	var off_variant := staff_speakers.keys().filter(func(id): return not (sp.get(id) is Dictionary and sp[id].get("portrait_source") is Dictionary
		and str(sp[id].portrait_source.get("staff_variant", "")).begins_with(str(staff_speakers[id]) + "/") and not sp[id].portrait_source.has("model")))
	check(staff_speakers.has("bartender") and off_variant.is_empty(),
		"every staff speaker's portrait_source names its staff_variant, not a raw model (%s; wrong: %s)" % [staff_speakers, off_variant])
	if studio_ok and sp.get("bartender") is Dictionary and sp.bartender.get("portrait_source") is Dictionary:
		var bt: Dictionary = studio.resolve_source(sp.bartender.portrait_source, staff)
		check(str(bt.get("path", "")) == BARTENDER_PATH and str(bt.get("look", "?")) == "realistic" and str(bt.get("error", "?")) == "",
			"the Bartender's variant resolves to his realistic body (Story 25.31): g12_bartender_real.glb, look realistic (%s)" % [bt])
	if studio_ok:
		_check_portrait_source_errors(studio, sp)
		_check_portrait_studio_plan(studio, sp, staff)
	var note := str(data.get("_note", ""))
	check(note.contains("PortraitStudio.tscn -- ids=") and note.contains("portrait_source") and note.contains("25.31") and note.contains("25.32")
		and note.contains("mipmaps/generate=true") and note.contains("detect_3d/compress_to=0"),
		"speakers.json's _note: the portrait_source keys, the re-render command, 25.31 / 25.32 re-render the Bartender and Den Fa, a new PNG's two import edits")

	# The box: the three resolve to their PNGs (no plate, no warning); the slot draws a 512 px portrait smoothly at 160.
	var bx = load(BOX_SCRIPT) if ResourceLoader.exists(BOX_SCRIPT) else null
	if bx is GDScript:
		var wrong := []
		for id in PORTRAITS_RENDERED:
			var before: int = bx.warned_portraits.get(id, 0)
			var tex = bx.portrait_texture(id)
			if not (tex is CompressedTexture2D and (tex as Texture2D).resource_path == PORTRAIT_DIR + id + ".png") or bx.warned_portraits.get(id, 0) != before:
				wrong.append(id)
		check(wrong.is_empty(), "the dialogue box resolves Den Fa's, the Quest Dealer's and the Bartender's portraits to the PNGs, no plate, no 'missing portrait' warning (wrong: %s)" % [wrong])
	else:
		check(false, "dialogue_box.gd loads")
	var filter := -1
	var box_scene = load(BOX_SCENE) if ResourceLoader.exists(BOX_SCENE) else null
	if box_scene is PackedScene:
		var st: SceneState = (box_scene as PackedScene).get_state()
		for i in st.get_node_count():
			if st.get_node_name(i) == &"Portrait":
				for p in st.get_node_property_count(i):
					if st.get_node_property_name(i, p) == &"texture_filter":
						filter = int(st.get_node_property_value(i, p))
	check(filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"the box's Portrait slot filters linear with mipmaps (the project default is nearest: a 512 px portrait at 160 px would alias) (%d)" % filter)

	# The studio is a dev scene: its root runs the studio script, isn't a player_scene, and it quits before the autosave.
	var ps = load(PORTRAIT_STUDIO_SCENE) if ResourceLoader.exists(PORTRAIT_STUDIO_SCENE) else null
	var root_script = null
	var groups := PackedStringArray()
	if ps is PackedScene:
		var st: SceneState = (ps as PackedScene).get_state()
		groups = st.get_node_groups(0)
		for p in st.get_node_property_count(0):
			if st.get_node_property_name(0, p) == &"script":
				root_script = st.get_node_property_value(0, p)
	# Its render path is the game's: the edge shader with the game's parameters (only linePixels widened, and its
	# default stays 1 so the game draws as before), exactly one DirectionalLight (the edge pass multiplies by each).
	var shader_src := FileAccess.get_file_as_string(EDGE_SHADER_PATH)
	# Every scene and material that uses the edge shader (found by its path or uid, not a list) keeps linePixels at
	# its default: only the studio widens it; no script sets it either.
	var shader_uid := FileAccess.get_file_as_string(EDGE_SHADER_PATH + ".uid").strip_edges()
	var res_files: Array[String] = []
	_collect_files("res://", ["tscn", "tres", "material", "gd"], res_files)
	var users := res_files.filter(func(p): return p.get_extension() != "gd" and (FileAccess.get_file_as_string(p).contains(EDGE_SHADER_PATH)
		or (shader_uid.begins_with("uid://") and FileAccess.get_file_as_string(p).contains(shader_uid))))
	# A game scene may carry linePixels at its default 1.0 (Godot's editor writes the default out on a re-save,
	# 2026-10-04); it fails only when a value is > 1 or can't be read.
	var game_scenes_wide := users.filter(func(p): return p != PORTRAIT_STUDIO_SCENE and _edge_line_pixels_widened(FileAccess.get_file_as_string(p)))
	game_scenes_wide += res_files.filter(func(p): return (p.get_extension() == "gd" and p != PORTRAIT_STUDIO_SCRIPT and not p.begins_with("res://test/")
		and FileAccess.get_file_as_string(p).contains("linePixels")))
	var known_users := [PORTRAIT_STUDIO_SCENE, "res://scenes/MainTavern.tscn", "res://scenes/world/ExteriorWorld.tscn", "res://scenes/dev/LookDev.tscn"]
	var unfound := known_users.filter(func(p): return not users.has(p))
	check(unfound.is_empty() and game_scenes_wide.is_empty(),
		"the edge shader's %d users (scanned by path/uid): only PortraitStudio.tscn widens linePixels (> 1; the default 1.0 written out is fine), no script sets it (widening it: %s; known users not found: %s)" % [users.size(), game_scenes_wide, unfound])
	check(not _edge_line_pixels_widened("shader_parameter/linePixels = 1.0\n") and _edge_line_pixels_widened("shader_parameter/linePixels = 1.5\n")
		and _edge_line_pixels_widened("shader_parameter/linePixels = 2\n") and _edge_line_pixels_widened("linePixels = nope\n")
		and not _edge_line_pixels_widened("shader_parameter/lineAlpha = 0.7\n"),
		"the linePixels scan passes the default 1.0 and fails a widened (1.5, 2) or unreadable value")
	# Story 25.23 (AC 8): the EdgeQuad sits at the far plane; under fog it would be fogged. If any of its scenes turns
	# fog on, the shader carries fog_disabled.
	var fogged := users.filter(func(p): return FileAccess.get_file_as_string(p).contains("volumetric_fog_enabled = true") or FileAccess.get_file_as_string(p).contains("\nfog_enabled = true"))
	check(fogged.is_empty() or shader_src.contains("fog_disabled"), "the edge shader is fog_disabled wherever a scene of it turns fog on (fogged scenes: %s)" % [fogged])
	var edge_ok := false
	var directional := -1
	if ps is PackedScene:
		var inst: Node = (ps as PackedScene).instantiate()
		var quad := inst.get_node_or_null("SubViewportContainer/Studio/Camera3D/EdgeQuad") as MeshInstance3D
		var mat: ShaderMaterial = quad.get_surface_override_material(0) as ShaderMaterial if quad != null else null
		edge_ok = mat != null and _is_edge_material(mat) and is_equal_approx(float(mat.get_shader_parameter("lightIntensity")), 1.25) \
			and is_equal_approx(float(mat.get_shader_parameter("lineAlpha")), 0.7) and bool(mat.get_shader_parameter("useLighting")) \
			and float(mat.get_shader_parameter("linePixels")) > 1.0
		directional = inst.find_children("*", "DirectionalLight3D", true, false).size()
		inst.free()
	check(shader_src.contains("uniform float linePixels = 1.0;") and game_scenes_wide.is_empty() and edge_ok and directional == 1,
		"the studio draws through the game's edge shader and parameters (linePixels widened there only (> 1); the game's scenes keep the default 1) with exactly one DirectionalLight (%d)" % directional)
	check(ps is PackedScene and root_script is GDScript and (root_script as GDScript).resource_path == PORTRAIT_STUDIO_SCRIPT and not "player_scene" in groups,
		"PortraitStudio.tscn: its root runs portrait_studio.gd, not in player_scene (PlayerManager stands down)")
	if studio_ok:
		_check_portrait_studio_guard(studio)
	print("")


## True when a resource's text widens the edge shader's linePixels: any "linePixels = v" with v > 1, or a value
## that doesn't read as a number (Test 22; the default 1.0 the editor writes out is not a widening).
func _edge_line_pixels_widened(text: String) -> bool:
	if not text.contains("linePixels"):
		return false
	var re := RegEx.new()
	re.compile("linePixels\\s*=\\s*([^\\s]+)")
	var found := re.search_all(text)
	if found.size() != text.count("linePixels"):
		return true
	for m in found:
		var v: String = m.get_string(1)
		if not v.is_valid_float() or float(v) > 1.0:
			return true
	return false


## The studio's save guard (Test 22, Story 25.17 review): it asks to quit, then a watchdog thread kills the
## process, both well before SaveSystem's autosave whatever game_config says, with a budget per speaker; the hard
## stop doesn't depend on a quit already asked for; after the guard fires nothing more is written.
func _check_portrait_studio_guard(studio: GDScript) -> void:
	var cfg = _read_json(GAME_CONFIG_PATH)
	var autosave = studio.autosave_seconds(cfg if cfg is Dictionary else {})
	var configured := float(cfg.get("autosave_interval_seconds", 300)) if cfg is Dictionary else 300.0
	var reads := [studio.autosave_seconds({}), studio.autosave_seconds({"autosave_interval_seconds": 120}),
		studio.autosave_seconds({"autosave_interval_seconds": 0}), studio.autosave_seconds({"autosave_interval_seconds": -5}),
		studio.autosave_seconds({"autosave_interval_seconds": "junk"})]
	check(autosave is float and is_equal_approx(autosave, configured) and reads == [300.0, 120.0, 1.0, 1.0, 1.0],
		"the studio reads SaveSystem's autosave interval from game_config (%s s; none: 300; not a positive number: a Timer's 1 s) %s" % [autosave, reads])
	var bad := []
	for a in [float(autosave) if autosave is float else 300.0, 300.0, 120.0, 40.0, 1.0]:
		for n in [0, 1, 3, 5, 50]:
			var g = studio.guard_seconds(n, a)
			if not g is Vector2 or g.x <= 0.0 or g.x >= g.y or g.y > a * 0.5 + 0.001:
				bad.append("%d speaker(s), autosave %.0f s: %s" % [n, a, g])
	check(bad.is_empty(), "the save guard asks to quit, then the hard stop, both by half the autosave interval whatever the config says (wrong: %s)" % [bad])
	var g1 = studio.guard_seconds(1, 300.0)
	var g5 = studio.guard_seconds(5, 300.0)
	check(g1 is Vector2 and g5 is Vector2 and g5.x >= 60.0 and g5.x - g1.x >= 4.0 * 8.0,
		"the guard's budget grows per speaker: a 5-speaker cold run gets %s s before the guard (1 speaker: %s s)" % [g5.x if g5 is Vector2 else g5, g1.x if g1 is Vector2 else g1])
	var src := FileAccess.get_file_as_string(PORTRAIT_STUDIO_SCRIPT)
	var watch := _func_body(src, "_watch")
	var render := _func_body(src, "_render")
	var last_wait := render.rfind("await ")
	var gate := render.find("_quitting", last_wait)
	check(_func_body(src, "_ready").contains("_watchdog.start(") and watch.contains("OS.kill(OS.get_process_id())") and not watch.contains("_quitting")
		and _func_body(src, "_exit_tree").contains("wait_to_finish()") and _func_body(src, "_on_save_guard_timeout") != "",
		"the hard stop: a watchdog thread started in _ready kills the process at the deadline whether or not a quit was asked for (the main loop may be what hangs); joined on exit")
	check(last_wait > 0 and gate > last_wait and gate < render.find("save_png("),
		"_render checks the guard after its last wait and before it writes: after the guard fires, nothing is written")
	check(src.contains("mipmaps/generate=true") and src.contains("detect_3d/compress_to=0"),
		"the studio's header says a new PNG's two import edits (mipmaps/generate=true, detect_3d/compress_to=0)")


## source_error() rejects a wrong type or a conflicting key in a portrait_source (Test 22, Story 25.17 review): a
## string, null, array or bool where a number goes; a look next to a staff_variant; unknown camera keys. A
## function that aborts returns no String and fails the check (no vacuous pass).
func _check_portrait_source_errors(studio: GDScript, sp: Dictionary) -> void:
	var model_src = sp.get("den_fa", {}).get("portrait_source") if sp.get("den_fa") is Dictionary else null
	var staff_src = sp.get("quest_dealer", {}).get("portrait_source") if sp.get("quest_dealer") is Dictionary else null
	if not model_src is Dictionary or not staff_src is Dictionary:
		check(false, "den_fa and quest_dealer have a portrait_source to vary")
		return
	var good := [studio.source_error(model_src), studio.source_error(staff_src)]
	var cases := [["camera.fov", "24"], ["camera.head_height", null], ["camera.yaw_deg", [30]], ["camera.pitch_deg", true],
		["camera.eye_offset", [0.0, "0.1", 0.0]], ["camera.zoom", 2.0], ["camera", null], ["clip", 5], ["bone", ""], ["bone", 3],
		["time", "0"], ["time", -1.0], ["look", 3], ["model", ""], ["model", 7]]
	var passed := []
	for c in cases:
		var e = studio.source_error(_t22_source_with(model_src, c[0], c[1]))
		if not (e is String and e != ""):
			passed.append("%s = %s" % c)
	var anime = studio.source_error(_t22_source_with(staff_src, "look", "anime"))
	var variant_typed = studio.source_error(_t22_source_with(staff_src, "staff_variant", 4))
	check(good == ["", ""] and passed.is_empty() and anime is String and anime != "" and variant_typed is String and variant_typed != "",
		"source_error() type-checks every key and rejects a look next to a staff_variant (the real sources: %s; let through: %s; look + staff_variant: '%s')" % [good, passed, anime])


## A copy of a portrait_source with one key set ("camera.<key>" sets a camera key; null sets null).
static func _t22_source_with(base: Dictionary, key: String, value) -> Dictionary:
	var s: Dictionary = base.duplicate(true)
	if key.begins_with("camera.") and s.get("camera") is Dictionary:
		s.camera[key.trim_prefix("camera.")] = value
	else:
		s[key] = value
	return s


## plan() validates the whole request before anything is written (Test 22, Story 25.17 review): unknown or
## repeated ids, an empty ids= or out=, a relative out=, an unknown argument, a speaker without a source, a bad
## source, an unknown clip, a bad or shared portrait path anywhere in the request: an error and no jobs at all.
func _check_portrait_studio_plan(studio: GDScript, sp: Dictionary, staff: Dictionary) -> void:
	var fixture: Dictionary = sp.duplicate(true)
	var base: Dictionary = sp.get("den_fa", {}).get("portrait_source", {}).duplicate(true) if sp.get("den_fa") is Dictionary else {}
	var add := func(id: String, portrait: String, src: Dictionary) -> void:
		fixture[id] = {"name": id, "portrait": portrait, "colour": "#333333", "portrait_source": src}
	add.call("t22_badcam", PORTRAIT_DIR + "t22_badcam.png", _t22_source_with(base, "camera.fov", "24"))
	add.call("t22_badclip", PORTRAIT_DIR + "t22_badclip.png", _t22_source_with(base, "clip", "T22NoSuchClip"))
	add.call("t22_badbone", PORTRAIT_DIR + "t22_badbone.png", _t22_source_with(base, "bone", "t22_no_bone"))
	add.call("t22_late", PORTRAIT_DIR + "t22_late.png", _t22_source_with(base, "time", 999.0))
	add.call("t22_user", "user://t22_user.png", base)
	add.call("t22_jpg", PORTRAIT_DIR + "t22_jpg.jpg", base)
	add.call("t22_up", PORTRAIT_DIR + "../t22_up.png", base)
	add.call("t22_same", PORTRAIT_DIR + "den_fa.png", base)
	var out := ProjectSettings.globalize_path("user://").path_join("t22_previews")
	var refused := [["ids="], ["ids=den_fa,t22_nobody"], ["ids=elder"], ["ids=den_fa", "out="], ["ids=den_fa", "out=previews"],
		["idz=den_fa"], ["ids=den_fa,den_fa"], ["ids=den_fa", "out=" + out, "out=" + out], ["ids=den_fa,t22_badcam"], ["ids=den_fa,t22_badclip"],
		["ids=den_fa,t22_badbone"], ["ids=den_fa,t22_late"], ["ids=den_fa,t22_user"], ["ids=den_fa,t22_jpg"], ["ids=den_fa,t22_up"], ["ids=den_fa,t22_same"]]
	var let_through := []
	for args in refused:
		var r = studio.plan(PackedStringArray(args), fixture, staff)
		if not (r is Dictionary and str(r.get("error", "")) != "" and r.get("jobs") is Array and (r.jobs as Array).is_empty()):
			let_through.append(" ".join(args))
	check(let_through.is_empty(), "the studio refuses a bad request whole, before any write: unknown/repeated ids, empty ids= or out=, a relative out=, an unknown argument, no source, a bad source, clip, bone, time or portrait path (let through: %s)" % [let_through])
	var all = studio.plan(PackedStringArray(), sp, staff)
	var all_ok: bool = all is Dictionary and str(all.get("error", "?")) == "" and all.get("jobs") is Array \
		and (all.jobs as Array).map(func(j): return j.id) == PORTRAITS_RENDERED \
		and (all.jobs as Array).all(func(j): return j.file == ProjectSettings.globalize_path(PORTRAIT_DIR + j.id + ".png"))
	var one = studio.plan(PackedStringArray(["ids=quest_dealer", "out=" + out]), sp, staff)
	var one_ok: bool = one is Dictionary and str(one.get("error", "?")) == "" and one.get("jobs") is Array and (one.jobs as Array).size() == 1 \
		and one.jobs[0].file == out.path_join("quest_dealer.png")
	check(all_ok and one_ok, "no ids: every speaker with a source, written to its portrait path; out=<absolute folder>: written there instead (%s; %s)" % [
		all.get("error", all) if all is Dictionary else all, one.get("error", one) if one is Dictionary else one])


static func _collect_files(dir_path: String, exts: Array, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not (dir_path == "res://" and sub in ["addons", "build", ".godot"]):
			_collect_files(dir_path.path_join(sub), exts, out)
	for file_name in dir.get_files():
		if file_name.get_extension() in exts:
			out.append(dir_path.path_join(file_name))


## One portrait file (Test 22, AC 6): a 512 × 512 Texture2D, opaque, not blank (luminance spread and many colours),
## imported lossless with mipmaps and detect_3d off (DP-5).
func _check_portrait_png(id: String, path: String) -> void:
	var tex = load(path)
	var img: Image = (tex as Texture2D).get_image() if tex is Texture2D else null
	var why := []
	if img == null:
		why.append("not a Texture2D")
	else:
		if img.get_size() != Vector2i(PORTRAIT_SIZE, PORTRAIT_SIZE):
			why.append("size %s" % img.get_size())
		if not img.has_mipmaps():
			why.append("no mipmaps")
		if img.is_compressed():
			why.append("VRAM-compressed")
		else:
			var lum := PackedFloat32Array()
			var colours := {}
			var opaque := true
			for y in range(0, img.get_height(), 8):
				for x in range(0, img.get_width(), 8):
					var c := img.get_pixel(x, y)
					lum.append(c.get_luminance())
					colours[c.to_html(false)] = true
					opaque = opaque and c.a > 0.999
			var mean := 0.0
			for v in lum:
				mean += v
			mean /= maxf(lum.size(), 1)
			var variance := 0.0
			for v in lum:
				variance += (v - mean) * (v - mean)
			variance /= maxf(lum.size(), 1)
			if variance < 0.003 or colours.size() < 200:
				why.append("blank-ish (luminance variance %.4f, %d colours)" % [variance, colours.size()])
			if not opaque:
				why.append("not opaque")
	var cfg := ConfigFile.new()
	if cfg.load(path + ".import") != OK:
		why.append("no .import")
	elif int(cfg.get_value("params", "compress/mode", -1)) != 0 or not bool(cfg.get_value("params", "mipmaps/generate", false)) \
			or int(cfg.get_value("params", "detect_3d/compress_to", -1)) != 0:
		why.append("import params %s/%s/%s" % [cfg.get_value("params", "compress/mode", "?"), cfg.get_value("params", "mipmaps/generate", "?"),
			cfg.get_value("params", "detect_3d/compress_to", "?")])
	check(why.is_empty(), "%s's portrait: 512 × 512, opaque, not blank, lossless with mipmaps, detect_3d off %s" % [id, why])


## One speaker's portrait_source (Test 22, AC 6): the studio's own resolver and an independent read agree, the body
## loads and has the clip and the bone, the camera numbers are in range.
func _check_portrait_source(studio: GDScript, id: String, src: Dictionary, staff: Dictionary) -> void:
	var r: Dictionary = studio.resolve_source(src, staff)
	var spec_error: String = studio.source_error(src)
	var want_path := ""
	var want_look := str(src.get("look", ""))
	if src.has("staff_variant"):
		var parts := str(src.staff_variant).split("/")
		var v = staff.get("roles", {}).get(parts[0], {}).get("variants", {}).get(parts[1] if parts.size() == 2 else "", null)
		want_path = str(v.get("model_path", "")) if v is Dictionary else ""
		want_look = str(v.get("look", "")) if v is Dictionary else ""
	else:
		want_path = str(src.get("model", ""))
	var why := []
	if want_path == "" or not _res_exists(want_path):
		why.append("no body (%s)" % want_path)
	if str(r.get("error", "")) != "" or str(r.get("path", "")) != want_path or str(r.get("look", "")) != want_look:
		why.append("resolver says %s" % [r])
	if spec_error != "":
		why.append(spec_error)
	if why.is_empty():
		var body = load(want_path)
		var inst: Node = (body as PackedScene).instantiate() if body is PackedScene else null
		if inst == null:
			why.append("doesn't instantiate")
		else:
			var players := inst.find_children("*", "AnimationPlayer", true, false)
			var skels := inst.find_children("*", "Skeleton3D", true, false)
			if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(str(src.get("clip", ""))):
				why.append("no clip %s" % src.get("clip", ""))
			elif float(src.get("time", 0.0)) > (players[0] as AnimationPlayer).get_animation(str(src.clip)).length:
				why.append("time past the clip's end")
			if skels.is_empty() or (skels[0] as Skeleton3D).find_bone(str(src.get("bone", "head"))) < 0:
				why.append("no bone %s" % src.get("bone", "head"))
			inst.free()
	check(why.is_empty(), "%s's portrait_source resolves: %s, look '%s', clip %s, bone %s, camera in range %s" % [
		id, want_path.get_file(), want_look, src.get("clip", "?"), src.get("bone", "head"), why])


# --- Test 23: Anime look presets (2026-10-03, Raphael: "a tad darker") ---
# anime_look.gd reads game_config.json › anime_look_preset. The default is "approved": exactly the look approved in
# Story 25.30 (a StandardMaterial3D toon copy, TOON_BAND 0.12, the shared anime_outline.tres: grow 0.011, ink
# (0.17, 0.09, 0.12)). An unknown name falls back to approved with a warning. The darker presets (anime_look_presets)
# are ShaderMaterials on anime_toon.gdshader with their own outline copy; the imported materials are never edited.
func test_anime_look_presets() -> void:
	print("[Test 23] Anime look presets")
	var cfg = _read_json(GAME_CONFIG_PATH)
	var look = load(ANIME_LOOK_SCRIPT)
	var outline = load(ANIME_OUTLINE)
	# Story 25.23 (AC 11): the default is Raphael's pick from the D2 sheet ("approved" until he picks), and it resolves
	# without a warning (an unknown name would fall back to approved and warn).
	var pick = cfg.get("anime_look_preset") if cfg is Dictionary else null
	look.last_warning = ""
	var resolved: String = look.reload()
	check(pick is String and resolved == pick and look.preset() == pick and str(look.last_warning) == "",
		"the default look preset is game_config's pick and resolves without a warning (anime_look_preset = %s -> %s)" % [pick, resolved])
	look.set_preset("approved")
	check(ResourceLoader.exists(ANIME_TOON_SHADER) and load(ANIME_TOON_SHADER) is Shader, "exists: anime_toon.gdshader")

	# approved = today's materials, property by property: the Story 25.30 recipe applied to a copy of the source.
	var src := StandardMaterial3D.new()
	src.resource_name = "t23_src"
	src.albedo_texture = PlaceholderTexture2D.new()
	src.roughness = 0.85
	src.cull_mode = BaseMaterial3D.CULL_DISABLED
	src.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var want := src.duplicate() as StandardMaterial3D
	want.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	want.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	want.metallic = 0.0
	want.metallic_specular = 0.0
	want.metallic_texture = null
	want.roughness = 0.12
	want.roughness_texture = null
	want.next_pass = outline
	var mk := func() -> Node3D:
		var n := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.name = "T23Body"
		mi.mesh = BoxMesh.new()
		(mi.mesh as BoxMesh).material = src
		n.add_child(mi)
		return n
	var m1: Node3D = mk.call()
	var m2: Node3D = mk.call()
	var mi1 := m1.get_child(0) as MeshInstance3D
	var mi2 := m2.get_child(0) as MeshInstance3D
	var n1: int = look.apply(m1)
	var n1b: int = look.apply(m1)
	look.apply(m2)
	var ap = mi1.get_surface_override_material(0)
	var diff := []
	if ap is StandardMaterial3D:
		for prop in want.get_property_list():
			if prop.usage & PROPERTY_USAGE_STORAGE and ap.get(prop.name) != want.get(prop.name):
				diff.append(prop.name)
	else:
		diff.append("not a StandardMaterial3D")
	var o := outline as StandardMaterial3D
	check(look.TOON_BAND == 0.12 and n1 == 1 and n1b == 0 and diff.is_empty() and ap.next_pass == outline
			and mi2.get_surface_override_material(0) == ap and src.diffuse_mode != BaseMaterial3D.DIFFUSE_TOON and is_equal_approx(src.roughness, 0.85),
		"approved: exactly today's toon (TOON_BAND 0.12, toon diffuse, no specular, no metal, the shared outline as next_pass), one copy shared, the source untouched (differs in %s)" % [diff])
	check(o != null and is_equal_approx(o.grow_amount, 0.011) and o.albedo_color.is_equal_approx(Color(0.17, 0.09, 0.12, 1.0))
			and o.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and o.cull_mode == BaseMaterial3D.CULL_FRONT and o.grow,
		"approved: the shared outline as approved (grow %.3f, ink %s)" % [o.grow_amount if o else 0.0, o.albedo_color if o else Color()])

	# an unknown preset: approved, with a warning
	look.last_warning = ""
	var got: String = look.set_preset("chibi")
	check(got == "approved" and look.preset() == "approved" and str(look.last_warning).contains("unknown preset 'chibi'") and look.apply(m1) == 0,
		"an unknown preset falls back to approved with a warning (%s; %s)" % [got, look.last_warning])

	# the darker presets: a shader toon per source (shared), their own outline, roughness > 0; back to approved re-tones
	var presets: Dictionary = cfg.get("anime_look_presets", {}) if cfg is Dictionary and cfg.get("anime_look_presets") is Dictionary else {}
	for name in ["darker_a", "darker_b"]:
		var entry: Dictionary = presets.get(name, {}) if presets.get(name) is Dictionary else {}
		var on: String = look.set_preset(name)
		var k1: int = look.apply(m1)
		var k2: int = look.apply(m2)
		var sm = mi1.get_surface_override_material(0)
		var ok: bool = on == name and k1 == 1 and k2 == 1 and look.apply(m1) == 0 and sm is ShaderMaterial and look.is_toon(sm)
		ok = ok and mi2.get_surface_override_material(0) == sm and (sm as ShaderMaterial).shader == load(ANIME_TOON_SHADER)
		ok = ok and float(sm.get_shader_parameter("ink_roughness")) > 0.0 and sm.get_shader_parameter("albedo_nearest") == src.albedo_texture
		var np = sm.next_pass if sm is Material else null
		ok = ok and np is StandardMaterial3D and np != outline and is_equal_approx(np.grow_amount, float(entry.get("outline_grow", -1)))
		var p: Dictionary = look.params(name)
		for key in ["band_threshold", "band_softness", "lit_gain", "shadow_level", "shadow_fill", "shadow_desaturate"]:
			ok = ok and entry.has(key) and is_equal_approx(float(sm.get_shader_parameter(key)), float(entry[key])) and is_equal_approx(float(p[key]), float(entry[key]))
		check(ok and src.diffuse_mode != BaseMaterial3D.DIFFUSE_TOON and src.next_pass == null and is_equal_approx(o.grow_amount, 0.011),
			"%s: a shared anime_toon ShaderMaterial (its numbers from game_config, ink roughness > 0) with its own outline (grow %s), the source and the shared outline untouched" % [name, entry.get("outline_grow", "?")])
	look.set_preset("approved")
	check(look.apply(m1) == 1 and mi1.get_surface_override_material(0) == ap, "back to approved: the body is re-toned with the same approved copy")

	# bad numbers in a preset: the approved defaults, with a warning
	look._presets["t23_bad"] = {"lit_gain": -1, "shadow_tint": [0, 0, 0], "outline_grow": "x", "band_softness": 0.3}
	look.last_warning = ""
	var bad: Dictionary = look.params("t23_bad")
	check(bad.lit_gain == 1.0 and bad.shadow_tint == Color(1, 1, 1) and is_equal_approx(bad.outline_grow, 0.011) and is_equal_approx(bad.band_softness, 0.3)
			and is_equal_approx(look.params("t23_none").band_softness, 0.12) and str(look.last_warning) != "",
		"a preset's bad numbers take the approved defaults, with a warning; good ones and the defaults stay")
	look.reload()
	m1.free()
	m2.free()
	print("")


# --- Test 24: The player's body (Story 25.31, AC 5) ---
# One man for the demo (AH-1), on route RL: Player.tscn bakes no body; player.gd loads data/characters/player.json's
# model (else its fallback, else the old Rogue), keeps the old yaw, tones his own body (look "realistic"), and plays
# Running_A at speed / run_ground_speed (V9: the gameplay speed stays, the feet don't skate). The GLB passes the RL rules
# (Test 19's checker); the worn sword is a prop on hips and nothing hangs from his hands (R-9).
func test_player_body() -> void:
	print("[Test 24] The player's body")
	var spec = _read_json(PLAYER_DATA_PATH) if FileAccess.file_exists(PLAYER_DATA_PATH) else null
	check(spec is Dictionary and str(spec.get("model_path", "")) == PLAYER_BODY_PATH and ResourceLoader.exists(PLAYER_BODY_PATH)
		and str(spec.get("fallback_model_path", "")) == PLAYER_FALLBACK_PATH and ResourceLoader.exists(PLAYER_FALLBACK_PATH)
		and str(spec.get("look", "")) == "realistic" and str(spec.get("_note", "")).length() > 10,
		"player.json: his realistic body, the KayKit Rogue as its fallback, look realistic, a _note")
	var ground := float(spec.get("run_ground_speed", 0.0)) if spec is Dictionary else 0.0
	check(absf(ground - PLAYER_RUN_GROUND_SPEED) < 0.005, "player.json run_ground_speed %.3f is Running_A's measured ground speed on his body (%.3f m/s)" % [ground, PLAYER_RUN_GROUND_SPEED])
	var tscn := FileAccess.get_file_as_string(PLAYER_SCENE)
	check(not tscn.contains("Rogue.glb") and not tscn.contains("[node name=\"Rogue\"") and not tscn.contains("instance=ExtResource"),
		"Player.tscn bakes no body (the body comes from player.json)")
	var src := FileAccess.get_file_as_string(PLAYER_SCRIPT)
	check(not src.contains("$Rogue") and not src.contains("rogue_model") and src.contains("PLAYER_DATA") and not src.contains("/root/"),
		"player.gd: no $Rogue, no rogue_model, the body from PLAYER_DATA, no autoload path")
	_check_staff_glb(PLAYER_BODY_PATH, [[], "Player_", ["Player_Sword"], [], ["Walk_Bar", "Wipe", "Pour", "Serve", "Restock", "Write", "Brief"],
		["Idle", "Running_A"], [], RL_TRI_BUDGET, RL_BODY_SURFACES, "realistic"])
	# R-9: the sword is worn (a prop on hips), nothing on his hand slots
	var inst := (load(PLAYER_BODY_PATH) as PackedScene).instantiate() if ResourceLoader.exists(PLAYER_BODY_PATH) else Node3D.new()
	var atts := inst.find_children("*", "BoneAttachment3D", true, false)
	var psks := inst.find_children("*", "Skeleton3D", true, false)
	var on := {}
	for a in atts:
		# glTF puts a bone-parented prop on an item bone of its own (KayKit's way): name the rig bone it hangs from
		var bn := str((a as BoneAttachment3D).bone_name)
		if not psks.is_empty():
			var sk := psks[0] as Skeleton3D
			var bi := sk.find_bone(bn)
			if bi >= 0 and sk.get_bone_parent(bi) >= 0 and bn.begins_with("Player_"):
				bn = sk.get_bone_name(sk.get_bone_parent(bi))
		on[bn] = a.find_children("*", "MeshInstance3D", true, false).map(func(m): return str(m.name))
	inst.free()
	check(on.get("hips", []).has("Player_Sword") and not on.has("handslot.r") and not on.has("handslot.l"),
		"his sword is a prop on hips (worn, the pick's), nothing on his hand slots (R-9) (%s)" % [on])

	var world := Node3D.new()
	root.add_child(world)
	var pl = (load(PLAYER_SCENE) as PackedScene).instantiate()
	world.add_child(pl)
	var why := []
	if pl.body_model == null:
		why.append("no body")
	else:
		if pl.body_path != PLAYER_BODY_PATH or pl.using_fallback:
			why.append("body %s" % pl.body_path)
		if absf(rad_to_deg(pl.body_model.rotation.y) - 172.07) > 0.1 or absf(pl.body_model.position.y + 0.75) > 0.001:
			why.append("yaw %.2f / y %.3f" % [rad_to_deg(pl.body_model.rotation.y), pl.body_model.position.y])
		if pl.body_look != "realistic":
			why.append("look '%s'" % pl.body_look)
		var toned := 0
		var surfaces := 0
		var look = load(ANIME_LOOK_SCRIPT)
		for mi in pl.body_model.find_children("*", "MeshInstance3D", true, false):
			for s in ((mi as MeshInstance3D).mesh.get_surface_count() if (mi as MeshInstance3D).mesh else 0):
				surfaces += 1
				if look.is_toon((mi as MeshInstance3D).get_surface_override_material(s)):
					toned += 1
		if surfaces < 2 or toned != surfaces:
			why.append("toned %d of %d surfaces" % [toned, surfaces])
		if absf(pl.speed - PLAYER_SPEED) > 1e-6 or absf(pl.run_rate - PLAYER_SPEED / PLAYER_RUN_GROUND_SPEED) > 0.001:
			why.append("speed %.2f, run rate %.3f" % [pl.speed, pl.run_rate])
		pl._play_animation("Running_A", 0.0)
		var ap: AnimationPlayer = pl.animation_player
		if ap == null or ap.current_animation != "Running_A" or absf(ap.get_playing_speed() * PLAYER_RUN_GROUND_SPEED - PLAYER_SPEED) > 0.01:
			why.append("Running_A at %.3f" % (ap.get_playing_speed() if ap else -1.0))
		pl._play_animation("Idle", 0.0)
		if ap == null or absf(ap.get_playing_speed() - 1.0) > 1e-6:
			why.append("Idle at %.3f" % (ap.get_playing_speed() if ap else -1.0))
	check(why.is_empty(), "Player.tscn: his body from player.json, the old yaw (172.07°) at the capsule's foot, the realistic look on every surface, Running_A at speed / run_ground_speed (the feet slide at 5.0 m/s: no skating), Idle at 1.0 (wrong: %s)" % [why])
	pl.queue_free()
	# the fallback: his model missing -> the KayKit Rogue, its imported look, Running_A at 1.0
	var fb = load(PLAYER_SCRIPT).new()
	fb.data_path = PLAYER_MISSING_FIXTURE
	var cap := CollisionShape3D.new()
	cap.name = "CollisionShape3D"
	cap.shape = CapsuleShape3D.new()
	(cap.shape as CapsuleShape3D).height = 1.5
	fb.add_child(cap)
	world.add_child(fb)
	var fwhy := []
	if fb.body_model == null or fb.body_path != PLAYER_FALLBACK_PATH or not fb.using_fallback or fb.body_look != "" or fb.run_rate != 1.0:
		fwhy.append("%s, fallback %s, look '%s', rate %s" % [fb.body_path, fb.using_fallback, fb.body_look, fb.run_rate])
	elif fb.body_model.find_children("*", "MeshInstance3D", true, false).any(func(m): return (m as MeshInstance3D).get_surface_override_material(0) != null):
		fwhy.append("the fallback body toned")
	check(fwhy.is_empty(), "his model missing: the fallback (the KayKit Rogue) with its imported look and Running_A at 1.0 (wrong: %s)" % [fwhy])
	fb.queue_free()
	world.queue_free()
	await process_frame
	print("")


# --- Test 25: Light and mood (Story 25.23) ---
# The hall's light is data: a MOOD (today = the scene as saved, moody_a, moody_b) and a PHASE (morning ... dawn; day =
# the identity) from game_config.json, combined and applied by scripts/game/tavern_lighting.gd (static helpers, no
# class_name). The ink rule (LM-3): the one DirectionalLight keeps its transform, colour and energy in every mood and
# phase; only its cull mask moves (all layers, or the EdgeQuad's layer 20). Shadows only on the lights a mood lists
# (candles never). The phases blend; GameBus.day_phase_changed drives them. The fireplace's floor rune shows while the
# fire owns E. Headless: no rendering; a fixture rig of stand-in lights, a Hearth and a pillar instance.
func test_light_and_mood() -> void:
	print("[Test 25] Light and mood")
	var cfg = _read_json(GAME_CONFIG_PATH)
	var moods = cfg.get("tavern_light_moods") if cfg is Dictionary else null
	var phases = cfg.get("tavern_light_phases") if cfg is Dictionary else null
	var cfg_ok: bool = cfg is Dictionary and cfg.get("tavern_light_mood") is String and moods is Dictionary and phases is Dictionary \
		and moods.get("moody_a") is Dictionary and moods.get("moody_b") is Dictionary and str(moods.get("_comment", "")).length() > 40 \
		and LM_PHASES.all(func(p): return phases.get(p) is Dictionary) and str(phases.get("_comment", "")).length() > 40 \
		and str(cfg.get("tavern_light_phase_default", "")) in LM_PHASES \
		and (cfg.get("tavern_light_blend_seconds") is float or cfg.get("tavern_light_blend_seconds") is int) and float(cfg.get("tavern_light_blend_seconds", 0)) > 0.0 \
		and (cfg.get("tavern_light_morning_hold_seconds") is float or cfg.get("tavern_light_morning_hold_seconds") is int) and float(cfg.get("tavern_light_morning_hold_seconds", 0)) > 0.0
	check(cfg_ok, "game_config: tavern_light_mood, the moods (moody_a, moody_b, a _comment), the six phases (a _comment), the default phase, the blend and morning-hold seconds")
	var TL = load(TAVERN_LIGHTING_SCRIPT) if ResourceLoader.exists(TAVERN_LIGHTING_SCRIPT) else null
	var src := FileAccess.get_file_as_string(TAVERN_LIGHTING_SCRIPT)
	var api := ["mood_names", "resolve_mood", "mood_params", "phase_params", "combine", "blend", "reload_config", "load_config", "resolve_phase", "set_mood", "set_phase", "current"]
	var missing := api.filter(func(m): return TL == null or not TL.get_script_method_list().any(func(x): return x.name == m))
	check(TL is GDScript and missing.is_empty() and not src.begins_with("class_name") and not src.contains("\nclass_name"),
		"tavern_lighting.gd loads by path (no class_name) with its API (missing: %s)" % [missing])
	if TL == null or not missing.is_empty():
		print("")
		return
	TL.reload_config()
	var names: Array = TL.mood_names()
	check(names.size() >= 3 and names[0] == "today" and names.has("moody_a") and names.has("moody_b") and not names.any(func(n): return str(n).begins_with("_")),
		"mood names: today first, then the config's (%s); _comment skipped" % [names])
	check(TL.configured_mood() == str(cfg.get("tavern_light_mood")) or (str(cfg.get("tavern_light_mood")) == "today" and TL.configured_mood() == "today"),
		"the configured mood resolves: %s" % TL.configured_mood())

	# fallbacks
	TL.last_warning = ""
	check(TL.resolve_mood("candlelit_nope") == "today" and str(TL.last_warning).contains("candlelit_nope"),
		"an unknown mood -> today, with a warning (%s)" % TL.last_warning)
	TL.last_warning = ""
	TL.load_config({"tavern_light_moods": {"today": {"fill_energy": 9.0}, "t25": {"fill_energy": -1, "ambient_color": [0.1, 0.2], "bar_energy": "x",
		"ambient_energy": 0.5, "sun_lights_hall": false, "desk_energy": 1.0, "hearth_scale": 1.2, "candle_scale": 1.0, "window_color": [1, 1, 1],
		"window_energy": 1.0, "shadow_lights": ["hearth", "candles"], "omni_shadow_mode": "dual_paraboloid", "pillar_glow": 1.0}}})
	var today_warn: String = TL.last_warning
	var names2: Array = TL.mood_names()
	TL.last_warning = ""
	var t25: Dictionary = TL.mood_params("t25", TL.TODAY_VALUES)
	var w25: String = TL.last_warning
	check(today_warn.contains("today") and names2 == ["today", "t25"], "a config entry named today is ignored, with a warning (%s)" % today_warn)
	check(is_equal_approx(float(t25.fill_energy), float(TL.TODAY_VALUES.fill_energy)) and (t25.ambient_color as Color).is_equal_approx(TL.TODAY_VALUES.ambient_color)
		and is_equal_approx(float(t25.bar_energy), float(TL.TODAY_VALUES.bar_energy)) and is_equal_approx(float(t25.exposure), float(TL.TODAY_VALUES.exposure))
		and t25.shadow_lights == ["hearth"] and is_equal_approx(float(t25.ambient_energy), 0.5) and w25 != "",
		"a bad number (negative energy, a 2-number colour, a string), a missing key and a shadowed candle fall back per key to today's, with a warning (%s)" % w25)
	TL.last_warning = ""
	check(TL.resolve_phase("reveal") == "late_night" and TL.resolve_phase("teatime") == "" and str(TL.last_warning).contains("teatime"),
		"phases: \"reveal\" is late_night (24.2's name), an unknown one resolves to nothing, with a warning")
	TL.reload_config()

	# today pinned to the scene as saved (2026-10-04)
	var tav := _scene_nodes(TAVERN_SCENE_PATH)
	var sun: Dictionary = tav.get(TAVERN_ENV + "Outdoors Light", {})
	var fill: Dictionary = tav.get(TAVERN_ENV + "TavernLight", {})
	var bar: Dictionary = tav.get(TAVERN_ENV + "BarLight", {})
	var we: Dictionary = tav.get(TAVERN_ENV + "WorldEnvironment", {})
	var envr = we.get("props", {}).get("environment")
	var sp: Dictionary = sun.get("props", {})
	var fp: Dictionary = fill.get("props", {})
	var bp: Dictionary = bar.get("props", {})
	var pinned: bool = sun.get("type") == "DirectionalLight3D" and (sp.get("transform", Transform3D()) as Transform3D).is_equal_approx(LM_SUN_XF)
	pinned = pinned and (sp.get("light_color", Color()) as Color).is_equal_approx(Color(1, 0.8, 0.5)) and is_equal_approx(float(sp.get("light_energy", 0)), 1.5)
	pinned = pinned and not sp.has("light_cull_mask") and not sp.get("shadow_enabled", false)
	pinned = pinned and (fp.get("transform", Transform3D()) as Transform3D).origin.is_equal_approx(Vector3(14.0983, 4.10605, -13.4522))
	pinned = pinned and (fp.get("light_color", Color()) as Color).is_equal_approx(Color(0.6, 0.8, 1)) and is_equal_approx(float(fp.get("light_energy", 0)), 2.0)
	pinned = pinned and is_equal_approx(float(fp.get("omni_range", 0)), 15.0) and not fp.get("shadow_enabled", false)
	pinned = pinned and (bp.get("transform", Transform3D()) as Transform3D).origin.is_equal_approx(Vector3(-3.06924, 2.08058, -3.57674))
	pinned = pinned and (bp.get("light_color", Color()) as Color).is_equal_approx(Color(1, 0.9, 0.6)) and is_equal_approx(float(bp.get("light_energy", 0)), 1.5)
	pinned = pinned and is_equal_approx(float(bp.get("omni_range", 0)), 4.0) and not bp.get("shadow_enabled", false)
	pinned = pinned and envr is Environment and (envr as Environment).ambient_light_color.is_equal_approx(Color(0.4, 0.5, 0.7))
	pinned = pinned and is_equal_approx((envr as Environment).ambient_light_energy, 0.3) and (envr as Environment).ambient_light_source == Environment.AMBIENT_SOURCE_BG
	pinned = pinned and (envr as Environment).background_mode == Environment.BG_CLEAR_COLOR and is_equal_approx((envr as Environment).tonemap_exposure, 1.0)
	var hs := _scene_nodes(HEARTH_SCENE_PATH)
	var fl: Dictionary = hs.get("FireLight", {}).get("props", {})
	pinned = pinned and is_equal_approx(float(fl.get("omni_range", 0)), 6.0) and not fl.get("shadow_enabled", false) and fl.get("light_color", Color()) == Color(1, 0.6, 0, 1)
	var ds := _scene_nodes(DESK_SCENE_PATH)
	var dl: Dictionary = ds.get("DeskLight", {}).get("props", {})
	pinned = pinned and (dl.get("transform", Transform3D()) as Transform3D).origin.is_equal_approx(Vector3(0.76, 1.4, -0.22))
	pinned = pinned and (dl.get("light_color", Color()) as Color).is_equal_approx(Color(1, 0.9, 0.6)) and is_equal_approx(float(dl.get("light_energy", 0)), 1.5)
	pinned = pinned and is_equal_approx(float(dl.get("omni_range", 0)), 4.0) and not dl.get("shadow_enabled", false) and ds.get("DeskLight", {}).get("groups", []).is_empty()
	var tt: Dictionary = TL.TODAY_VALUES
	pinned = pinned and is_equal_approx(float(tt.fill_energy), 2.0) and is_equal_approx(float(tt.bar_energy), 1.5) and is_equal_approx(float(tt.desk_energy), 1.5)
	pinned = pinned and tt.ambient_background == true and tt.sun_lights_hall == true and float(tt.candle_scale) == 0.0 and float(tt.window_energy) == 0.0
	pinned = pinned and tt.shadow_lights == [] and float(tt.hearth_scale) == 1.0 and float(tt.pillar_glow) == 1.0 and float(tt.exposure) == 1.0
	check(pinned, "today pinned: MainTavern's sun, TavernLight, BarLight, Environment (Background ambient, no source set), the hearth's FireLight (range 6, no shadow) and the desk's DeskLight are the 2026-10-04 values, and TODAY matches them")

	# the ink rule in the scene
	var dirs := tav.keys().filter(func(k): return tav[k].type == "DirectionalLight3D")
	var quad: Dictionary = tav.get(TAVERN_EDGE_QUAD, {}).get("props", {})
	var on20 := tav.keys().filter(func(k): return k != TAVERN_EDGE_QUAD and int(tav[k].props.get("layers", 1)) & INK_LAYER_MASK != 0)
	check(dirs.size() == 1 and int(quad.get("layers", 1)) == INK_LAYER_MASK and int(quad.get("cast_shadow", 1)) == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and on20.is_empty(),
		"the ink light: one DirectionalLight in MainTavern (%d), the EdgeQuad on layer 20 alone with cast_shadow off, no other node on layer 20 (%s)" % [dirs.size(), on20])
	var cam := Camera3D.new()
	cam.set_script(load(CAMERA_SCRIPT))
	root.add_child(cam)
	var cmask := cam.cull_mask
	cam.free()
	check(cmask & INK_LAYER_MASK != 0 and cmask & 3 == 3, "the tavern camera sees layers 1, 2 and the EdgeQuad's 20 (cull mask %d)" % cmask)
	var svp: Dictionary = tav.get("SubViewportContainer/SubViewport", {}).get("props", {})
	check(int(svp.get("positional_shadow_atlas_size", 0)) == 4096, "the hall's SubViewport has a positional shadow atlas set (%s; 0 renders no omni shadow)" % [svp.get("positional_shadow_atlas_size")])

	# blends, the identity day, the glow floor, the ink mask, over every mood x phase
	var a := {"x": 1.0, "c": Color(0, 0, 0), "b": true, "s": ["hearth"]}
	var b := {"x": 3.0, "c": Color(1, 0.5, 0), "b": false, "s": []}
	var mid: Dictionary = TL.blend(a, b, 0.5)
	check(TL.blend(a, b, 0.0) == a and TL.blend(a, b, 1.0) == b and is_equal_approx(float(mid.x), 2.0) and (mid.c as Color).is_equal_approx(Color(0.5, 0.25, 0))
		and mid.b == true and mid.s == ["hearth"], "blend: t 0 is a, t 1 is b, t 0.5 halves numbers and colours (switches hold until the end)")
	var bad := []
	for m in TL.mood_names():
		var mp: Dictionary = TL.mood_params(m, TL.TODAY_VALUES)
		if TL.combine(mp, TL.phase_params("day")) != mp:
			bad.append("%s x day is not %s" % [m, m])
		for ph in LM_PHASES:
			var c: Dictionary = TL.combine(mp, TL.phase_params(ph))
			if float(c.pillar_glow) < 0.6 or float(c.pillar_glow) > 2.0:
				bad.append("%s/%s glow %.2f" % [m, ph, c.pillar_glow])
			if float(c.hearth_scale) <= 0.0:
				bad.append("%s/%s hearth %.2f" % [m, ph, c.hearth_scale])
			if int(TL.sun_mask(c, 4294967295)) & INK_LAYER_MASK == 0:
				bad.append("%s/%s sun mask" % [m, ph])
			if not (c.shadow_lights as Array).all(func(n): return str(n) in ["hearth", "bar", "desk", "fill"]):
				bad.append("%s/%s shadows %s" % [m, ph, c.shadow_lights])
	check(bad.is_empty(), "every mood x phase (%d x %d): day is the identity, pillar glow in 0.6..2.0, hearth scale > 0, the sun keeps layer 20, shadows only on hearth/bar/desk/fill (wrong: %s)" % [TL.mood_names().size(), LM_PHASES.size(), bad])
	for m in ["moody_a", "moody_b"]:
		var mp: Dictionary = TL.mood_params(m, TL.TODAY_VALUES)
		check(not mp.ambient_background and mp.sun_lights_hall == false and float(mp.fill_energy) < float(TL.TODAY_VALUES.fill_energy) and float(mp.candle_scale) > 0.0
			and float(mp.hearth_scale) > 1.0 and mp.shadow_lights.has("hearth"), "%s: a dim explicit ambient, the sun off the hall, the cold fill low, candles lit, the hearth up and shadowed" % m)
	var ev_p: Dictionary = TL.phase_params("evening")
	var ln_p: Dictionary = TL.phase_params("late_night")
	check((ev_p.window_color as Color).b > (ev_p.window_color as Color).r and (ln_p.window_color as Color).b > (ln_p.window_color as Color).r
		and float(ev_p.window_energy) < 1.0 and float(ln_p.window_energy) < float(ev_p.window_energy) and float(ev_p.candle_scale) > 1.0,
		"evening and late night: cold blue-teal windows, dimmer; the candles rise at evening (amber inside, teal outside)")

	# the fixture rig: apply moods and phases to stand-in lights, a Hearth and a pillar
	var rig := _lm_rig(TL)
	var ctl = rig.ctl
	var sunl: DirectionalLight3D = rig.sun
	var fire: OmniLight3D = rig.hearth.get_node("FireLight")
	var sun_xf := sunl.transform
	var ink_bad := []
	for m in TL.mood_names():
		ctl.set_mood(m)
		for ph in LM_PHASES:
			ctl.set_phase(ph, 0.0)
			if sunl.transform != sun_xf or sunl.light_color != Color(1, 0.8, 0.5) or sunl.light_energy != 1.5 or sunl.light_cull_mask & INK_LAYER_MASK == 0:
				ink_bad.append("%s/%s" % [m, ph])
			var want_glow: float = float(TL.combine(TL.mood_params(m, ctl.today), TL.phase_params(ph)).pillar_glow)
			if not is_equal_approx(rig.pillar.glow_energy, want_glow):
				ink_bad.append("%s/%s glow %.2f != %.2f" % [m, ph, rig.pillar.glow_energy, want_glow])
	check(ink_bad.is_empty() and ctl.applied_count >= 8, "the rig over every mood x phase: the sun's transform, colour and energy never change, its mask keeps layer 20; the pillar's glow is mood x phase (wrong: %s; %d applied)" % [ink_bad, ctl.applied_count])
	ctl.set_phase("day", 0.0)
	ctl.set_mood("moody_a")
	var ma: Dictionary = TL.mood_params("moody_a", ctl.today)
	var envn: Environment = rig.env.environment
	var cand := rig.candles as Array
	var rig_ok: bool = envn.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and envn.ambient_light_color.is_equal_approx(ma.ambient_color)
	rig_ok = rig_ok and sunl.light_cull_mask == INK_LAYER_MASK and is_equal_approx(rig.fill.light_energy, float(ma.fill_energy))
	rig_ok = rig_ok and is_equal_approx(rig.bar.light_energy, float(ma.bar_energy)) and is_equal_approx(rig.desk.light_energy, float(ma.desk_energy))
	rig_ok = rig_ok and is_equal_approx(rig.hearth.light_scale, float(ma.hearth_scale)) and fire.shadow_enabled and fire.shadow_blur == 0.0 and fire.light_size == 0.0
	rig_ok = rig_ok and not rig.fill.shadow_enabled and not rig.bar.shadow_enabled and not rig.desk.shadow_enabled
	rig_ok = rig_ok and cand.all(func(c): return c.visible and not c.shadow_enabled and is_equal_approx(c.light_energy, float(c.get_meta("base_energy")) * float(ma.candle_scale)))
	rig_ok = rig_ok and (rig.window as SpotLight3D).visible and not (rig.window as SpotLight3D).shadow_enabled and (rig.window as SpotLight3D).light_color.is_equal_approx(ma.window_color)
	check(rig_ok, "moody_a on the rig: the explicit ambient, the sun on layer 20 only, fill/bar/desk at its energies, the hearth's light_scale and hard shadow, candles lit and unshadowed, the window lit")
	# review 2026-10-04: a light saved without base_energy keeps its authored energy as the base (snapshotted once at
	# _ready), so "today" (scale 0) can't zero it for good; the rig went through today and every mood x phase above
	ctl.set_mood("today")
	ctl.set_mood("moody_a")
	var bare: OmniLight3D = rig.bare
	var bare_win: SpotLight3D = rig.bare_win
	check(bare.visible and is_equal_approx(bare.light_energy, 0.9 * float(ma.candle_scale)) and is_equal_approx(float(bare.get_meta("base_energy", -1.0)), 0.9)
		and bare_win.visible and is_equal_approx(bare_win.light_energy, 2.0 * float(ma.window_energy)) and is_equal_approx(float(bare_win.get_meta("base_energy", -1.0)), 2.0),
		"a candle and a window light saved without base_energy keep their authored energy as the base through today (scale 0) and back (candle %.3f, window %.3f)" % [bare.light_energy, bare_win.light_energy])
	# review 2026-10-04: the window light cards share one material in MainTavern; each gets its own copy so its alpha
	# (base_alpha x window_energy) is its own, and the shared material is never written
	var rig_cards: Array = rig.cards
	var cm0 = (rig_cards[0] as MeshInstance3D).get_surface_override_material(0)
	var cm1 = (rig_cards[1] as MeshInstance3D).get_surface_override_material(0)
	var shared_mat: StandardMaterial3D = rig.card_mat
	var cards_ok: bool = cm0 is StandardMaterial3D and cm1 is StandardMaterial3D and cm0 != cm1 and cm0 != shared_mat and cm1 != shared_mat
	cards_ok = cards_ok and is_equal_approx((cm0 as StandardMaterial3D).albedo_color.a, 0.3 * float(ma.window_energy)) and is_equal_approx((cm1 as StandardMaterial3D).albedo_color.a, 0.7 * float(ma.window_energy))
	cards_ok = cards_ok and (cm1 as StandardMaterial3D).blend_mode == BaseMaterial3D.BLEND_MODE_ADD and shared_mat.albedo_color == Color(1, 1, 1, 1) and rig_cards.all(func(q): return q.visible)
	check(cards_ok, "two window light cards sharing one material: each has its own copy and its own alpha (0.3 and 0.7 x window_energy); the shared material is untouched")
	ctl.set_mood("today")
	var back: bool = envn.ambient_light_source == Environment.AMBIENT_SOURCE_BG and envn.ambient_light_color.is_equal_approx(Color(0.4, 0.5, 0.7)) and is_equal_approx(envn.ambient_light_energy, 0.3)
	back = back and sunl.light_cull_mask == 4294967295 and rig.fill.light_energy == 2.0 and rig.bar.light_energy == 1.5 and rig.desk.light_energy == 1.5
	back = back and rig.hearth.light_scale == 1.0 and not fire.shadow_enabled and fire.shadow_blur == 1.0 and cand.all(func(c): return not c.visible)
	back = back and not (rig.window as SpotLight3D).visible and rig.pillar.glow_energy == 1.0 and is_equal_approx(envn.tonemap_exposure, 1.0)
	check(back, "back to today on the rig: every value exactly as the rig was saved (Background ambient, the sun on all layers, no shadow, candles and windows off)")
	# phases blend: GameBus drives them, a new phase mid-blend starts from the blended values
	var gb = root.get_node_or_null("GameBus")
	check(gb != null and gb.has_signal("day_phase_changed"), "GameBus has day_phase_changed(phase)")
	ctl.set_mood("moody_b")
	var mb: Dictionary = TL.mood_params("moody_b", ctl.today)
	if gb and gb.has_signal("day_phase_changed"):
		gb.day_phase_changed.emit("evening")
	var secs := float(TL.blend_seconds())
	ctl._process(secs * 0.5)
	var half: float = rig.fill.light_energy
	var want_half: float = lerpf(float(mb.fill_energy), float(mb.fill_energy) * float(TL.phase_params("evening").fill_scale), 0.5)
	ctl.set_phase("late_night")
	var no_jump: bool = is_equal_approx(rig.fill.light_energy, half)
	ctl._process(secs + 0.1)
	var end_ok: bool = ctl.phase == "late_night" and is_equal_approx(rig.fill.light_energy, float(mb.fill_energy) * float(TL.phase_params("late_night").fill_scale))
	check(is_equal_approx(half, want_half) and no_jump and end_ok, "GameBus.day_phase_changed(evening) blends over %.1f s (half way %.3f); late_night mid-blend starts from there (no jump) and ends exactly there" % [secs, half])
	ctl.set_phase("teatime")
	check(ctl.phase == "late_night" and str(TL.last_warning).contains("teatime"), "an unknown phase: the light stays, with a warning")
	var gm = root.get_node_or_null("GameManager")
	var had_brief = gm.get("has_pending_briefing") if gm else null
	if gm and gb:
		gm.set("has_pending_briefing", false)
		gb.day_phase_changed.emit("morning")
		ctl._process(float(TL.morning_hold_seconds()) - 0.5)
		var held: bool = ctl.phase == "morning"
		ctl._process(1.0)
		ctl._process(secs + 0.1)
		check(held and ctl.phase == "day", "morning (the signal) without a briefing turns to day after the hold (%.0f s)" % TL.morning_hold_seconds())
		gm.set("has_pending_briefing", true)
		gb.day_phase_changed.emit("morning")
		ctl._process(float(TL.morning_hold_seconds()) + 1.0)
		check(ctl.phase == "morning", "morning with a briefing pending waits for it (the briefing's end sends day)")
		gb.day_phase_changed.emit("day")
		ctl._process(secs + 0.1)
		check(ctl.phase == "day", "the briefing's day ends the morning")
	if gm:
		gm.set("has_pending_briefing", had_brief)
	rig.root.free()
	# set before _ready is kept; a fresh scene starts in the default phase
	var rig2 := _lm_rig(TL, "evening")
	check(rig2.ctl.phase == "evening", "set_phase before _ready is kept (%s)" % rig2.ctl.phase)
	rig2.root.free()
	var rig3 := _lm_rig(TL)
	check(rig3.ctl.phase == str(cfg.get("tavern_light_phase_default", "day")) and rig3.ctl.mood == TL.configured_mood(), "a fresh rig starts in the configured mood and the default phase")
	rig3.root.free()
	# review 2026-10-04: set_mood before _ready is kept (like set_phase's), not overwritten by the configured mood
	var rig4 := _lm_rig(TL, "", null, "moody_b")
	var mb4: Dictionary = TL.mood_params("moody_b", rig4.ctl.today)
	check(rig4.ctl.mood == "moody_b" and (rig4.env.environment as Environment).ambient_light_color.is_equal_approx(mb4.ambient_color)
		and (rig4.sun as DirectionalLight3D).light_cull_mask == INK_LAYER_MASK, "set_mood before _ready is kept and applied at _ready (%s)" % rig4.ctl.mood)
	rig4.root.free()
	# review 2026-10-04 (MEDIUM): MainTavern's Environment is a sub-resource every instance of the cached scene shares.
	# A reload (Pause -> Load Game -> reload_current_scene) while a dimmed phase is on must still snapshot the scene's
	# saved light as today: each controller works on its own copy and never writes the shared one
	var shared_env := Environment.new()
	shared_env.ambient_light_color = Color(0.4, 0.5, 0.7)
	shared_env.ambient_light_energy = 0.3
	var rs1 := _lm_rig(TL, "", shared_env)
	var today1: Dictionary = (rs1.ctl.today as Dictionary).duplicate(true)
	rs1.ctl.set_mood("moody_b")
	rs1.ctl.set_phase("late_night", 0.0)
	var dimmed: bool = (rs1.env.environment as Environment).ambient_light_source == Environment.AMBIENT_SOURCE_COLOR
	var rs2 := _lm_rig(TL, "", shared_env)
	var today2: Dictionary = rs2.ctl.today
	var untouched: bool = shared_env.ambient_light_source == Environment.AMBIENT_SOURCE_BG and shared_env.ambient_light_color.is_equal_approx(Color(0.4, 0.5, 0.7)) \
		and is_equal_approx(shared_env.ambient_light_energy, 0.3) and is_equal_approx(shared_env.tonemap_exposure, 1.0)
	check(dimmed and today2 == today1 and today2.ambient_background == true and untouched and rs1.env.environment != shared_env and rs2.env.environment != shared_env,
		"a second controller after a dimmed phase (moody_b, late_night) snapshots the same today (Background ambient %s); the shared Environment is never written (untouched %s)" % [today2.get("ambient_background"), untouched])
	rs1.root.free()
	rs2.root.free()

	# the emit sites (one line each)
	var bed := FileAccess.get_file_as_string(BEDROOM_SCRIPT)
	var brief := FileAccess.get_file_as_string(BRIEFING_SCRIPT)
	check(_lm_in_func(bed, "open_bedroom", "day_phase_changed.emit(\"evening\")") and _lm_in_func(bed, "start_sleep_sequence", "day_phase_changed.emit(\"late_night\")")
		and _lm_in_func(bed, "_on_fade_complete", "day_phase_changed.emit(\"morning\")") and brief.count("day_phase_changed.emit(\"day\")") == 2,
		"the phase signal is sent where the loop already turns: the bedroom (evening), sleep (late_night), the new day (morning), the briefing's two ends (day)")

	# the candle, torch and window lights
	var board := _scene_nodes(NOTICE_SCENE_PATH)
	var lights := []
	for sc in [tav, board]:
		for k in sc:
			if sc[k].groups.has("tavern_candle") or sc[k].groups.has("tavern_window"):
				lights.append([k, sc[k]])
	var cn := lights.filter(func(e): return e[1].groups.has("tavern_candle"))
	var wn := lights.filter(func(e): return e[1].groups.has("tavern_window"))
	var lbad := []
	for e in lights:
		var pr: Dictionary = e[1].props
		if pr.get("visible", true) or pr.get("shadow_enabled", false) or float(pr.get("metadata/base_energy", 0.0)) <= 0.0 \
				or (e[1].groups.has("tavern_candle") and float(pr.get("omni_range", 9)) > 3.5):
			lbad.append(e[0])
	check(cn.size() >= 6 and wn.size() >= 4 and lbad.is_empty(),
		"%d candle/torch lights (board sconces, torches, the thin candle) and %d window lights: saved hidden, unshadowed, a base_energy, candles' range <= 3.5 m (wrong: %s)" % [cn.size(), wn.size(), lbad])
	var tln: Dictionary = tav.get(TAVERN_ENV + "TavernLighting", {})
	check(tln.get("props", {}).get("script") is GDScript and (tln.props.script as GDScript).resource_path == TAVERN_LIGHTING_SCRIPT, "MainTavern runs TavernLighting under its Environment")
	# the round bar's warm pool (no flame there: a light with no lamp, today off) and the window light cards (V11)
	var bpool: Dictionary = tav.get(TAVERN_ENV + "BarPool", {}).get("props", {})
	check(tav.get(TAVERN_ENV + "BarPool", {}).get("type") == "OmniLight3D" and bpool.get("visible", true) == false and not bpool.get("shadow_enabled", false)
		and float(TL.TODAY_VALUES.bar_pool_energy) == 0.0, "the bar's warm pool (BarPool): saved hidden, unshadowed; today 0")
	var cards := tav.keys().filter(func(k): return tav[k].groups.has("tavern_window_card"))
	var card_bad := []
	for k in cards:
		var pr: Dictionary = tav[k].props
		var cm = pr.get("surface_material_override/0")
		if pr.get("visible", true) or int(pr.get("cast_shadow", 1)) != 0 or not cm is StandardMaterial3D or float(pr.get("metadata/base_alpha", 0.0)) <= 0.0:
			card_bad.append(k)
		elif (cm as StandardMaterial3D).shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or (cm as StandardMaterial3D).roughness != 0.0 \
				or (cm as StandardMaterial3D).blend_mode != BaseMaterial3D.BLEND_MODE_ADD or (cm as StandardMaterial3D).render_priority < 1:
			card_bad.append(k)
	check(cards.size() >= 4 and card_bad.is_empty(), "%d window light cards (fog shafts rejected by the spike): saved hidden, additive, unshaded, roughness 0, render_priority >= 1, no shadow (wrong: %s)" % [cards.size(), card_bad])
	# LookDev follows the hall's mood (LM-12): "today" changes nothing; a moody mood moves its ambient, sun and fills
	var ld: Node = (load("res://scenes/dev/LookDev.tscn") as PackedScene).instantiate()
	root.add_child(ld)
	var ldenv: Environment = (ld.get_node("SubViewportContainer/SubViewport/WorldEnvironment") as WorldEnvironment).environment
	var ldsun := ld.get_node("SubViewportContainer/SubViewport/OutdoorsLight") as DirectionalLight3D
	var ldquad := ld.get_node("SubViewportContainer/SubViewport/Camera3D/EdgeQuad") as VisualInstance3D
	var ld_today: bool = TL.configured_mood() != "today" or (ldenv.ambient_light_source == Environment.AMBIENT_SOURCE_BG and ldsun.light_cull_mask == 4294967295 and ldquad.layers == 1)
	ld._follow_hall_mood("moody_a")
	var mav: Dictionary = TL.mood_params("moody_a")
	var ld_moody: bool = ldenv.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and ldenv.ambient_light_color.is_equal_approx(mav.ambient_color) \
		and ldsun.light_cull_mask == INK_LAYER_MASK and ldquad.layers == INK_LAYER_MASK and ldsun.light_energy == 1.5 \
		and is_equal_approx((ld.get_node("SubViewportContainer/SubViewport/CoolFill") as OmniLight3D).light_energy, float(mav.fill_energy))
	ld.free()
	ldenv.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	check(ld_today and ld_moody, "LookDev's tavern preset follows the hall's mood: today changes nothing; moody_a moves the ambient, the sun to an ink light (EdgeQuad on layer 20, energy kept), the cool fill")

	# the floor rune cue
	var cue_scene = load(RUNE_CUE_SCENE) if ResourceLoader.exists(RUNE_CUE_SCENE) else null
	var cue: Node3D = (cue_scene as PackedScene).instantiate() if cue_scene is PackedScene else null
	var ring: MeshInstance3D = cue.find_child("Ring", true, false) as MeshInstance3D if cue else null
	var rm = ring.get_surface_override_material(0) if ring and ring.mesh else null
	if ring and rm == null and ring.mesh:
		rm = ring.mesh.surface_get_material(0)
	var cue_ok: bool = cue != null and cue.get_script() is GDScript and (cue.get_script() as GDScript).resource_path == RUNE_CUE_SCRIPT and ring != null and not ring.visible
	cue_ok = cue_ok and rm is StandardMaterial3D and (rm as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and (rm as StandardMaterial3D).roughness == 0.0
	cue_ok = cue_ok and (rm as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and (rm as StandardMaterial3D).render_priority >= 1
	cue_ok = cue_ok and not (rm as StandardMaterial3D).no_depth_test and ring.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	check(cue_ok, "FloorRuneCue.tscn: hidden by default; unshaded, roughness 0 (no ink), transparent, render_priority >= 1, depth-tested, no shadow")
	if cue_ok:
		var standin := RefCounted.new()
		var sgd := GDScript.new()
		sgd.source_code = "extends RefCounted\nvar owner_zone = null\nfunc owns_e(z) -> bool:\n\treturn z != null and z == owner_zone\n"
		sgd.reload()
		standin.set_script(sgd)
		var z := Area3D.new()
		var w := Node3D.new()
		root.add_child(w)
		w.add_child(z)
		cue.zone = z
		cue.prompt_ui = standin
		w.add_child(cue)
		standin.owner_zone = z
		cue._process(1.0)
		var shown: bool = ring.visible
		var other := Area3D.new()
		w.add_child(other)
		standin.owner_zone = other
		cue._process(1.0)
		var hid: bool = not ring.visible
		check(shown and hid, "the cue shows while its zone owns E and hides when another takes E (shown %s, hidden %s)" % [shown, hid])
		w.free()
	elif cue:
		cue.free()
	var cues := tav.keys().filter(func(k): return tav[k].instance == RUNE_CUE_SCENE)
	check(cues.size() == 1 and str(tav[cues[0]].props.get("zone_path", "")).ends_with("FireplaceArea") and str(tav[cues[0]].props.get("hearth_path", "")).ends_with("Hearth"),
		"MainTavern has one floor rune cue, for the fireplace's zone at the hearth (%s)" % [cues])
	print("")


## Test 25's fixture rig: the hall's light nodes on the paths TavernLighting expects (SubViewport/TavernNavigation/...),
## a real Hearth and a real pillar, two candles and a window. Returns the nodes; free rig.root after.
## `shared_env`: the WorldEnvironment uses this Environment (a cached scene's sub-resource, shared by every
## instance) instead of a new one; `early_mood`: set_mood before _ready. The rig also has a candle and a window
## light saved without base_energy, and two window light cards sharing one material (review 2026-10-04).
func _lm_rig(TL: GDScript, early_phase := "", shared_env: Environment = null, early_mood := "") -> Dictionary:
	var r := Node3D.new()
	r.name = "LMRig"
	var navn := Node3D.new()
	navn.name = "TavernNavigation"
	r.add_child(navn)
	var envn := Node3D.new()
	envn.name = "Environment"
	navn.add_child(envn)
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	if shared_env:
		we.environment = shared_env
	else:
		we.environment = Environment.new()
		we.environment.ambient_light_color = Color(0.4, 0.5, 0.7)
		we.environment.ambient_light_energy = 0.3
	envn.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Outdoors Light"
	sun.transform = LM_SUN_XF
	sun.light_color = Color(1, 0.8, 0.5)
	sun.light_energy = 1.5
	envn.add_child(sun)
	var mk := func(n: String, e: float, parent: Node) -> OmniLight3D:
		var l := OmniLight3D.new()
		l.name = n
		l.light_energy = e
		parent.add_child(l)
		return l
	var fill: OmniLight3D = mk.call("TavernLight", 2.0, envn)
	var barl: OmniLight3D = mk.call("BarLight", 1.5, envn)
	var furn := Node3D.new()
	furn.name = "Furniture"
	navn.add_child(furn)
	var desk := Node3D.new()
	desk.name = "GuildDesk"
	furn.add_child(desk)
	var deskl: OmniLight3D = mk.call("DeskLight", 1.5, desk)
	var hearth: Node3D = (load(HEARTH_SCENE_PATH) as PackedScene).instantiate()
	hearth.name = "Hearth"
	hearth.preview_fuel = 80.0
	hearth.preview_stock = 0
	furn.add_child(hearth)
	var arch := Node3D.new()
	arch.name = "Architecture"
	navn.add_child(arch)
	var pillar: Node3D = (load(PILLAR_SCENE_PATH) as PackedScene).instantiate()
	pillar.name = "HourglassPillar"
	pillar.reveal_stage_override = 4
	arch.add_child(pillar)
	var candles := []
	for i in 2:
		var c: OmniLight3D = mk.call("Candle%d" % i, 0.8 + 0.2 * i, furn)
		c.visible = false
		c.set_meta("base_energy", c.light_energy)
		c.add_to_group("tavern_candle")
		candles.append(c)
	var win := SpotLight3D.new()
	win.name = "Window"
	win.visible = false
	win.light_energy = 3.0
	win.set_meta("base_energy", 3.0)
	win.add_to_group("tavern_window")
	arch.add_child(win)
	# saved without base_energy: the controller must keep the authored energy as the base
	var bare: OmniLight3D = mk.call("CandleBare", 0.9, furn)
	bare.visible = false
	bare.add_to_group("tavern_candle")
	var bare_win := SpotLight3D.new()
	bare_win.name = "WindowBare"
	bare_win.visible = false
	bare_win.light_energy = 2.0
	bare_win.add_to_group("tavern_window")
	arch.add_child(bare_win)
	# two light cards sharing one material, as MainTavern saves them (base_alpha 0.3 and 0.7)
	var card_mat := StandardMaterial3D.new()
	card_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	card_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	card_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var cards := []
	for i in 2:
		var q := MeshInstance3D.new()
		q.name = "Card%d" % i
		q.mesh = QuadMesh.new()
		q.set_surface_override_material(0, card_mat)
		q.set_meta("base_alpha", 0.3 + 0.4 * i)
		q.visible = false
		q.add_to_group("tavern_window_card")
		arch.add_child(q)
		cards.append(q)
	for pn in ["HearthProbe", "BarProbe"]:
		var p := ReflectionProbe.new()
		p.name = pn
		p.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		r.add_child(p)
	var ctl := Node.new()
	ctl.name = "TavernLighting"
	ctl.set_script(TL)
	ctl.dev_keys = false
	if early_phase != "":
		ctl.set_phase(early_phase, 0.0)
	if early_mood != "":
		ctl.set_mood(early_mood)
	envn.add_child(ctl)
	root.add_child(r)
	return {"root": r, "ctl": ctl, "env": we, "sun": sun, "fill": fill, "bar": barl, "desk": deskl, "hearth": hearth, "pillar": pillar,
		"candles": candles, "window": win, "bare": bare, "bare_win": bare_win, "cards": cards, "card_mat": card_mat}


## True when `needle` appears inside func `fname`'s body in a GDScript source (to the next top-level func).
static func _lm_in_func(src: String, fname: String, needle: String) -> bool:
	var at := src.find("func %s(" % fname)
	if at < 0:
		return false
	var end := src.find("\nfunc ", at + 1)
	var body := src.substr(at, (end - at) if end > 0 else -1)
	return body.contains(needle)
