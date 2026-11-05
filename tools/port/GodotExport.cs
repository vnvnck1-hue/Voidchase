// Temporary exporter used to port scenes to Godot. Safe to delete.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;
using UnityEngine.U2D;
using Unity.Collections;
using UnityEditor.Animations;

public static class GodotExport
{
    static string outDir;
    static HashSet<Texture2D> textures = new HashSet<Texture2D>();
    static Dictionary<int, string> texNames = new Dictionary<int, string>();
    static HashSet<Material> materials = new HashSet<Material>();
    static HashSet<AnimationClip> clips = new HashSet<AnimationClip>();
    static StringBuilder log = new StringBuilder();

    public static void Run()
    {
        try
        {
            var args = Environment.GetCommandLineArgs();
            for (int i = 0; i < args.Length; i++) if (args[i] == "-exportPath" && i + 1 < args.Length) outDir = args[i + 1];
            if (string.IsNullOrEmpty(outDir)) outDir = "E:/godot_export_tmp";
            Directory.CreateDirectory(outDir);
            string[] scenes = { "Assets/KSC_251206/Scenes/Touch_Game_demo.unity", "Assets/KSC_251206/Scenes/Touch_Game_demo_anim.unity" };
            foreach (var s in scenes) ExportScene(s);
            ExportMaterials();
            ExportTextures();
            File.WriteAllText(Path.Combine(outDir, "export_log.txt"), log.ToString());
            File.WriteAllText(Path.Combine(outDir, "DONE.txt"), "ok");
        }
        catch (Exception e)
        {
            log.AppendLine("FATAL: " + e);
            File.WriteAllText(Path.Combine(outDir ?? "E:/godot_export_tmp", "export_log.txt"), log.ToString());
            File.WriteAllText(Path.Combine(outDir ?? "E:/godot_export_tmp", "FAILED.txt"), e.ToString());
        }
        if (Application.isBatchMode) EditorApplication.Exit(0);
    }

    // ---------------- scene ----------------
    static void ExportScene(string scenePath)
    {
        var scene = EditorSceneManager.OpenScene(scenePath, OpenSceneMode.Single);
        log.AppendLine("Opened " + scenePath);
        var root = new Dictionary<string, object>();
        root["scene"] = scenePath;
        var roots = new List<object>();
        foreach (var go in scene.GetRootGameObjects()) roots.Add(DumpGO(go));
        root["roots"] = roots;
        root["colorSpace"] = PlayerSettings.colorSpace.ToString();

        // animations: sample after hierarchy dump (sampling mutates the scene)
        var anims = new List<object>();
        foreach (var animator in UnityEngine.Object.FindObjectsByType<Animator>(FindObjectsInactive.Include, FindObjectsSortMode.None))
        {
            var ad = new Dictionary<string, object>();
            ad["animatorPath"] = GOPath(animator.gameObject);
            var ctrl = animator.runtimeAnimatorController as AnimatorController;
            ad["controller"] = ctrl ? AssetDatabase.GetAssetPath(ctrl) : null;
            var clipList = new List<object>();
            if (ctrl != null)
            {
                foreach (var layer in ctrl.layers)
                {
                    var sm = layer.stateMachine;
                    foreach (var st in sm.states)
                    {
                        var clip = st.state.motion as AnimationClip;
                        var sd = new Dictionary<string, object>();
                        sd["state"] = st.state.name;
                        sd["isDefault"] = sm.defaultState == st.state;
                        sd["speed"] = st.state.speed;
                        sd["clip"] = clip ? AssetDatabase.GetAssetPath(clip) : null;
                        sd["clipName"] = clip ? clip.name : null;
                        clipList.Add(sd);
                        if (clip) clips.Add(clip);
                    }
                }
            }
            ad["states"] = clipList;
            anims.Add(ad);
        }
        root["animators"] = anims;

        // Sample every clip against each animator whose hierarchy it binds to
        var sampled = new List<object>();
        foreach (var animator in UnityEngine.Object.FindObjectsByType<Animator>(FindObjectsInactive.Include, FindObjectsSortMode.None))
        {
            var ctrl = animator.runtimeAnimatorController as AnimatorController;
            if (ctrl == null) continue;
            foreach (var clip in ctrl.animationClips)
            {
                try { sampled.Add(SampleClip(animator.gameObject, clip)); }
                catch (Exception e) { log.AppendLine("sample fail " + clip.name + ": " + e); }
            }
        }
        // timeline-bound clips (same clips as controllers in this project) are covered above.
        root["sampledClips"] = sampled;

        var json = new StringBuilder();
        Json.Write(json, root, 0);
        File.WriteAllText(Path.Combine(outDir, Path.GetFileNameWithoutExtension(scenePath) + ".json"), json.ToString());
        log.AppendLine("Wrote scene json " + scenePath);
        // reopen to discard sampling changes
        EditorSceneManager.OpenScene(scenePath, OpenSceneMode.Single);
    }

    static string GOPath(GameObject go)
    {
        if (go == null) return null;
        var sb = go.name;
        var t = go.transform.parent;
        while (t != null) { sb = t.name + "/" + sb; t = t.parent; }
        return sb;
    }

