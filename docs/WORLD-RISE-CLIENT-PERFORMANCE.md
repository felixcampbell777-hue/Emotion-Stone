# Client performance evidence

October 19, 2026, working source candidate; not a client FPS or dedicated-host capacity certification.

Godot 4.5 already performs view-frustum culling. Forward+ also automatically instances eligible shared opaque meshes. World Rise already uses finite visibility ranges, crown HLOD, streamed scenery chunks, grass MultiMeshes, distant enemy sleeping and animation LOD. Adding a second camera-culling loop would duplicate engine work; camera visibility must never disable authority AI, damage, resources or retained loot. Outdoor occlusion would require measured static occluders and additional CPU work. References: [Godot 4.5 3D optimization](https://docs.godotengine.org/en/4.5/tutorials/performance/optimizing_3d_performance.html), [occlusion culling](https://docs.godotengine.org/en/4.5/tutorials/3d/occlusion_culling.html).

A disposable 1,024-geometry render-budget microbenchmark rejected two candidates. Guarding unchanged render setters raised median CPU dispatch from 616 to 769 microseconds (P95 645 to 821); squared distances alone showed no benefit (621 to 672 microseconds). All 12,288 tier/property comparisons passed. Both candidates were reverted. These short headless measurements show no demonstrated benefit; they do not measure rendered GPU frames. Compact local evidence is `output/verification/render-budget-optimization-current.json`.

The accepted change removes an unnecessary complete Actor snapshot from `wr_actor_pose.apply()`. The serializer and restore now share the same scalar/vector allowlists, while restore checks the actual scalar field types directly. Native bone, weapon, equipment, action-transition, gait, view and animation restores retain their full prior behavior. Unknown properties remain excluded, containers remain copied, and the prior float-to-integer acceptance is preserved. No rig, replay history, authority logic or wire payload was reduced.

A differential fixture used the actual Main Actor and previous implementation on Godot 4.5.1, macOS/Apple M3, with disposable user data. Forty-one checks passed across greatsword, spear, rapier and bow, including identical serialized payloads, full restore snapshots, unknown/wrong-type rejection and numeric conversion. Interleaved 140-sample timing pairs measured complete pose restoration:

| Weapon | Prior median | Candidate median | Prior P95 | Candidate P95 |
| --- | ---: | ---: | ---: | ---: |
| Greatsword | 199 µs | 140 µs | 228 µs | 155 µs |
| Spear | 215 µs | 151 µs | 871 µs | 487 µs |
| Rapier | 210 µs | 148 µs | 221 µs | 161 µs |
| Bow | 213 µs | 151 µs | 226 µs | 161 µs |

Median reduction is about 29–30%; the spear P95 contains host outliers. These are isolated CPU timings, not a promise of equivalent total frame improvement. Full canonical bridge checks passed **23,323**, with zero head-frame and steel endpoint error for every weapon. Production prediction checks passed **23**, retaining exact final correction, bounded history, collision and single ammunition spending.

Current local results are `output/verification/actor-pose-performance-current.json`, `wr_actor_bridge_checks-pose-optimization-current.log` and `wr_prediction_checks-pose-optimization-current.log`. The reusable differential fixture is `game/scripts/network/wr_actor_pose_performance_checks.gd`; supply the prior pose script as temporary `--legacy=res://...` input and use the normal isolated-userdata helper. Remove that temporary source after the run. Benchmark source does not belong in normal gameplay startup.
