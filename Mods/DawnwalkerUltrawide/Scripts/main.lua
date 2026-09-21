local VERSION = "1.0.5"
local HUD_CLASS = "WBP_GameHUD_C"
local HUD_PATH = "/Game/_Dawnwalker/UI/_Unified/HUD/WBP_GameHUD.WBP_GameHUD_C"
local CAM_CLASS = "/Script/Engine.CameraComponent"
local CAM_PROPS = { "CameraComponent", "DialogueCameraComponent" }
local MAINTAIN_YFOV = 0
local MAINTAIN_XFOV = 1
local BACKSTOP_MS = 5000
local RECHECK_MS = 300
local UNCAP_MS = 500
local dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
local LOG = dir .. "Ultrawide.log"
local Cfg = { Enabled = true, RecenterHUD = true, RemoveCinematicBars = true,
              KeepVerticalFov = true, HudAspect = 16 / 9, HudWidthOffset = 0,
              ToggleKey = "", Verbose = false, Trace = false,
              UncapCinematicFps = true, CinematicAnimFps = 60 }
local logFile, lastMsg, reps = nil, nil, 0
local function emit(m)
    local okc, c = pcall(os.clock); local line = (okc and string.format("[%8.2f] ", c) or "") .. m
    print("[Ultrawide] " .. line .. "\n")
    if Cfg.Verbose and logFile ~= false then
        if not logFile then local ok, f = pcall(io.open, LOG, "a"); logFile = (ok and f) or false end
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
local function dbg(fmt, ...) if Cfg.Trace then local ok, m = pcall(string.format, fmt, ...); log("[trace] %s", ok and m or tostring(fmt)) end end
local function parseAspect(v)
    local a, b = v:match("^%s*(%d+%.?%d*)%s*:%s*(%d+%.?%d*)%s*$")
    if a and tonumber(b) and tonumber(b) > 0 then local r = tonumber(a) / tonumber(b); if r > 0.1 then return r end end
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
                elseif key == "togglekey"           then Cfg.ToggleKey = v
                elseif key == "uncapcinematicfps"   then Cfg.UncapCinematicFps = parseBool(lv, Cfg.UncapCinematicFps)
                elseif key == "cinematicanimfps"    then local n = tonumber(v); if n and n == n and n - n == 0 and n >= 1 then Cfg.CinematicAnimFps = math.floor(n) end
                end
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
local function nameOf(o) if not alive(o) then return "" end local ok, n = pcall(_fullName, o); return ok and type(n) == "string" and n or "" end
local function putBool(o, f, val) local cur = member(o, f)
    if type(cur) ~= "boolean" or cur == val then return false end return pcall(_write, o, f, val) end
local function putNum(o, f, val) local cur = member(o, f)
    if type(cur) ~= "number" or cur == val then return false end return pcall(_write, o, f, val) end
local MISSING
for _, g in ipairs({ "FindAllOf", "StaticFindObject", "FindFirstOf", "ExecuteInGameThread", "LoopAsync", "RegisterHook", "NotifyOnNewObject" }) do
    if rawget(_G, g) == nil then MISSING = (MISSING and MISSING .. ", " or "") .. g end
end
local wll, engine
local function _vpSize(w, p) local s = w:GetViewportSize(p); return s.X, s.Y end
local function _vpScale(w, p) return w:GetViewportScale(p) end
local function _compByClass(a, cls) return a:GetComponentByClass(cls) end
local function _get(o) return o:get() end
local function anchors()
    if not alive(wll) then wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary") end
    if not alive(engine) then engine = FindFirstOf("GameEngine") end
end
local function playerController()
    anchors()
    local gvc = member(engine, "GameViewport")
    local gi = member(gvc, "GameInstance")
    local players = member(gi, "LocalPlayers")
    if players ~= nil then
        local ok, lp = pcall(_index, players, 1)
        if ok then local ctl = member(lp, "PlayerController"); if alive(ctl) then return ctl end end
    end
    local ctl = FindFirstOf("PlayerController")
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
local lastInset = nil
local basePad = {}
local function isCDO(o) return nameOf(o):find("Default__", 1, true) ~= nil end
local function debarOn() return Cfg.Enabled and Cfg.RemoveCinematicBars end
local function uncapOn() return Cfg.Enabled and Cfg.UncapCinematicFps end
local function padOf(slot)
    local m = member(slot, "Padding"); if m == nil then return nil end
    local function g(k) local ok, v = pcall(_index, m, k); return (ok and type(v) == "number") and v or 0 end
    return { l = g("Left"), t = g("Top"), r = g("Right"), b = g("Bottom") }