    static Dictionary<string, object> DumpGO(GameObject go)
    {
        var d = new Dictionary<string, object>();
        d["name"] = go.name;
        d["path"] = GOPath(go);
        d["active"] = go.activeSelf;
        d["activeInHierarchy"] = go.activeInHierarchy;
        d["layer"] = go.layer;
        d["tag"] = go.tag;
        d["instanceID"] = go.GetInstanceID();
        var t = go.transform;
        d["localPosition"] = V3(t.localPosition);
        d["localRotation"] = Q(t.localRotation);
        d["localEuler"] = V3(t.localEulerAngles);
        d["localScale"] = V3(t.localScale);
        d["worldPosition"] = V3(t.position);
        d["worldRotation"] = Q(t.rotation);
        d["worldEuler"] = V3(t.eulerAngles);
        d["lossyScale"] = V3(t.lossyScale);
        var rt = t as RectTransform;
        if (rt != null)
        {
            d["rect"] = new Dictionary<string, object> { { "x", rt.rect.x }, { "y", rt.rect.y }, { "w", rt.rect.width }, { "h", rt.rect.height } };
            d["anchorMin"] = V2(rt.anchorMin); d["anchorMax"] = V2(rt.anchorMax); d["anchoredPosition"] = V2(rt.anchoredPosition); d["sizeDelta"] = V2(rt.sizeDelta); d["pivot"] = V2(rt.pivot);
        }
        var comps = new List<object>();
        foreach (var c in go.GetComponents<Component>())
        {
            if (c == null) { comps.Add(new Dictionary<string, object> { { "type", "MISSING" } }); continue; }
            if (c is Transform) continue;
            var cd = new Dictionary<string, object>();
            cd["type"] = c.GetType().FullName;
            cd["instanceID"] = c.GetInstanceID();
            var beh = c as Behaviour; if (beh != null) cd["enabled"] = beh.enabled;
            var rend = c as Renderer; if (rend != null) cd["enabled"] = rend.enabled;
            try { cd["props"] = DumpSerialized(c); } catch (Exception e) { cd["propsError"] = e.Message; }
            try { AddExtra(c, cd); } catch (Exception e) { cd["extraError"] = e.ToString(); log.AppendLine("extra fail " + c.GetType().Name + " on " + GOPath(go) + ": " + e); }
            comps.Add(cd);
        }
        d["components"] = comps;
        var children = new List<object>();
        for (int i = 0; i < t.childCount; i++) children.Add(DumpGO(t.GetChild(i).gameObject));
        d["children"] = children;
        return d;
    }

