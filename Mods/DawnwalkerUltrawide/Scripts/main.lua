local VERSION = "1.0.3"
local HUD_CLASS = "WBP_GameHUD_C"
local HUD_PATH = "/Game/_Dawnwalker/UI/_Unified/HUD/WBP_GameHUD.WBP_GameHUD_C"
local CAM_CLASS = "/Script/Engine.CameraComponent"
local MAINTAIN_YFOV = 0
local MAINTAIN_XFOV = 1
local BACKSTOP_MS = 5000
local RECHECK_MS = 300
local dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
local LOG = dir .. "Ultrawide.log"
local Cfg = { Enabled = true, RecenterHUD = true, RemoveCinematicBars = true,
              KeepVerticalFov = true, HudAspect = 16 / 9, HudWidthOffset = 0,
              ToggleKey = "", Verbose = false, Trace = false }
local logFile, lastMsg, reps = nil, nil, 0
local function emit(m)
    local okc, c = pcall(os.clock); local line = (okc and string.format("[%8.2f] ", c) or "") .. m
    print("[Ultrawide] " .. line .. "\n")
    if Cfg.Verbose and logFile ~= false then
        if not logFile then local ok, f = pcall(io.open, LOG, "a"); logFile = (ok and f) or false end
        -- flush per line so the log captures everything up to a crash; the per-spawn burst that
        -- made this expensive is gone (birth-clear now tallies, it does not log per spawn).
        if logFile then pcall(function() logFile:write(line .. "\n"); logFile:flush() end) end
    end
end
local function log(fmt, ...)
    local ok, m = pcall(string.format, fmt, ...); m = ok and m or tostring(fmt)
    if m == lastMsg then reps = reps + 1; return end
    lastMsg = m
    if reps > 0 then emit(string.format("(previous line x%d)", reps + 1)); reps = 0 end
    emit(m)
end
local function trace(fmt, ...) if Cfg.Trace then local ok, m = pcall(string.format, fmt, ...); log("[trace] " .. (ok and m or tostring(fmt))) end end
local function parseAspect(v)
    local a, b = v:match("^%s*(%d+%.?%d*)%s*:%s*(%d+%.?%d*)%s*$")
    if a and tonumber(b) and tonumber(b) > 0 then return tonumber(a) / tonumber(b) end
    local n = tonumber(v); if n and n > 0.1 then return n end
end
local function parseBool(lv, d)
    if lv == "true" or lv == "1" or lv == "yes" or lv == "on" then return true
    elseif lv == "false" or lv == "0" or lv == "no" or lv == "off" then return false end
    return d
end
local function applyIni()
    local body
    for _, name in ipairs({ "Ultrawide.ini", "Ultrawide.defaults.ini" }) do
        local ok, f = pcall(io.open, dir .. name, "r")
        if ok and f then local okr, b = pcall(function() return f:read("a") end); pcall(function() f:close() end)
            if okr and type(b) == "string" and b ~= "" then body = b; break end end
    end
    if not body then return end
    body = body:gsub("^\239\187\191", "")
    for line in body:gmatch("[^\r\n]+") do
        line = line:gsub("[ \t]+", " ")
        if not line:match("^%s*[;#%[]") then
            local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
            if k then
                v = v:gsub("%s+[;#].*$", "")
                local key, lv = k:lower(), v:lower()
                if     key == "enabled"             then Cfg.Enabled = parseBool(lv, Cfg.Enabled)
                elseif key == "recenterhud"         then Cfg.RecenterHUD = parseBool(lv, Cfg.RecenterHUD)
                elseif key == "removecinematicbars" then Cfg.RemoveCinematicBars = parseBool(lv, Cfg.RemoveCinematicBars)
                elseif key == "keepverticalfov"     then Cfg.KeepVerticalFov = parseBool(lv, Cfg.KeepVerticalFov)
                elseif key == "verbose"             then Cfg.Verbose = parseBool(lv, Cfg.Verbose)
                elseif key == "trace"               then Cfg.Trace = parseBool(lv, Cfg.Trace)
                elseif key == "hudaspect"           then local a = parseAspect(v); if a then Cfg.HudAspect = a end
                elseif key == "hudwidthoffset"      then local n = tonumber(v); if n and n == n and n - n == 0 then Cfg.HudWidthOffset = n end
                elseif key == "togglekey"           then Cfg.ToggleKey = v end
            end
        end
    end