end
local function findHuds()
    local out = {}
    local ok, all = pcall(FindAllOf, HUD_CLASS)
    if ok and type(all) == "table" then for _, x in pairs(all) do
        if alive(x) and not isCDO(x) then out[#out + 1] = x end end end
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
local function setPad(slot, l, t, r, b)
    return pcall(function() slot:SetPadding({ Left = l, Top = t, Right = r, Bottom = b }) end)
end
local function applyHud(force)
    if not (Cfg.Enabled and Cfg.RecenterHUD) then return end
    local w, h, scale = viewport(); if not w then return end
    local inset = math.max(0, (w - h * Cfg.HudAspect) / 2 / scale) + Cfg.HudWidthOffset
    if inset < 0 then inset = 0 end
    if not force and lastInset and math.abs(inset - lastInset) < 0.5 then return end
    local huds = findHuds(); if #huds == 0 then return end
    local n = 0
    for _, h2 in ipairs(huds) do
        for _, ch in ipairs(hudChildren(h2)) do
            local id = nameOf(ch)
            local slot = id ~= "" and member(ch, "Slot")
            if alive(slot) then
                local base = basePad[id]
                if not base then base = padOf(slot) or { l = 0, t = 0, r = 0, b = 0 }
                    basePad[id] = base
                    if base.l ~= 0 or base.t ~= 0 or base.r ~= 0 or base.b ~= 0 then
                        dbg("base padding on %s: L=%.0f T=%.0f R=%.0f B=%.0f", id, base.l, base.t, base.r, base.b)
                    end
                end
                if setPad(slot, base.l + inset, base.t, base.r + inset, base.b) then n = n + 1 end
            end
        end
    end
    if n > 0 then lastInset = inset
        log("HUD centred to %.3f: inset %.0f on %d containers (%.0fx%.0f)", Cfg.HudAspect, inset, n, w, h) end
end
local function restoreHud()
    if Cfg.RecenterHUD then
        for _, h2 in ipairs(findHuds()) do
            for _, ch in ipairs(hudChildren(h2)) do
                local base = basePad[nameOf(ch)]
                if base then local slot = member(ch, "Slot")
                    if alive(slot) then setPad(slot, base.l, base.t, base.r, base.b) end end
            end
        end
    end
    lastInset = nil
end
local function enforceCam(cam)
    if not debarOn() then return 0 end
    if not alive(cam) then return 0 end
    local made = 0
    if member(cam, "bConstrainAspectRatio") == true then
        if putBool(cam, "bConstrainAspectRatio", false) then made = made + 1 end
        local axis = Cfg.KeepVerticalFov and MAINTAIN_YFOV or MAINTAIN_XFOV
        if putNum(cam, "AspectRatioAxisConstraint", axis) then made = made + 1 end
        if putBool(cam, "bOverrideAspectRatioAxisConstraint", true) then made = made + 1 end
    end
    return made
end
local function structRead(s, n)
    if s == nil then return nil end
    local ok, v = pcall(_index, s, n)
    if ok then return v end
end
local camClass
local function cameraManager()
    local pcm = member(playerController(), "PlayerCameraManager")
    if alive(pcm) then return pcm end
end
local function addCam(out, visited, c)
    local id = nameOf(c)
    if id ~= "" and not visited[id] then visited[id] = true; out[#out + 1] = c end
end
local function camsOf(actor, out, visited, barred)
    if not alive(actor) then return end
    local isCamActor = false
    for _, prop in ipairs(CAM_PROPS) do
        local c = member(actor, prop)
        if alive(c) then
            isCamActor = true
            addCam(out, visited, c)
        end
    end
    if not isCamActor and barred then
        if not alive(camClass) then camClass = StaticFindObject(CAM_CLASS) end
        if alive(camClass) then
            local ok, c = pcall(_compByClass, actor, camClass)
            if ok and alive(c) then
                addCam(out, visited, c)
            end
        end
    end
end
local function debarActor(actor)
    local cams, visited = {}, {}
    camsOf(actor, cams, visited, true)
    local made = 0
    for _, c in ipairs(cams) do if enforceCam(c) > 0 then made = made + 1 end end
    return made
end
local lastId, lastCleared, reasserts = "", false, 0
local warnedNoPcm, warnedNoCam = false, false
local spawnSeen, spawnCleared = 0, 0
local function enforceActiveCam()
    if not debarOn() then return end
    local pcm = cameraManager()
    if not pcm then
        if not warnedNoPcm then warnedNoPcm = true; log("active-camera chain unreadable (no PlayerCameraManager); de-bar idle") end
        return
    end
    local barred = structRead(structRead(member(pcm, "CameraCachePrivate"), "POV"), "bConstrainAspectRatio") == true
    local cams, visited = {}, {}
    camsOf(structRead(member(pcm, "ViewTarget"), "Target"), cams, visited, barred)
    camsOf(structRead(member(pcm, "PendingViewTarget"), "Target"), cams, visited, barred)
    local id0 = cams[1] and nameOf(cams[1]) or ""
    if id0 ~= "" and id0 == lastId and lastCleared and member(cams[1], "bConstrainAspectRatio") == true then
        reasserts = reasserts + 1
        if reasserts == 1 or reasserts % 50 == 0 then log("the game re-set the aspect constraint on the active camera (%d times)", reasserts) end
    end
    local n = 0
    for _, c in ipairs(cams) do if enforceCam(c) > 0 then n = n + 1 end end
    lastId, lastCleared = id0, (n > 0)
    if spawnSeen > 0 then dbg("birth-clear: %d spawn(s), %d de-barred since last pass", spawnSeen, spawnCleared); spawnSeen, spawnCleared = 0, 0 end
    dbg("pass: barred=%s cams=%d cleared=%d", tostring(barred), #cams, n)
    if n > 0 then log("de-barred active camera%s (%d)", (#cams > 1 and "s" or ""), #cams) end
    if barred and #cams == 0 and not warnedNoCam then
        warnedNoCam = true
        log("bars on screen but no camera reachable from the view target - de-bar idle")
    end
end
local scanPending, recheckPending = false, false
local function _scanBody() scanPending = false; pcall(enforceActiveCam) end
local function _recheckBody() recheckPending = false; pcall(enforceActiveCam) end
local function _recheckFire()
    if not pcall(ExecuteInGameThread, _recheckBody) then recheckPending = false end
end
local function scanCams()
    if scanPending then return end
    scanPending = true
    if not pcall(ExecuteInGameThread, _scanBody) then
        scanPending = false
    end
end
local function scheduleRecheck()
    if recheckPending or not debarOn() or rawget(_G, "ExecuteWithDelay") == nil then return end
    recheckPending = true
    if not pcall(ExecuteWithDelay, RECHECK_MS, _recheckFire) then recheckPending = false end
end
local function beat()
    if Cfg.Enabled then dbg("trigger: backstop"); applyHud(false) end
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
    NotifyOnNewObject(CAM_CLASS, function(cam)
        if debarOn() and alive(cam) then
            spawnSeen = spawnSeen + 1
            local okc, made = pcall(enforceCam, cam)
            if okc and type(made) == "number" and made > 0 then spawnCleared = spawnCleared + 1 end
        end
        scheduleRecheck()
    end)
end)
local function onHudBuilt(w)
    if not alive(w) or isCDO(w) then return end
    dbg("trigger: hud-load"); lastInset = nil; basePad = {}
    ExecuteInGameThread(function() pcall(applyHud, true); pcall(enforceActiveCam) end)
end
pcall(function()
    local ok = pcall(NotifyOnNewObject, HUD_PATH, onHudBuilt)
    log("hud-load trigger: %s", ok and "registered" or "UNAVAILABLE (HUD centred at startup and on resolution change only, not after a level load)")
end)
local function regStatus(ok) return ok and "registered" or "unavailable" end
pcall(function()
    local okreg = pcall(NotifyOnNewObject, "/Script/Engine.CameraActor", function(actor)
        if not (debarOn() and alive(actor)) then return end
        local made = debarActor(actor)
        if made > 0 then dbg("actor-birth de-bar: %s (%d cam)", nameOf(actor), made) end
    end)
    log("hook CameraActor birth-clear: %s", regStatus(okreg))
end)
pcall(function()
    local okreg = pcall(RegisterHook, "/Script/Engine.PlayerController:ClientSetCinematicMode", function()
        dbg("trigger: cinematic-mode"); scanCams(); scheduleRecheck()
    end)
    log("hook ClientSetCinematicMode: %s", regStatus(okreg))
end)
pcall(function()
    local okreg = pcall(RegisterHook, "/Script/Engine.PlayerController:SetViewTargetWithBlend", function(_, p1)
        if not debarOn() then return end
        dbg("trigger: view-target-blend")
        local ok, actor = pcall(_get, p1)
        if ok and alive(actor) then
            debarActor(actor)
        end
        scanCams(); scheduleRecheck()
    end)
    log("hook SetViewTargetWithBlend: %s", regStatus(okreg))
end)
for _, fn in ipairs({ "CinematicModeStarted", "CinematicModeFinished" }) do
    local tag = "trigger: " .. fn
    local okreg = pcall(RegisterHook, "/Script/Dawnwalker.DawnwalkerDialogueSubsystem:" .. fn, function()
        dbg(tag); scanCams(); scheduleRecheck()
    end)
    log("hook %s: %s", fn, regStatus(okreg))
end
if Cfg.ToggleKey ~= "" and rawget(_G, "RegisterKeyBind") and rawget(_G, "Key") and rawget(_G, "IsKeyBindRegistered") then
    pcall(function() local k = Key[Cfg.ToggleKey:upper()]
        if type(k) == "number" and not IsKeyBindRegistered(k) then
            RegisterKeyBind(k, {}, function() ExecuteInGameThread(function() pcall(toggle) end) end)
            log("toggle key %s bound", Cfg.ToggleKey) end end)
end
pcall(function() ExecuteInGameThread(function() pcall(applyHud, true); scanCams() end) end)
local beatQueued = false
pcall(function()
    LoopAsync(BACKSTOP_MS, function()
        if not beatQueued then beatQueued = true
            if not pcall(ExecuteInGameThread, function() beatQueued = false; pcall(beat) end) then beatQueued = false end end
        return false
    end)
end)

local KSL_PATH, kslCDO = "/Script/Engine.Default__KismetSystemLibrary", nil
local function _ksl() if not alive(kslCDO) then kslCDO = StaticFindObject(KSL_PATH) end return alive(kslCDO) and kslCDO or nil end
local function _exec(cmd) local k, pc = _ksl(), playerController(); if k and alive(pc) then pcall(function() k:ExecuteConsoleCommand(pc, cmd, pc) end) end end
local function renderCap()
    anchors()
    local gus = member(engine, "GameUserSettings")
    if not alive(gus) then local okf, g = pcall(FindFirstOf, "GameUserSettings"); gus = (okf and alive(g) and not isCDO(g)) and g or nil end
    local v = num(member(gus, "FrameRateLimit"))
    if v and v == v and v - v == 0 and v >= 0 then return v end
    return nil
end
local function _raiseRate(p)
    if not (alive(p) and nameOf(p):find("CinematicNodeLevelSequencePlayer", 1, true)) then return end
    local fr; if not pcall(function() fr = p:GetFrameRate() end) or fr == nil then return end
    local rnum, rden = tonumber(structRead(fr, "Numerator")), tonumber(structRead(fr, "Denominator"))
    if rnum and rden and rden > 0 and (rnum / rden) < Cfg.CinematicAnimFps then
        if pcall(function() fr.Numerator = Cfg.CinematicAnimFps; fr.Denominator = 1; p:SetFrameRate(fr) end) then
            dbg("anim-uncap: %s frame rate %s/%s -> %d/1", nameOf(p), tostring(rnum), tostring(rden), Cfg.CinematicAnimFps)
        end
    end
end
local function uncapPass()
    if not uncapOn() then return end
    local cap = renderCap()
    if cap then _exec(string.format("t.MaxFPS %.0f", cap)) end
    local ok, players = pcall(FindAllOf, "LevelSequencePlayer")
    if ok and type(players) == "table" then for _, p in pairs(players) do if not isCDO(p) then _raiseRate(p) end end end
end
local uncapQueued, uncapLater = false, false
local function _uncapBody() uncapQueued = false; pcall(uncapPass) end
local function uncapNow()
    if uncapQueued or not uncapOn() then return end
    uncapQueued = true
    if not pcall(ExecuteInGameThread, _uncapBody) then uncapQueued = false end
end
local function _uncapLaterFire() uncapLater = false; uncapNow() end
local function uncapSoon()
    if uncapLater or not uncapOn() or rawget(_G, "ExecuteWithDelay") == nil then return end
    uncapLater = true
    if not pcall(ExecuteWithDelay, UNCAP_MS, _uncapLaterFire) then uncapLater = false end
end
pcall(function()
    local a = pcall(RegisterHook, "/Script/Dawnwalker.DawnwalkerDialogueSubsystem:CinematicModeStarted", function()
        uncapNow(); uncapSoon()
    end)
    local b = pcall(RegisterHook, "/Script/Engine.PlayerController:ClientSetCinematicMode", function(_, p1)
        local okb, on = pcall(_get, p1)
        if okb and on == false then return end
        uncapNow(); uncapSoon()
    end)
    log("hook cutscene-uncap: CinematicModeStarted=%s ClientSetCinematicMode=%s", regStatus(a), regStatus(b))
end)