    static void AddExtra(Component c, Dictionary<string, object> cd)
    {
        var sr = c as SpriteRenderer;
        if (sr != null)
        {
            cd["sprite"] = SpriteInfo(sr.sprite);
            cd["sharedMaterial"] = MatRef(sr.sharedMaterial);
            cd["sortingOrder"] = sr.sortingOrder; cd["sortingLayerName"] = sr.sortingLayerName; cd["sortingLayerID"] = sr.sortingLayerID;
            cd["color"] = Col(sr.color); cd["flipX"] = sr.flipX; cd["flipY"] = sr.flipY; cd["drawMode"] = sr.drawMode.ToString(); cd["size"] = V2(sr.size);
            cd["bounds"] = Bounds(sr.bounds); cd["localBounds"] = Bounds(sr.localBounds);
            // skinned mesh data
            var skin = c.GetComponent("UnityEngine.U2D.Animation.SpriteSkin");
            if (skin != null && sr.sprite != null) cd["skinMesh"] = SkinMesh(sr.sprite, skin, sr);
        }
        var img = c as UnityEngine.UI.Image;
        if (img != null)
        {
            cd["sprite"] = SpriteInfo(img.sprite);
            cd["color"] = Col(img.color); cd["imageType"] = img.type.ToString(); cd["fillMethod"] = img.fillMethod.ToString(); cd["fillAmount"] = img.fillAmount; cd["fillOrigin"] = img.fillOrigin; cd["fillClockwise"] = img.fillClockwise; cd["preserveAspect"] = img.preserveAspect;
            cd["material"] = MatRef(img.material);
        }
        var cam = c as Camera;
        if (cam != null)
        {
            cd["orthographic"] = cam.orthographic; cd["orthographicSize"] = cam.orthographicSize; cd["backgroundColor"] = Col(cam.backgroundColor); cd["clearFlags"] = cam.clearFlags.ToString(); cd["nearClip"] = cam.nearClipPlane; cd["farClip"] = cam.farClipPlane; cd["aspect"] = cam.aspect; cd["pixelRect"] = new Dictionary<string, object> { { "w", cam.pixelWidth }, { "h", cam.pixelHeight } };
        }
        var psr = c as ParticleSystemRenderer;
        if (psr != null)
        {
            var mats = new List<object>(); foreach (var m in psr.sharedMaterials) mats.Add(MatRef(m)); cd["materials"] = mats;
            cd["trailMaterial"] = MatRef(psr.trailMaterial);
            cd["renderMode"] = psr.renderMode.ToString(); cd["sortMode"] = psr.sortMode.ToString(); cd["alignment"] = psr.alignment.ToString();
            cd["sortingOrder"] = psr.sortingOrder; cd["sortingFudge"] = psr.sortingFudge; cd["lengthScale"] = psr.lengthScale; cd["velocityScale"] = psr.velocityScale; cd["pivot"] = V3(psr.pivot); cd["minParticleSize"] = psr.minParticleSize; cd["maxParticleSize"] = psr.maxParticleSize;
        }
        var ps = c as ParticleSystem;
        if (ps != null)
        {
            cd["main"] = new Dictionary<string, object> {
                {"duration", ps.main.duration}, {"loop", ps.main.loop}, {"prewarm", ps.main.prewarm}, {"startDelay", MM(ps.main.startDelay)}, {"startLifetime", MM(ps.main.startLifetime)}, {"startSpeed", MM(ps.main.startSpeed)},
                {"startSize3D", ps.main.startSize3D}, {"startSize", MM(ps.main.startSize)}, {"startSizeX", MM(ps.main.startSizeX)}, {"startSizeY", MM(ps.main.startSizeY)}, {"startRotation3D", ps.main.startRotation3D}, {"startRotation", MM(ps.main.startRotation)}, {"startRotationZ", MM(ps.main.startRotationZ)}, {"flipRotation", ps.main.flipRotation},
                {"startColor", MMG(ps.main.startColor)}, {"gravityModifier", MM(ps.main.gravityModifier)}, {"simulationSpace", ps.main.simulationSpace.ToString()}, {"simulationSpeed", ps.main.simulationSpeed}, {"scalingMode", ps.main.scalingMode.ToString()}, {"playOnAwake", ps.main.playOnAwake}, {"maxParticles", ps.main.maxParticles}, {"emitterVelocityMode", ps.main.emitterVelocityMode.ToString()}, {"stopAction", ps.main.stopAction.ToString()}, {"useUnscaledTime", ps.main.useUnscaledTime}
            };
            var em = ps.emission;
            var bursts = new List<object>();
            var ba = new ParticleSystem.Burst[em.burstCount]; em.GetBursts(ba);
            foreach (var b in ba) bursts.Add(new Dictionary<string, object> { { "time", b.time }, { "count", MM(b.count) }, { "cycleCount", b.cycleCount }, { "repeatInterval", b.repeatInterval }, { "probability", b.probability } });
            cd["emission"] = new Dictionary<string, object> { { "enabled", em.enabled }, { "rateOverTime", MM(em.rateOverTime) }, { "rateOverDistance", MM(em.rateOverDistance) }, { "bursts", bursts } };
            var sh = ps.shape;
            cd["shape"] = new Dictionary<string, object> { { "enabled", sh.enabled }, { "shapeType", sh.shapeType.ToString() }, { "radius", sh.radius }, { "radiusThickness", sh.radiusThickness }, { "angle", sh.angle }, { "length", sh.length }, { "arc", sh.arc }, { "arcMode", sh.arcMode.ToString() }, { "arcSpread", sh.arcSpread }, { "radiusMode", sh.radiusMode.ToString() }, { "position", V3(sh.position) }, { "rotation", V3(sh.rotation) }, { "scale", V3(sh.scale) }, { "boxThickness", V3(sh.boxThickness) }, { "alignToDirection", sh.alignToDirection }, { "randomDirectionAmount", sh.randomDirectionAmount }, { "sphericalDirectionAmount", sh.sphericalDirectionAmount }, { "randomPositionAmount", sh.randomPositionAmount }, { "donutRadius", sh.donutRadius } };
            var vol = ps.velocityOverLifetime;
            cd["velocityOverLifetime"] = new Dictionary<string, object> { { "enabled", vol.enabled }, { "x", MM(vol.x) }, { "y", MM(vol.y) }, { "z", MM(vol.z) }, { "space", vol.space.ToString() }, { "orbitalX", MM(vol.orbitalX) }, { "orbitalY", MM(vol.orbitalY) }, { "orbitalZ", MM(vol.orbitalZ) }, { "radial", MM(vol.radial) }, { "speedModifier", MM(vol.speedModifier) } };
            var lim = ps.limitVelocityOverLifetime;
            cd["limitVelocityOverLifetime"] = new Dictionary<string, object> { { "enabled", lim.enabled }, { "limit", MM(lim.limit) }, { "dampen", lim.dampen }, { "separateAxes", lim.separateAxes }, { "drag", MM(lim.drag) }, { "multiplyDragByParticleSize", lim.multiplyDragByParticleSize }, { "multiplyDragByParticleVelocity", lim.multiplyDragByParticleVelocity } };
            var fol = ps.forceOverLifetime;
            cd["forceOverLifetime"] = new Dictionary<string, object> { { "enabled", fol.enabled }, { "x", MM(fol.x) }, { "y", MM(fol.y) }, { "z", MM(fol.z) }, { "space", fol.space.ToString() } };
            var col = ps.colorOverLifetime;
            cd["colorOverLifetime"] = new Dictionary<string, object> { { "enabled", col.enabled }, { "color", MMG(col.color) } };
            var cbs = ps.colorBySpeed;
            cd["colorBySpeed"] = new Dictionary<string, object> { { "enabled", cbs.enabled }, { "color", MMG(cbs.color) }, { "range", V2(cbs.range) } };
            var sol = ps.sizeOverLifetime;
            cd["sizeOverLifetime"] = new Dictionary<string, object> { { "enabled", sol.enabled }, { "separateAxes", sol.separateAxes }, { "size", MM(sol.size) }, { "x", MM(sol.x) }, { "y", MM(sol.y) } };
            var sbs = ps.sizeBySpeed;
            cd["sizeBySpeed"] = new Dictionary<string, object> { { "enabled", sbs.enabled }, { "size", MM(sbs.size) }, { "range", V2(sbs.range) } };
            var rol = ps.rotationOverLifetime;
            cd["rotationOverLifetime"] = new Dictionary<string, object> { { "enabled", rol.enabled }, { "separateAxes", rol.separateAxes }, { "z", MM(rol.z) }, { "x", MM(rol.x) }, { "y", MM(rol.y) } };
            var rbs = ps.rotationBySpeed;
            cd["rotationBySpeed"] = new Dictionary<string, object> { { "enabled", rbs.enabled }, { "z", MM(rbs.z) }, { "range", V2(rbs.range) } };
            var noise = ps.noise;
            cd["noise"] = new Dictionary<string, object> { { "enabled", noise.enabled }, { "strength", MM(noise.strength) }, { "separateAxes", noise.separateAxes }, { "strengthX", MM(noise.strengthX) }, { "strengthY", MM(noise.strengthY) }, { "frequency", noise.frequency }, { "scrollSpeed", MM(noise.scrollSpeed) }, { "damping", noise.damping }, { "octaveCount", noise.octaveCount }, { "octaveMultiplier", noise.octaveMultiplier }, { "octaveScale", noise.octaveScale }, { "quality", noise.quality.ToString() }, { "positionAmount", MM(noise.positionAmount) }, { "rotationAmount", MM(noise.rotationAmount) }, { "sizeAmount", MM(noise.sizeAmount) } };
            var tsa = ps.textureSheetAnimation;
            cd["textureSheetAnimation"] = new Dictionary<string, object> { { "enabled", tsa.enabled }, { "mode", tsa.mode.ToString() }, { "numTilesX", tsa.numTilesX }, { "numTilesY", tsa.numTilesY }, { "animation", tsa.animation.ToString() }, { "frameOverTime", MM(tsa.frameOverTime) }, { "startFrame", MM(tsa.startFrame) }, { "cycleCount", tsa.cycleCount }, { "rowMode", tsa.rowMode.ToString() }, { "rowIndex", tsa.rowIndex }, { "timeMode", tsa.timeMode.ToString() }, { "fps", tsa.fps }, { "spriteCount", tsa.spriteCount } };
            var tr = ps.trails;
            cd["trails"] = new Dictionary<string, object> { { "enabled", tr.enabled }, { "mode", tr.mode.ToString() }, { "ratio", tr.ratio }, { "lifetime", MM(tr.lifetime) }, { "minVertexDistance", tr.minVertexDistance }, { "worldSpace", tr.worldSpace }, { "dieWithParticles", tr.dieWithParticles }, { "sizeAffectsWidth", tr.sizeAffectsWidth }, { "sizeAffectsLifetime", tr.sizeAffectsLifetime }, { "inheritParticleColor", tr.inheritParticleColor }, { "colorOverLifetime", MMG(tr.colorOverLifetime) }, { "widthOverTrail", MM(tr.widthOverTrail) }, { "colorOverTrail", MMG(tr.colorOverTrail) }, { "generateLightingData", tr.generateLightingData }, { "textureMode", tr.textureMode.ToString() }, { "ribbonCount", tr.ribbonCount }, { "shadowBias", tr.shadowBias } };
            var inh = ps.inheritVelocity;
            cd["inheritVelocity"] = new Dictionary<string, object> { { "enabled", inh.enabled }, { "mode", inh.mode.ToString() }, { "curve", MM(inh.curve) } };
            var sub = ps.subEmitters;
            cd["subEmittersEnabled"] = sub.enabled; cd["subEmittersCount"] = sub.subEmittersCount;
            cd["lightsEnabled"] = ps.lights.enabled; cd["collisionEnabled"] = ps.collision.enabled; cd["triggerEnabled"] = ps.trigger.enabled; cd["externalForcesEnabled"] = ps.externalForces.enabled; cd["customDataEnabled"] = ps.customData.enabled; cd["lifetimeByEmitterSpeedEnabled"] = ps.lifetimeByEmitterSpeed.enabled;
        }
        var anim = c as Animator;
        if (anim != null)
        {
            cd["controller"] = anim.runtimeAnimatorController ? AssetDatabase.GetAssetPath(anim.runtimeAnimatorController) : null;
        }
        var mr = c as MeshRenderer;
        if (mr != null) { var mats = new List<object>(); foreach (var m in mr.sharedMaterials) mats.Add(MatRef(m)); cd["materials"] = mats; }
        var mf = c as MeshFilter;
        if (mf != null && mf.sharedMesh != null) { cd["mesh"] = mf.sharedMesh.name; cd["meshBounds"] = Bounds(mf.sharedMesh.bounds); }
        var bc = c as BoxCollider2D; if (bc != null) { cd["offset"] = V2(bc.offset); cd["size"] = V2(bc.size); cd["worldBounds"] = Bounds(bc.bounds); }
    }

