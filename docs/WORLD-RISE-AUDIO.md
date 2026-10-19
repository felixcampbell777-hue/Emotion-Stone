# World Rise audio

World Rise audio is local presentation, independent of damage, rewards and saves. `main.gd` owns one `AudioDirector`; both native single-player hooks and replicated presentation events use the same catalog. Other modes retain shared menus but do not acquire a full content audio pass.

## Runtime ownership

- `game/scripts/audio/audio_director.gd`: playback, event identity, priority/concurrency, listening, pause, settings, captions, ambience/music and voice ducking.
- `game/scripts/audio/audio_surface_resolver.gd`: support-aware material classification. Raft/bridge/metal supports take precedence over water; water steps use actual movement, including Water Walkers.
- `game/content/world_rise/audio_events.json`: 138 semantic event definitions, selected recordings, gain/pitch/cooldown/range/priority and captions.
- `game/default_bus_layout.tres`: Master limiter; Game/Music/Ambience/SFX/UI/Voice; cave reverb and Underwater filtering. Voice capture remains a separate subsystem.
- `game/scripts/world_sound.gd`: native creature transitions, damage, actual-distance footfalls and world/economy helpers. Weapon/actor/inventory owners emit accepted action and result events.

World emitters belong to the actual gameplay `world_root` inside its own SubViewport, whose 3D listener is enabled. UI and menu preview views never become listeners. The director uses the gameplay camera's physics world for at most four occlusion queries per 0.12 seconds. Critical tells retain their full filter bandwidth.

Pools are bounded to 32 positional one-shots, 8 UI one-shots and 8 players for music/day/night/water crossfades. Lower-priority footsteps cannot displace combat cues. A single source has a four-voice limit except critical cues; per-source cooldowns prevent repeated state polling from creating storms. Stable action/target identities suppress duplicate confirmed events; stale generations and historical/restored events are rejected.

Player footfalls follow actual travel and rig gait phase, with movement-distance fallback. Blocked movement, jumps, action motion, map relocation and paused input do not generate walking steps. Swing sounds use actor-owned action phase markers; impact and parry sounds follow actual resolved contacts. No sound drives simulation.

Offline overlays freeze gameplay audio emission and active world one-shots; background beds continue quietly. Online overlays leave shared world sound running. Music and day/night beds follow World Rise's existing gameplay clock, including its daylight transition function. Floor/map replacement stops old world voices and invalidates event identities. Audio preferences live in `user://audio.cfg`, outside character saves.

Settings provide Master, Music, Effects, Ambience, UI and Voice volume (zero mutes), quiet listening, mono output, important-sound captions, background mute and quieter footsteps. Voice reports aggregate activity through `set_voice_activity(bool)` and uses the dedicated Voice bus; this ducks music/ambience without changing voice gain. No microphone capture is implemented by the director.

Call `await audio.shutdown_and_drain()` before orderly game/fixture shutdown and require its boolean result. It stops emission/playback, clears stream references, destroys permanently retired pool nodes, waits at least two process frames, and observes weak playback references until Godot’s audio fade/deferred deletion completes. Godot 4.5.1 positional players can retain a private pending playback when stopped before their next physics update; destroying retired nodes releases that reference. Its bounded timeout reports an error and failure; it does not suppress teardown warnings. `shutdown()` is the immediate stop/cache-clear operation; `_exit_tree` also calls it. Forced engine termination cannot promise a final mixer tick.

## Sources and style

Selected Kenney RPG Audio CC0 recordings supply movement/cloth/weapon/coin/menu foley. CaveboyTup's specific CC0 fantasy wolf cry supplies the principal wolf tell. Remaining impacts, wet/gel effects, exertions, spell cues, ambience and five short ambient compositions are original deterministic sound designs. They are intentionally stylized, including synthetic creature exertions; they are not field recordings or commissioned orchestral music.

Exact source URLs, original license notices, archive/runtime hashes and transformations are in `art/library/audio/` and `docs/ASSET-CREDITS.md`. Original recordings/compositions have a CC0 dedication and a reproducible generator, `tools/audio/create_original_audio.py`. `tools/audio/configure_audio_catalog.py` regenerates the catalog. Runtime audio is approximately 9.1 MB; unused donor source files remain outside runtime assets.

## Verification and current evidence

Run from the checkout root:

```
python3 tools/audio/verify_audio.py
./tools/platform.sh check-script scripts/audio/audio_checks.gd --timeout 40
./tools/platform.sh check-script scripts/audio/audio_gameplay_capture.gd --timeout 45
./tools/platform.sh check-script scripts/audio/audio_world_capture.gd --timeout 45
./tools/platform.sh check-script scripts/audio/audio_lifecycle_checks.gd --timeout 30
```

On Windows use the same `check-script` entries through `tools/platform.cmd`. The platform runner isolates userdata; never run fixtures against a player's save.

The static audit checks exact source licenses/hashes, file presence, non-silent unclipped original PCM, event gain/pitch bounds and catalog routing. The actual-main lifecycle fixture additionally checks active title playback, emitter destruction and mixer reference release; its optional `--floors` user argument repeats six authored floor transitions and checks unchanged emitter identities and bounded caches. The Godot fixture loads every selected stream and checks the actual SubViewport listener, deduplication, target-specific contacts, stale/historical rejection, distance culling, offline/online overlay policies, bounded voices/loops, priority stealing, shutdown and voice ducking. It records the real Godot mix rather than assembling an external imitation.

`output/verification/audio-current/` retains only current WAV/JSON evidence and compact MP3 previews. The gameplay capture exercises real Floor One movement/jump, greatsword/new weapons, damage/menus and authored wolf AI. The world capture exercises actual Floor Two giant leap/landing/split/greens, shallow-water movement and Vault formation/combat/death. High fixture HP, direct fixture damage and relocation are explicitly recorded in the capture scope; they are not gameplay balance changes. A service montage additionally checks the broader catalog.

Waveform peak/RMS and clipping measurements establish signal integrity; they do not establish human listening approval, speaker/headphone compatibility or an eight-client performance budget. Source hooks, event traces, and these captured scenarios are evidence of implemented coverage, not a claim that every possible combat interaction or every legacy campaign has been auditioned. Real Windows/macOS playback and microphone/Internet voice acceptance remain separate verification results.