end
pcall(applyIni)
local function num(x) return type(x) == "number" and x or nil end
local function _isValid(o) return o:IsValid() end
local function _index(o, n) return o[n] end
local function _fullName(o) return o:GetFullName() end
local function _write(o, f, v) o[f] = v end
local function alive(o) if not o then return false end local ok, v = pcall(_isValid, o); return ok and v == true end
local function member(o, n) if not alive(o) then return nil end local ok, v = pcall(_index, o, n); if ok then return v end end
local function fullName(o) if not alive(o) then return "" end local ok, n = pcall(_fullName, o); return ok and type(n) == "string" and n or "" end
local function setBool(o, f, val) local cur = member(o, f)
    if type(cur) ~= "boolean" or cur == val then return false end return pcall(_write, o, f, val) end
local function setNum(o, f, val) local cur = member(o, f)
    if type(cur) ~= "number" or cur == val then return false end return pcall(_write, o, f, val) end
local MISSING
for _, g in ipairs({ "FindAllOf", "StaticFindObject", "FindFirstOf", "ExecuteInGameThread", "LoopAsync", "RegisterHook", "NotifyOnNewObject" }) do
    if rawget(_G, g) == nil then MISSING = (MISSING and MISSING .. ", " or "") .. g end
end
-- Controller/HUD are never cached across ticks: on a save load / level travel the
-- engine destroys and GC-purges them, after which alive() can read freed memory and
-- lie (the 1.0.2 camera bug-class, still latent for these two). Only process-lifetime
-- objects (the CDO, GEngine) are held; the controller is re-derived every pass through
-- GC-tracked properties (a pointer read that way is live or already nulled, never freed
-- memory), with a fresh FindFirstOf fallback (also live-safe) if that chain is unavailable.
local wll, engine
local function _vpSize(w, p) local s = w:GetViewportSize(p); return s.X, s.Y end
local function _vpScale(w, p) return w:GetViewportScale(p) end
local function anchors()
    if not alive(wll) then wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary") end
    if not alive(engine) then engine = FindFirstOf("GameEngine") end   -- process-lifetime; at most one scan, only until found
end
local function playerController()
    anchors()
    local gvc = member(engine, "GameViewport")
    local gi = member(gvc, "GameInstance")
    local players = member(gi, "LocalPlayers")
    if players ~= nil then
        local ok, lp = pcall(_index, players, 1)   -- TArray proxy, 1-based; touched only inside this pass, never stored
        if ok then local ctl = member(lp, "PlayerController"); if alive(ctl) then return ctl end end
    end
    local ctl = FindFirstOf("PlayerController")   -- fallback: fresh lookup (live handle, crash-safe) when the chain yields no live controller
    if alive(ctl) then return ctl end
end
local function viewport()
    local ctl = playerController()
    if not (alive(wll) and ctl) then return end
    local w, h
    local ok, x, y = pcall(_vpSize, wll, ctl)
    if ok and num(x) and num(y) and x > 16 then w, h = x, y end
    local oks, sc = pcall(_vpScale, wll, ctl)
    return w, h, (oks and num(sc) and sc > 0) and sc or 1
