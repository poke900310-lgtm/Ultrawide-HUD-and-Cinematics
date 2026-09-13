local VERSION = "1.0.0"
local HUD_CLASS = "WBP_GameHUD_C"
local HUD_PATH = "/Game/_Dawnwalker/UI/_Unified/HUD/WBP_GameHUD.WBP_GameHUD_C"
local CAM_CLASS = "/Script/Engine.CameraComponent"
local MAINTAIN_YFOV = 0
local MAINTAIN_XFOV = 1
local CALM_MAX = 6
local BACKSTOP_MS = 5000
local RECHECK_MS = 300
local dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
local LOG = dir .. "Ultrawide.log"
local Cfg = { Enabled = true, RecenterHUD = true, RemoveCinematicBars = true,
              KeepVerticalFov = true, HudAspect = 16 / 9, HudWidthOffset = 0,
              ToggleKey = "", Verbose = false }
local logFile, lastMsg, reps = nil, nil, 0
local function emit(m)
    print("[Ultrawide] " .. m .. "\n")
    if Cfg.Verbose and logFile ~= false then
        if not logFile then local ok, f = pcall(io.open, LOG, "a"); logFile = (ok and f) or false end
        if logFile then pcall(function() logFile:write(m .. "\n"); logFile:flush() end) end
    end
end
local function log(fmt, ...)
    local ok, m = pcall(string.format, fmt, ...); m = ok and m or tostring(fmt)
    if m == lastMsg then reps = reps + 1; return end
    lastMsg = m
    if reps > 0 then emit(string.format("(previous line x%d)", reps + 1)); reps = 0 end
    emit(m)
end
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
local wll, pc
local function _vpSize(w, p) local s = w:GetViewportSize(p); return s.X, s.Y end
local function _vpScale(w, p) return w:GetViewportScale(p) end
local function viewport()
    if not alive(wll) then wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary") end
    if not alive(pc) then pc = FindFirstOf("PlayerController") end
    if not (alive(wll) and alive(pc)) then return end
    local w, h, scale
    local ok, x, y = pcall(_vpSize, wll, pc)
    if ok and num(x) and num(y) and x > 16 then w, h = x, y end
    local oks, sc = pcall(_vpScale, wll, pc)
    return w, h, (oks and num(sc) and sc > 0) and sc or 1
end
local hud, lastInset = nil, nil
local function hudChildren()
    if not alive(hud) then
        hud = nil
        local ok, all = pcall(FindAllOf, HUD_CLASS)
        if ok and type(all) == "table" then for _, x in pairs(all) do
            if alive(x) and not fullName(x):find("Default__", 1, true) then hud = x; break end end end
    end
    local out = {}
    local wt = member(hud, "WidgetTree"); local root = alive(wt) and member(wt, "RootWidget")
    if not alive(root) then return out end
    local ok, n = pcall(function() return root:GetChildrenCount() end)
    if not (ok and num(n)) then return out end
    for i = 0, n - 1 do local okc, ch = pcall(function() return root:GetChildAt(i) end)
        if okc and alive(ch) then out[#out + 1] = ch end end
    return out
end
local function applyHud(force)
    if not (Cfg.Enabled and Cfg.RecenterHUD) then return end
    if not alive(hud) then lastInset = nil end
    local w, h, scale = viewport(); if not w then return end
    local inset = math.max(0, (w - h * Cfg.HudAspect) / 2 / scale) + Cfg.HudWidthOffset
    if inset < 0 then inset = 0 end
    if not force and lastInset and math.abs(inset - lastInset) < 0.5 then return end
    local kids = hudChildren(); local n = 0
    for _, ch in ipairs(kids) do local slot = member(ch, "Slot")
        if alive(slot) and pcall(function() slot:SetPadding({ Left = inset, Top = 0, Right = inset, Bottom = 0 }) end) then n = n + 1 end end
    if n > 0 then lastInset = inset; log("HUD centred to %.3f: inset %.0f on %d containers (%.0fx%.0f)", Cfg.HudAspect, inset, n, w, h) end
end
local function restoreHud()
    for _, ch in ipairs(hudChildren()) do local slot = member(ch, "Slot")
        if alive(slot) then pcall(function() slot:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 0 }) end) end end
    lastInset = nil