    static object SkinMesh(Sprite sprite, Component skin, SpriteRenderer sr)
    {
        var d = new Dictionary<string, object>();
        int vcount = sprite.GetVertexCount();
        d["vertexCount"] = vcount;
        { var pos = sprite.GetVertexAttribute<Vector3>(VertexAttribute.Position); var vl = new List<object>(); for (int i = 0; i < pos.Length; i++) vl.Add(V3(pos[i])); d["vertices"] = vl; }
        if (sprite.HasVertexAttribute(VertexAttribute.TexCoord0)) { var uv = sprite.GetVertexAttribute<Vector2>(VertexAttribute.TexCoord0); var ul = new List<object>(); for (int i = 0; i < uv.Length; i++) ul.Add(V2(uv[i])); d["uv"] = ul; }
        { var idx = sprite.GetIndices(); var il = new List<object>(); for (int i = 0; i < idx.Length; i++) il.Add((int)idx[i]); d["indices"] = il; }
        if (sprite.HasVertexAttribute(VertexAttribute.BlendWeight))
        {
            var bw = sprite.GetVertexAttribute<BoneWeight>(VertexAttribute.BlendWeight);
            var wl = new List<object>();
            for (int k = 0; k < bw.Length; k++) { var w = bw[k]; wl.Add(new Dictionary<string, object> { { "i0", w.boneIndex0 }, { "w0", w.weight0 }, { "i1", w.boneIndex1 }, { "w1", w.weight1 }, { "i2", w.boneIndex2 }, { "w2", w.weight2 }, { "i3", w.boneIndex3 }, { "w3", w.weight3 } }); }
            d["boneWeights"] = wl;
        }
        try {
            var sbones = sprite.GetBones();
            var sbl = new List<object>();
            foreach (var b in sbones) sbl.Add(new Dictionary<string, object> { { "name", b.name }, { "guid", b.guid }, { "position", V3(b.position) }, { "rotation", Q(b.rotation) }, { "length", b.length }, { "parentId", b.parentId } });
            d["spriteBones"] = sbl;
        } catch (Exception e) { d["spriteBonesError"] = e.Message; }
        { var bp = sprite.GetBindPoses(); var bl = new List<object>(); for (int i = 0; i < bp.Length; i++) bl.Add(Mat(bp[i])); d["bindPoses"] = bl; }
        // bone transforms from skin via reflection (public property boneTransforms, rootBone)
        var tp = skin.GetType().GetProperty("boneTransforms");
        var bones = tp != null ? tp.GetValue(skin) as Transform[] : null;
        var btl = new List<object>();
        if (bones != null) foreach (var b in bones) btl.Add(b ? GOPath(b.gameObject) : null);
        d["boneTransforms"] = btl;
        var rp = skin.GetType().GetProperty("rootBone");
        var rb = rp != null ? rp.GetValue(skin) as Transform : null;
        d["rootBone"] = rb ? GOPath(rb.gameObject) : null;
        // bone world transforms now (for verification)
        var bw2 = new List<object>();
        if (bones != null) foreach (var b in bones) bw2.Add(b ? (object)Mat(sr.transform.worldToLocalMatrix * b.localToWorldMatrix) : null);
        d["boneToSpriteNow"] = bw2;
        return d;
    }