end
local lastInset, hudDirty = nil, true
local basePad = {}   -- container fullName -> its ORIGINAL padding {l,t,r,b} (numbers, never handles), captured before we modify it.
-- NOTE: a UE4SS mod hot-reload (not a game restart) re-runs this file with basePad empty while the live HUD still carries the
-- previous inset, so it re-captures the modified padding as "base" and insets twice until the next real HUD rebuild / restart.
-- Shipped users never hot-reload, so this is left unguarded on purpose (any heuristic guard risks misreading authored padding).
local function padOf(slot)   -- read the slot's current FMargin; degrades to nil if unreadable
    local m = member(slot, "Padding"); if m == nil then return nil end
    local function g(k) local ok, v = pcall(_index, m, k); return (ok and type(v) == "number") and v or 0 end
    return { l = g("Left"), t = g("Top"), r = g("Right"), b = g("Bottom") }
end
local function findHuds()   -- every live non-CDO instance, fresh each call; nothing held past the caller's pass
    local out = {}
    local ok, all = pcall(FindAllOf, HUD_CLASS)
    if ok and type(all) == "table" then for _, x in pairs(all) do
        if alive(x) and not fullName(x):find("Default__", 1, true) then out[#out + 1] = x end end end
    return out
end
local function hudChildren(h)
    local out = {}
    local wt = member(h, "WidgetTree"); local root = alive(wt) and member(wt, "RootWidget")
    if not alive(root) then return out end
    local ok, n = pcall(function() return root:GetChildrenCount() end)
    if not (ok and num(n)) then return out end
    for i = 0, n - 1 do local okc, ch = pcall(function() return root:GetChildAt(i) end)
        if okc and alive(ch) then out[#out + 1] = ch end end
    return out
end
local function applyHud(force)
    if not (Cfg.Enabled and Cfg.RecenterHUD) then return end
    local w, h, scale = viewport(); if not w then return end
    local inset = math.max(0, (w - h * Cfg.HudAspect) / 2 / scale) + Cfg.HudWidthOffset
    if inset < 0 then inset = 0 end
    if not (force or hudDirty) and lastInset and math.abs(inset - lastInset) < 0.5 then return end
    local huds = findHuds(); if #huds == 0 then return end   -- scan only on load / resize / explicit force, never steady state
    local n = 0
    for _, h2 in ipairs(huds) do   -- if an old and a new HUD coexist for a tick, centre both
        for _, ch in ipairs(hudChildren(h2)) do
            local id = fullName(ch)
            local slot = id ~= "" and member(ch, "Slot")   -- need a stable key to cache base padding; skip unidentifiable containers
            if alive(slot) then
                local base = basePad[id]
                if not base then base = padOf(slot) or { l = 0, t = 0, r = 0, b = 0 }   -- capture the base padding ONCE, before we overwrite it
                    basePad[id] = base
                    if base.l ~= 0 or base.t ~= 0 or base.r ~= 0 or base.b ~= 0 then
                        trace("base padding on %s: L=%.0f T=%.0f R=%.0f B=%.0f", id, base.l, base.t, base.r, base.b)
                    end
                end
                -- offset FROM the base: add the recentre inset to left/right, keep the game's own top/bottom (and base left/right)
                if pcall(function() slot:SetPadding({ Left = base.l + inset, Top = base.t, Right = base.r + inset, Bottom = base.b }) end) then n = n + 1 end
            end
        end
    end
    if n > 0 then lastInset, hudDirty = inset, false
        log("HUD centred to %.3f: inset %.0f on %d containers (%.0fx%.0f)", Cfg.HudAspect, inset, n, w, h) end
end
local function restoreHud()
    if Cfg.RecenterHUD then   -- only touch containers we actually modified; never write zeros over padding we never captured
        for _, h2 in ipairs(findHuds()) do
            for _, ch in ipairs(hudChildren(h2)) do
                local base = basePad[fullName(ch)]
                if base then local slot = member(ch, "Slot")
                    if alive(slot) then pcall(function()
                        slot:SetPadding({ Left = base.l, Top = base.t, Right = base.r, Bottom = base.b }) end) end end
            end
        end
    end
    lastInset, hudDirty = nil, true
end
-- Camera de-bar: enforce only the ACTIVE on-screen camera. Only the camera the
-- PlayerCameraManager is viewing through ever renders letterbox bars, so each pass
-- resolves that one camera fresh (PlayerController -> PlayerCameraManager ->
-- ViewTarget/PendingViewTarget.Target -> camera component) and clears the aspect
-- constraint on it alone -- never a walk of the whole object array. No camera
-- handle is held past the synchronous pass that obtained it, so a camera freed
-- during rapid cinematic churn can never be reached through a stale handle. UE4SS
-- exposes no non-dereferencing validity test to Lua, so freshness of lookup is the
-- only safe primitive: resolve this tick, act, and drop every handle.
local function enforceCam(cam)
    if not (Cfg.Enabled and Cfg.RemoveCinematicBars) then return 0 end
    if not alive(cam) then return 0 end
    local made = 0
    if member(cam, "bConstrainAspectRatio") == true then
        if setBool(cam, "bConstrainAspectRatio", false) then made = made + 1 end
        local axis = Cfg.KeepVerticalFov and MAINTAIN_YFOV or MAINTAIN_XFOV
        if setNum(cam, "AspectRatioAxisConstraint", axis) then made = made + 1 end
        if setBool(cam, "bOverrideAspectRatioAxisConstraint", true) then made = made + 1 end
    end
    return made
end
-- Struct-proxy field read. member() calls o:IsValid() first, which UObjects have
-- but the FTViewTarget / FMinimalViewInfo struct proxies do not, so struct hops
-- use this pcall-only read. A proxy is only ever touched inside the same
-- synchronous pass that read its owning UObject, never stored.
local function field(s, n)
    if s == nil then return nil end
    local ok, v = pcall(_index, s, n)
    if ok then return v end
end
local camClass   -- UClass, a permanent engine object (like wll); resolved lazily, never a camera instance
local function cameraManager()
    local pcm = member(playerController(), "PlayerCameraManager")
    if alive(pcm) then return pcm end
end
-- The camera component(s) the manager renders `actor` through: at most two named
-- subobjects, plus one GetComponentByClass call only when the actor is not a named
-- camera actor AND bars are actually on screen. Never walks the object array.
local function camsOf(actor, out, seen, barred)
    if not alive(actor) then return false end
    local isCamActor = false
    for _, prop in ipairs({ "CameraComponent", "DialogueCameraComponent" }) do
        local c = member(actor, prop)
        if alive(c) then
            isCamActor = true
            local id = fullName(c)
            if id ~= "" and not seen[id] then seen[id] = true; out[#out + 1] = c end
        end
    end
    if not isCamActor and barred then
        if not alive(camClass) then camClass = StaticFindObject(CAM_CLASS) end
        if alive(camClass) then
            local ok, c = pcall(function() return actor:GetComponentByClass(camClass) end)
            if ok and alive(c) then
                local id = fullName(c)
                if id ~= "" and not seen[id] then seen[id] = true; out[#out + 1] = c end
            end
        end
    end
end
-- Diagnostics only (plain strings/numbers, never handles): a canary that answers "does the
-- game re-assert the constraint on the same camera?" without any scan. Kept for the first
-- public release; the in-game runs never showed bars, so this path is as yet unexercised.
local lastId, lastCleared, reasserts = "", false, 0
local warnedNoPcm, warnedNoCam = false, false
local spawnSeen, spawnCleared = 0, 0   -- birth-clear tally, reported once per pass (plain numbers, never handles)
-- One pass: de-bar the active (and, mid-blend, the pending) camera. Fired by
-- events (camera spawn / cut / cinematic edges) with one delayed recheck, plus the
-- 5 s backstop. There is no continuous poll -- each call resolves one camera, acts,
-- and returns.
local function enforceActiveCam()
    if not (Cfg.Enabled and Cfg.RemoveCinematicBars) then return end
    local pcm = cameraManager()
    if not pcm then
        if not warnedNoPcm then warnedNoPcm = true; log("active-camera chain unreadable (no PlayerCameraManager); de-bar idle") end
        return
    end
    local barred = field(field(member(pcm, "CameraCachePrivate"), "POV"), "bConstrainAspectRatio") == true
    local cams, seen = {}, {}
    camsOf(field(member(pcm, "ViewTarget"), "Target"), cams, seen, barred)
    camsOf(field(member(pcm, "PendingViewTarget"), "Target"), cams, seen, barred)
    local id0 = cams[1] and fullName(cams[1]) or ""
    if id0 ~= "" and id0 == lastId and lastCleared and member(cams[1], "bConstrainAspectRatio") == true then
        reasserts = reasserts + 1
        if reasserts == 1 or reasserts % 50 == 0 then log("the game re-set the aspect constraint on the active camera (%d times)", reasserts) end
    end
    local n = 0
    for _, c in ipairs(cams) do if enforceCam(c) > 0 then n = n + 1 end end
    lastId, lastCleared = id0, (n > 0)
    if spawnSeen > 0 then trace("birth-clear: %d spawn(s), %d de-barred since last pass", spawnSeen, spawnCleared); spawnSeen, spawnCleared = 0, 0 end
    trace("pass: barred=%s cams=%d cleared=%d", tostring(barred), #cams, n)
    if n > 0 then log("de-barred active camera%s (%d)", (#cams > 1 and "s" or ""), #cams) end
    if barred and #cams == 0 and not warnedNoCam then
        warnedNoCam = true
        log("bars on screen but no camera reachable from the view target - de-bar idle")
    end
end
-- Triggers are event-driven: each cinematic edge / camera spawn / cut queues one
-- immediate active-camera pass (coalesced, at most one in flight) plus one delayed
-- recheck to catch the view target settling a frame later. There is NO continuous
-- poll -- the only periodic work is the 5 s backstop, which does one active-camera
-- pass. A rare mid-cinematic hard cut onto a pre-existing camera (native
-- SetViewTarget: no hook, no spawn) is caught by that backstop within 5 s.
local scanPending, recheckPending = false, false
local function scanCams()
    if scanPending then return end
    scanPending = true
    if not pcall(ExecuteInGameThread, function() scanPending = false; pcall(enforceActiveCam) end) then
        scanPending = false
    end
end
local function scheduleRecheck()
    if recheckPending or not (Cfg.Enabled and Cfg.RemoveCinematicBars) or rawget(_G, "ExecuteWithDelay") == nil then return end
    recheckPending = true
    if not pcall(ExecuteWithDelay, RECHECK_MS, function()
        if not pcall(ExecuteInGameThread, function() recheckPending = false; pcall(enforceActiveCam) end) then recheckPending = false end
    end) then recheckPending = false end
end
local function beat()
    if Cfg.Enabled then trace("trigger: backstop"); applyHud(false); enforceActiveCam() end
end
local function toggle()
    Cfg.Enabled = not Cfg.Enabled
    if Cfg.Enabled then log(">>> Ultrawide ENABLED"); applyHud(true); scanCams()
    else log("<<< Ultrawide DISABLED"); restoreHud() end
end
log("")
if MISSING then
    log("Dawnwalker Ultrawide %s: this UE4SS build is missing %s - cannot run", VERSION, MISSING)
    return
end
log("Dawnwalker Ultrawide %s loaded (HUD %s @ %.3f, de-bars %s @ any resolution)",
    VERSION, tostring(Cfg.RecenterHUD), Cfg.HudAspect, tostring(Cfg.RemoveCinematicBars))
pcall(function()
    NotifyOnNewObject(CAM_CLASS, function(cam)   -- preemptive: clear each camera the instant it is born, before any cut can view it
        if Cfg.Enabled and Cfg.RemoveCinematicBars and alive(cam) then   -- fresh object, used synchronously, never stored
            spawnSeen = spawnSeen + 1            -- tallied here, reported once per pass; per-spawn logging would hitch the burst
            local okc, made = pcall(enforceCam, cam)
            if okc and type(made) == "number" and made > 0 then spawnCleared = spawnCleared + 1 end
        end
        scheduleRecheck()   -- one delayed active-camera pass covers a pre-existing viewed camera and any init-race
    end)
end)
local function onHudBuilt(w)   -- HUD (re)build == level/save load: recentre + clear the viewed camera; holds no reference
    if not alive(w) or fullName(w):find("Default__", 1, true) then return end
    trace("trigger: hud-load"); hudDirty = true; lastInset = nil; basePad = {}   -- old entries are for the destroyed HUD widget; recapture fresh
    ExecuteInGameThread(function() pcall(applyHud, true); pcall(enforceActiveCam) end)
end
pcall(function()
    local ok = pcall(NotifyOnNewObject, HUD_PATH, onHudBuilt)
    log("hud-load trigger: %s", ok and "registered" or "UNAVAILABLE (HUD centred at startup and on resolution change only, not after a level load)")
end)
pcall(function()
    local okreg = pcall(RegisterHook, "/Script/Engine.PlayerController:ClientSetCinematicMode", function()
        trace("trigger: cinematic-mode"); scanCams(); scheduleRecheck()
    end)
    log("hook ClientSetCinematicMode: %s", okreg and "registered" or "unavailable")
end)
-- Cut edge, zero-frame path: the new view target is a hook parameter valid THIS
-- tick, so the incoming camera is de-barred before its first frame draws. Only
-- fires when the game routes the cut through ProcessEvent (BP / dialogue);
-- sequencer hard cuts use native SetViewTarget and are caught by the recheck chain.
pcall(function()
    local okreg = pcall(RegisterHook, "/Script/Engine.PlayerController:SetViewTargetWithBlend", function(_, p1)
        if not (Cfg.Enabled and Cfg.RemoveCinematicBars) then return end
        trace("trigger: view-target-blend")
        local ok, actor = pcall(function() return p1:get() end)
        if ok and alive(actor) then
            local cams, seen = {}, {}
            camsOf(actor, cams, seen, true)
            for _, c in ipairs(cams) do enforceCam(c) end   -- handles die with this callback
        end
        scanCams(); scheduleRecheck()
    end)
    log("hook SetViewTargetWithBlend: %s", okreg and "registered" or "unavailable")
end)
-- Game-native dialogue/cinematic edges (present in Dawnwalker.exe); best effort,
-- silently skipped if not hookable. Each costs one coalesced pass plus one recheck,
-- so all are kept as cheap belt-and-suspenders alongside ClientSetCinematicMode.
for _, fn in ipairs({ "CinematicModeStarted", "CinematicModeFinished" }) do
    local okreg = pcall(RegisterHook, "/Script/Dawnwalker.DawnwalkerDialogueSubsystem:" .. fn, function()
        trace("trigger: " .. fn); scanCams(); scheduleRecheck()
    end)
    log("hook %s: %s", fn, okreg and "registered" or "unavailable")
end
if Cfg.ToggleKey ~= "" and rawget(_G, "RegisterKeyBind") and rawget(_G, "Key") and rawget(_G, "IsKeyBindRegistered") then
    pcall(function() local k = Key[Cfg.ToggleKey:upper()]
        if type(k) == "number" and not IsKeyBindRegistered(k) then
            RegisterKeyBind(k, {}, function() ExecuteInGameThread(function() pcall(toggle) end) end)
            log("toggle key %s bound", Cfg.ToggleKey) end end)
end
pcall(function() ExecuteInGameThread(function() pcall(applyHud, true); scanCams() end) end)
local pending = false
pcall(function()
    LoopAsync(BACKSTOP_MS, function()
        if not pending then pending = true
            if not pcall(ExecuteInGameThread, function() pending = false; pcall(beat) end) then pending = false end end
        return false
    end)
end)