end
local watched, seen = {}, {}
local function enforceCam(cam)
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
local function watch(cam)
    if not (Cfg.Enabled and Cfg.RemoveCinematicBars) or not alive(cam) then return end
    local id = fullName(cam); if id == "" or seen[id] then return end
    watched[#watched + 1] = { cam = cam, id = id, calm = 0, due = 0 }
    seen[id] = true
    enforceCam(cam)
end
local function rescanCams()
    if not (Cfg.Enabled and Cfg.RemoveCinematicBars) then return end
    local ok, all = pcall(FindAllOf, "CameraComponent")
    if ok and type(all) == "table" then for _, c in pairs(all) do watch(c) end end
end
local function sweepCams()
    local count, i = #watched, 1
    while i <= count do
        local s = watched[i]
        if s.due > 0 then s.due = s.due - 1; i = i + 1
        elseif alive(s.cam) and fullName(s.cam) == s.id then
            if enforceCam(s.cam) > 0 then s.calm = 0 elseif s.calm < CALM_MAX then s.calm = s.calm + 1 end
            s.due = s.calm; i = i + 1
        else seen[s.id] = nil; watched[i] = watched[count]; watched[count] = nil; count = count - 1 end
    end
end
local lastWake = -1
local function wakeCams()
    for _, s in ipairs(watched) do s.due = 0 end
    local now = os.clock()
    if now - lastWake < 0.5 then return end
    lastWake = now
    sweepCams()
end
local function scheduleRecheck()
    if rawget(_G, "ExecuteWithDelay") == nil then return end
    pcall(ExecuteWithDelay, RECHECK_MS, function()
        ExecuteInGameThread(function()
            for _, s in ipairs(watched) do s.due = 0 end
            pcall(sweepCams)
        end)
    end)
end
local function beat()
    if Cfg.Enabled then applyHud(false); sweepCams() end
end
local function toggle()
    Cfg.Enabled = not Cfg.Enabled
    if Cfg.Enabled then log(">>> Ultrawide ENABLED"); applyHud(true); wakeCams()
    else log("<<< Ultrawide DISABLED"); restoreHud() end
end
log("")
if MISSING then
    log("Dawnwalker Ultrawide %s: this UE4SS build is missing %s - cannot run", VERSION, MISSING)
    return
end
log("Dawnwalker Ultrawide %s loaded (HUD %s @ %.3f, de-bars %s @ any resolution)",
    VERSION, tostring(Cfg.RecenterHUD), Cfg.HudAspect, tostring(Cfg.RemoveCinematicBars))
local queued, draining = {}, false
pcall(function()
    NotifyOnNewObject(CAM_CLASS, function(c)
        queued[#queued + 1] = c
        if not draining then
            if pcall(ExecuteInGameThread, function() draining = false
                local batch = queued; queued = {}
                for _, c2 in ipairs(batch) do pcall(watch, c2) end
                scheduleRecheck() end) then draining = true end
        end
    end)
end)
pcall(function()
    NotifyOnNewObject(HUD_PATH, function(w)
        if alive(w) then hud = w; lastInset = nil; ExecuteInGameThread(function() pcall(applyHud, true) end) end
    end)
end)
pcall(function()
    RegisterHook("/Script/Engine.PlayerController:ClientSetCinematicMode",
        function() ExecuteInGameThread(function() pcall(wakeCams) end); scheduleRecheck() end)
end)
if Cfg.ToggleKey ~= "" and rawget(_G, "RegisterKeyBind") and rawget(_G, "Key") and rawget(_G, "IsKeyBindRegistered") then
    pcall(function() local k = Key[Cfg.ToggleKey:upper()]
        if type(k) == "number" and not IsKeyBindRegistered(k) then
            RegisterKeyBind(k, {}, function() ExecuteInGameThread(function() pcall(toggle) end) end)
            log("toggle key %s bound", Cfg.ToggleKey) end end)
end
pcall(function() ExecuteInGameThread(function() pcall(applyHud, true); pcall(rescanCams) end) end)
local pending = false
pcall(function()
    LoopAsync(BACKSTOP_MS, function()
        if not pending then pending = true
            ExecuteInGameThread(function() pending = false; pcall(beat) end) end
        return false
    end)
end)