    static object SpriteInfo(Sprite s)
    {
        if (s == null) return null;
        var d = new Dictionary<string, object>();
        d["name"] = s.name;
        d["assetPath"] = AssetDatabase.GetAssetPath(s);
        d["texture"] = TexRef(s.texture);
        d["rect"] = Rect(s.rect); d["textureRect"] = Rect(s.textureRect); d["textureRectOffset"] = V2(s.textureRectOffset);
        d["pivot"] = V2(s.pivot); d["pixelsPerUnit"] = s.pixelsPerUnit; d["border"] = V4(s.border); d["bounds"] = Bounds(s.bounds); d["packed"] = s.packed;
        d["packingMode"] = s.packingMode.ToString();
        return d;
    }

    static object TexRef(Texture tex)
    {
        if (tex == null) return null;
        var t2 = tex as Texture2D;
        string name = SafeTexName(tex);
        if (t2 != null && !textures.Contains(t2)) { textures.Add(t2); }
        return new Dictionary<string, object> { { "name", tex.name }, { "file", name + ".png" }, { "assetPath", AssetDatabase.GetAssetPath(tex) }, { "width", tex.width }, { "height", tex.height }, { "filterMode", tex.filterMode.ToString() }, { "wrapMode", tex.wrapMode.ToString() }, { "instanceID", tex.GetInstanceID() } };
    }
    static string SafeTexName(Texture tex)
    {
        if (texNames.TryGetValue(tex.GetInstanceID(), out var n)) return n;
        var ap = AssetDatabase.GetAssetPath(tex);
        var baseName = string.IsNullOrEmpty(ap) ? tex.name : Path.GetFileNameWithoutExtension(ap) + (AssetDatabase.IsMainAsset(tex) ? "" : "__" + tex.name);
        var sb = new StringBuilder();
        foreach (var ch in baseName) sb.Append(char.IsLetterOrDigit(ch) || ch == '_' || ch == '-' ? ch : '_');
        var nm = sb.ToString(); var nm0 = nm; int k = 1;
        while (texNames.ContainsValue(nm)) nm = nm0 + "_" + (k++);
        texNames[tex.GetInstanceID()] = nm; return nm;
    }

    static object MatRef(Material m)
    {
        if (m == null) return null;
        materials.Add(m);
        return new Dictionary<string, object> { { "name", m.name }, { "assetPath", AssetDatabase.GetAssetPath(m) }, { "shader", m.shader ? m.shader.name : null }, { "instanceID", m.GetInstanceID() } };
    }

    static void ExportMaterials()
    {
        var list = new List<object>();
        foreach (var m in materials)
        {
            var d = new Dictionary<string, object>();
            d["name"] = m.name; d["assetPath"] = AssetDatabase.GetAssetPath(m); d["instanceID"] = m.GetInstanceID();
            d["shader"] = m.shader ? m.shader.name : null; d["renderQueue"] = m.renderQueue;
            var props = new Dictionary<string, object>();
            if (m.shader != null)
            {
                int n = ShaderUtil.GetPropertyCount(m.shader);
                for (int i = 0; i < n; i++)
                {
                    var pn = ShaderUtil.GetPropertyName(m.shader, i); var pt = ShaderUtil.GetPropertyType(m.shader, i);
                    switch (pt)
                    {
                        case ShaderUtil.ShaderPropertyType.Color: props[pn] = Col(m.GetColor(pn)); break;
                        case ShaderUtil.ShaderPropertyType.Float: case ShaderUtil.ShaderPropertyType.Range: props[pn] = m.GetFloat(pn); break;
                        case ShaderUtil.ShaderPropertyType.Vector: props[pn] = V4(m.GetVector(pn)); break;
                        case ShaderUtil.ShaderPropertyType.TexEnv: props[pn] = TexRef(m.GetTexture(pn)); break;
                        case ShaderUtil.ShaderPropertyType.Int: props[pn] = m.GetInt(pn); break;
                    }
                }
            }
            d["props"] = props;
            d["keywords"] = new List<object>(m.shaderKeywords);
            list.Add(d);
        }
        var json = new StringBuilder(); Json.Write(json, list, 0);
        File.WriteAllText(Path.Combine(outDir, "materials.json"), json.ToString());
    }

