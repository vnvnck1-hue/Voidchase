# Unity → Godot port tooling

- `GodotExport.cs` — Unity editor script (drop into `Assets/Editor/` of the Unity project, run in
  batch mode). Dumps both scenes (hierarchy, every component via SerializedObject, sprites, skinned
  sprite meshes + bind poses, particle modules, materials), samples every animation clip at 60 fps,
  and blits every referenced texture to PNG.
- `gen_godot.py` — converts the export (`unity_export/`) to `scenes/*.tscn` and `assets/textures/`.
- `unity_export/` — the export used for the current scenes (JSON + PNG).

```
"E:\6000.3.7f1\Editor\Unity.exe" -batchmode -projectPath E:\KSC_250420_2 -executeMethod GodotExport.Run -exportPath <dir> -logFile <dir>\unity.log -quit
python tools\port\gen_godot.py <dir>
"E:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
```

The exporter is temporary: remove `Assets/Editor/_GodotExportTmp` from the Unity project after use.