    static void ExportTextures()
    {
        var texDir = Path.Combine(outDir, "textures"); Directory.CreateDirectory(texDir);
        var index = new List<object>();
        foreach (var tex in textures)
        {
            var name = SafeTexName(tex);
            var entry = new Dictionary<string, object> { { "file", name + ".png" }, { "assetPath", AssetDatabase.GetAssetPath(tex) }, { "name", tex.name }, { "width", tex.width }, { "height", tex.height }, { "format", tex.format.ToString() }, { "filterMode", tex.filterMode.ToString() }, { "wrapMode", tex.wrapMode.ToString() }, { "mipmapCount", tex.mipmapCount } };
            try
            {
                var rt = RenderTexture.GetTemporary(tex.width, tex.height, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
                var prev = RenderTexture.active;
                Graphics.Blit(tex, rt);
                RenderTexture.active = rt;
                var read = new Texture2D(tex.width, tex.height, TextureFormat.RGBA32, false, false);
                read.ReadPixels(new UnityEngine.Rect(0, 0, tex.width, tex.height), 0, 0);
                read.Apply();
                RenderTexture.active = prev;
                RenderTexture.ReleaseTemporary(rt);
                File.WriteAllBytes(Path.Combine(texDir, name + ".png"), read.EncodeToPNG());
                UnityEngine.Object.DestroyImmediate(read);
                entry["ok"] = true;
            }
            catch (Exception e) { entry["ok"] = false; entry["error"] = e.Message; log.AppendLine("tex fail " + tex.name + ": " + e.Message); }
            index.Add(entry);
        }
        var json = new StringBuilder(); Json.Write(json, index, 0);
        File.WriteAllText(Path.Combine(outDir, "textures.json"), json.ToString());
    }

    // ---------------- animation sampling ----------------
    static object SampleClip(GameObject root, AnimationClip clip)
    {
        var d = new Dictionary<string, object>();
        d["clip"] = AssetDatabase.GetAssetPath(clip); d["clipName"] = clip.name; d["root"] = GOPath(root);
        d["length"] = clip.length; d["frameRate"] = clip.frameRate; d["isLooping"] = clip.isLooping; d["wrapMode"] = clip.wrapMode.ToString();
        var settings = AnimationUtility.GetAnimationClipSettings(clip);
        d["loopTime"] = settings.loopTime; d["loopBlend"] = settings.loopBlend; d["cycleOffset"] = settings.cycleOffset;
        var bindings = AnimationUtility.GetCurveBindings(clip);
        var bl = new List<object>();
        var curvesKeys = new List<object>();
        foreach (var b in bindings)
        {
            var bd = new Dictionary<string, object> { { "path", b.path }, { "type", b.type != null ? b.type.FullName : null }, { "property", b.propertyName }, { "isPPtr", b.isPPtrCurve } };
            var resolved = AnimationUtility.GetAnimatedObject(root, b);
            bd["resolved"] = resolved != null;
            bl.Add(bd);
            var curve = AnimationUtility.GetEditorCurve(clip, b);
            var keys = new List<object>();
            if (curve != null) foreach (var k in curve.keys) keys.Add(new Dictionary<string, object> { { "t", k.time }, { "v", k.value }, { "in", k.inTangent }, { "out", k.outTangent }, { "inW", k.inWeight }, { "outW", k.outWeight }, { "wm", k.weightedMode.ToString() }, { "tm", AnimationUtility.GetKeyLeftTangentMode(curve, Array.IndexOf(curve.keys, k)).ToString() + "/" + AnimationUtility.GetKeyRightTangentMode(curve, Array.IndexOf(curve.keys, k)).ToString() } });
            curvesKeys.Add(keys);
        }
        d["bindings"] = bl; d["keys"] = curvesKeys;
        var objBindings = AnimationUtility.GetObjectReferenceCurveBindings(clip);
        var ol = new List<object>();
        foreach (var b in objBindings)
        {
            var frames = new List<object>();
            foreach (var kf in AnimationUtility.GetObjectReferenceCurve(clip, b)) frames.Add(new Dictionary<string, object> { { "t", kf.time }, { "value", kf.value ? kf.value.name : null }, { "assetPath", kf.value ? AssetDatabase.GetAssetPath(kf.value) : null }, { "sprite", kf.value as Sprite ? SpriteInfo(kf.value as Sprite) : null } });
            ol.Add(new Dictionary<string, object> { { "path", b.path }, { "type", b.type != null ? b.type.FullName : null }, { "property", b.propertyName }, { "frames", frames } });
        }
        d["objectBindings"] = ol;
        // sample
        int fps = 60; int frames_n = Mathf.RoundToInt(clip.length * fps) + 1;
        var samples = new List<object>();
        var times = new List<object>();
        for (int f = 0; f < frames_n; f++)
        {
            float t = Mathf.Min(f / (float)fps, clip.length);
            clip.SampleAnimation(root, t);
            times.Add(t);
            var row = new List<object>();
            foreach (var b in bindings)
            {
                float v; if (AnimationUtility.GetFloatValue(root, b, out v)) row.Add(v); else row.Add(null);
            }
            samples.Add(row);
        }
        d["sampleTimes"] = times; d["samples"] = samples;
        return d;
    }

    // ---------------- generic serialized dump ----------------
    static object DumpSerialized(UnityEngine.Object o)
    {
        var so = new SerializedObject(o);
        var it = so.GetIterator();
        var d = new Dictionary<string, object>();
        if (it.NextVisible(true))
        {
            do
            {
                if (it.name == "m_Script" || it.name == "m_ObjectHideFlags" || it.name == "m_CorrespondingSourceObject" || it.name == "m_PrefabInstance" || it.name == "m_PrefabAsset" || it.name == "m_GameObject") continue;
                d[it.name] = DumpProp(it, 0);
            } while (it.NextVisible(false));
        }
        return d;
    }

    static object DumpProp(SerializedProperty p, int depth)
    {
        if (depth > 12) return "<depth>";
        if (p.isArray && p.propertyType != SerializedPropertyType.String)
        {
            var l = new List<object>();
            int n = Math.Min(p.arraySize, 4096);
            for (int i = 0; i < n; i++) l.Add(DumpProp(p.GetArrayElementAtIndex(i), depth + 1));
            return l;
        }
        switch (p.propertyType)
        {
            case SerializedPropertyType.Integer: return p.longValue;
            case SerializedPropertyType.Boolean: return p.boolValue;
            case SerializedPropertyType.Float: return p.doubleValue;
            case SerializedPropertyType.String: return p.stringValue;
            case SerializedPropertyType.Color: return Col(p.colorValue);
            case SerializedPropertyType.ObjectReference: return ObjRef(p.objectReferenceValue);
            case SerializedPropertyType.LayerMask: return p.intValue;
            case SerializedPropertyType.Enum: { var names = p.enumDisplayNames; int idx = p.enumValueIndex; return new Dictionary<string, object> { { "enum", (idx >= 0 && idx < names.Length) ? names[idx] : null }, { "value", p.intValue } }; }
            case SerializedPropertyType.Vector2: return V2(p.vector2Value);
            case SerializedPropertyType.Vector3: return V3(p.vector3Value);
            case SerializedPropertyType.Vector4: return V4(p.vector4Value);
            case SerializedPropertyType.Rect: return Rect(p.rectValue);
            case SerializedPropertyType.ArraySize: return p.intValue;
            case SerializedPropertyType.Character: return p.intValue;
            case SerializedPropertyType.AnimationCurve: return Curve(p.animationCurveValue);
            case SerializedPropertyType.Bounds: return Bounds(p.boundsValue);
            case SerializedPropertyType.Gradient: try { return Grad(p.gradientValue); } catch { return "<gradient>"; }
            case SerializedPropertyType.Quaternion: return Q(p.quaternionValue);
            case SerializedPropertyType.ExposedReference: return ObjRef(p.exposedReferenceValue);
            case SerializedPropertyType.FixedBufferSize: return p.intValue;
            case SerializedPropertyType.Vector2Int: return V2(p.vector2IntValue);
            case SerializedPropertyType.Vector3Int: return V3(p.vector3IntValue);
            case SerializedPropertyType.RectInt: { var r = p.rectIntValue; return new Dictionary<string, object> { { "x", r.x }, { "y", r.y }, { "w", r.width }, { "h", r.height } }; }
            case SerializedPropertyType.BoundsInt: { var b = p.boundsIntValue; return new Dictionary<string, object> { { "pos", V3(b.position) }, { "size", V3(b.size) } }; }
            case SerializedPropertyType.ManagedReference: return "<managedref>";
            case SerializedPropertyType.Hash128: return p.hash128Value.ToString();
            case SerializedPropertyType.Generic:
                {
                    var d = new Dictionary<string, object>();
                    var child = p.Copy(); var end = p.GetEndProperty();
                    if (child.Next(true))
                    {
                        do
                        {
                            if (SerializedProperty.EqualContents(child, end)) break;
                            d[child.name] = DumpProp(child, depth + 1);
                        } while (child.Next(false));
                    }
                    return d;
                }
        }
        return "<" + p.propertyType + ">";
    }

    static object ObjRef(UnityEngine.Object o)
    {
        if (o == null) return null;
        var d = new Dictionary<string, object> { { "type", o.GetType().FullName }, { "name", o.name }, { "instanceID", o.GetInstanceID() } };
        var go = o as GameObject; var c = o as Component;
        if (go != null) d["path"] = GOPath(go);
        else if (c != null) { d["path"] = GOPath(c.gameObject); d["componentType"] = c.GetType().FullName; }
        else { d["assetPath"] = AssetDatabase.GetAssetPath(o); if (o is Sprite) d["sprite"] = SpriteInfo(o as Sprite); if (o is Texture) d["texture"] = TexRef(o as Texture); if (o is Material) d["material"] = MatRef(o as Material); }
        return d;
    }

    static object MM(ParticleSystem.MinMaxCurve c)
    {
        var d = new Dictionary<string, object> { { "mode", c.mode.ToString() }, { "constant", c.constant }, { "constantMin", c.constantMin }, { "constantMax", c.constantMax }, { "multiplier", c.curveMultiplier } };
        if (c.mode == ParticleSystemCurveMode.Curve || c.mode == ParticleSystemCurveMode.TwoCurves) { d["curveMax"] = Curve(c.curveMax); d["curveMin"] = Curve(c.curveMin); }
        return d;
    }
    static object MMG(ParticleSystem.MinMaxGradient g)
    {
        var d = new Dictionary<string, object> { { "mode", g.mode.ToString() }, { "color", Col(g.color) }, { "colorMin", Col(g.colorMin) }, { "colorMax", Col(g.colorMax) } };
        if (g.mode == ParticleSystemGradientMode.Gradient || g.mode == ParticleSystemGradientMode.TwoGradients || g.mode == ParticleSystemGradientMode.RandomColor) { d["gradientMax"] = Grad(g.gradientMax); d["gradientMin"] = Grad(g.gradientMin); }
        return d;
    }
    static object Curve(AnimationCurve c)
    {
        if (c == null) return null;
        var l = new List<object>();
        foreach (var k in c.keys) l.Add(new Dictionary<string, object> { { "t", k.time }, { "v", k.value }, { "in", k.inTangent }, { "out", k.outTangent }, { "inW", k.inWeight }, { "outW", k.outWeight }, { "wm", k.weightedMode.ToString() } });
        // also sampled
        var s = new List<object>();
        for (int i = 0; i <= 32; i++) s.Add(c.Evaluate(i / 32f));
        return new Dictionary<string, object> { { "keys", l }, { "sampled0to1", s }, { "pre", c.preWrapMode.ToString() }, { "post", c.postWrapMode.ToString() } };
    }
    static object Grad(Gradient g)
    {
        if (g == null) return null;
        var ck = new List<object>(); foreach (var k in g.colorKeys) ck.Add(new Dictionary<string, object> { { "t", k.time }, { "c", Col(k.color) } });
        var ak = new List<object>(); foreach (var k in g.alphaKeys) ak.Add(new Dictionary<string, object> { { "t", k.time }, { "a", k.alpha } });
        var s = new List<object>(); for (int i = 0; i <= 32; i++) s.Add(Col(g.Evaluate(i / 32f)));
        return new Dictionary<string, object> { { "mode", g.mode.ToString() }, { "colorKeys", ck }, { "alphaKeys", ak }, { "sampled0to1", s } };
    }
    static object V2(Vector2 v) => new List<object> { v.x, v.y };
    static object V3(Vector3 v) => new List<object> { v.x, v.y, v.z };
    static object V4(Vector4 v) => new List<object> { v.x, v.y, v.z, v.w };
    static object Q(Quaternion q) => new List<object> { q.x, q.y, q.z, q.w };
    static object Col(Color c) => new List<object> { c.r, c.g, c.b, c.a };
    static object Rect(UnityEngine.Rect r) => new Dictionary<string, object> { { "x", r.x }, { "y", r.y }, { "w", r.width }, { "h", r.height } };
    static object Bounds(UnityEngine.Bounds b) => new Dictionary<string, object> { { "center", V3(b.center) }, { "size", V3(b.size) } };
    static object Mat(Matrix4x4 m) { var l = new List<object>(); for (int i = 0; i < 16; i++) l.Add(m[i]); return l; } // column-major m[row + col*4]? Unity indexer m[index] is column-major: index = row + column*4
}

static class Json
{
    public static void Write(StringBuilder sb, object o, int depth)
    {
        if (o == null) { sb.Append("null"); return; }
        switch (o)
        {
            case string s: WriteStr(sb, s); return;
            case bool b: sb.Append(b ? "true" : "false"); return;
            case int i: sb.Append(i); return;
            case long l: sb.Append(l); return;
            case uint ui: sb.Append(ui); return;
            case ulong ul: sb.Append(ul); return;
            case short sh: sb.Append(sh); return;
            case ushort ush: sb.Append(ush); return;
            case byte by: sb.Append(by); return;
            case float f: WriteNum(sb, f); return;
            case double d: WriteNum(sb, d); return;
            case Dictionary<string, object> dict:
                {
                    sb.Append('{'); bool first = true;
                    foreach (var kv in dict) { if (!first) sb.Append(','); first = false; WriteStr(sb, kv.Key); sb.Append(':'); Write(sb, kv.Value, depth + 1); }
                    sb.Append('}'); return;
                }
            case List<object> list:
                {
                    sb.Append('['); bool first = true;
                    foreach (var v in list) { if (!first) sb.Append(','); first = false; Write(sb, v, depth + 1); }
                    sb.Append(']'); return;
                }
            case Array arr:
                {
                    sb.Append('['); bool first = true;
                    foreach (var v in arr) { if (!first) sb.Append(','); first = false; Write(sb, v, depth + 1); }
                    sb.Append(']'); return;
                }
            case Enum e: WriteStr(sb, e.ToString()); return;
        }
        WriteStr(sb, o.ToString());
    }
    static void WriteNum(StringBuilder sb, double d)
    {
        if (double.IsNaN(d)) sb.Append("NaN"); else if (double.IsPositiveInfinity(d)) sb.Append("Infinity"); else if (double.IsNegativeInfinity(d)) sb.Append("-Infinity");
        else sb.Append(d.ToString("R", CultureInfo.InvariantCulture));
    }
    static void WriteStr(StringBuilder sb, string s)
    {
        sb.Append('"');
        foreach (var ch in s)
        {
            switch (ch)
            {
                case '"': sb.Append("\\\""); break;
                case '\\': sb.Append("\\\\"); break;
                case '\n': sb.Append("\\n"); break;
                case '\r': sb.Append("\\r"); break;
                case '\t': sb.Append("\\t"); break;
                default: if (ch < 0x20) sb.Append("\\u").Append(((int)ch).ToString("x4")); else sb.Append(ch); break;
            }
        }
        sb.Append('"');
    }
}
