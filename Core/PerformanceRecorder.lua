-- Opt-in local performance history. No gameplay payloads are retained.
local ADDON, AvidAngler = ...
local Recorder = {}
AvidAngler.Recorder = Recorder
local SCHEMA, MAX_SESSIONS, MAX_RECENT, MAX_WORST = 1, 14, 200, 50
local ids = {
    "core.loot",
    "core.catch",
    "core.cast",
    "core.safety",
    "casting.events",
    "casting.update",
    "casting.resolve",
    "casting.choices",
    "casting.bags",
    "casting.toys",
    "casting.context",
    "tracking.stats",
    "tracking.analytics",
    "tracking.filterCatches",
    "tracking.filterCasts",
    "tracking.refresh",
    "tracking.value",
    "scoring.events",
    "scoring.build",
    "scoring.refresh",
    "scoring.watch",
    "scoring.catchRefresh",
    "scoring.zoneRefresh",
    "ui.refresh",
    "ui.queue",
    "ui.tracking",
    "ui.scoring",
    "ui.settings",
    "ui.achievements",
    "ui.guide",
    "ui.fishingStatus",
    "alerts.supplies",
    "alerts.venom",
}
local index = {}; for i, label in ipairs(ids) do index[label] = i end
local active, session, db, watcher, depth = false, nil, nil, nil, 0
local initialized = false
local starts, children, stackSessions = {}, {}, {}
local loading, context, combat, graceUntil = true, "unknown", "unknown", 0
local latestID, latestMs, latestAt = 0, 0, 0
local lastTick, baseline, nextContext = nil, 0, 0
local capMs, backgroundCapMs = 0, 0
local accountedAt, nextStartup, intervalOwn, intervalCalls = 0, 0, 0, 0
local lifecycleIDs = {start=true, autoStart=true, firstTick=true, leaving=true, entering=true, logout=true, stop=true}
local clock = GetTimePreciseSec or GetTime
local function now() return clock() end
local function plain(v) return not AvidAngler:IsSecretValue(v) end
local function number(v)
    if not plain(v) or type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end
local function read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and plain(value) then return value end
end
local function stat() return {n=0, total=0, own=0, peak=0, errors=0, loading=0, over10=0, over50=0, over100=0, over500=0} end
local function ringPush(ring, record, limit)
    ring.pos = ring.pos % limit + 1
    ring.data[ring.pos] = record
    ring.count = math.min(limit, ring.count + 1)
end
local function keepWorst(list, record)
    if #list >= MAX_WORST and record.ms <= list[#list].ms then return end
    local pos = #list + 1
    while pos > 1 and record.ms > list[pos-1].ms do pos = pos - 1 end
    table.insert(list, pos, record)
    list[MAX_WORST+1] = nil
end
local function refreshContext()
    context, combat = "unknown", "unknown"
    local ok, inside, kind = pcall(IsInInstance or function() end)
    if ok and plain(inside) and plain(kind) then
        if inside == false then context = read(IsResting) == true and "city" or "world"
        elseif inside == true then
            if kind == "raid" or kind == "party" or kind == "scenario" or kind == "arena" or kind == "pvp"
                or kind == "neighborhood" or kind == "interior" then context = kind end
        end
    end
    local function capPeriod(key)
        local raw=read(C_CVar and C_CVar.GetCVar,key)
        local fps=type(raw)=="string" and tonumber(raw) or number(raw)
        return fps and fps>0 and 1000/fps or 0
    end
    capMs,backgroundCapMs=capPeriod("maxFPS"),capPeriod("maxFPSBk")
    local value = read(InCombatLockdown)
    if value == true then combat = "combat" elseif value == false then combat = "calm" end
end
local function newSession()
    local version = read(C_AddOns and C_AddOns.GetAddOnMetadata, ADDON, "Version")
    local client = read(GetBuildInfo)
    local build = read(function() local _, value = GetBuildInfo(); return value end)
    local s = {diagnostics=2, unobserved=0, ticks=0, wrappedOwn=0, wrappedCalls=0,
        startup={}, nativeWorst={}, lifecycle={data={},pos=0,count=0}, started=time(), ended=time(), clockStart=now(), build=type(build)=="string" and build or "unknown", version=type(version)=="string" and version or "unknown",
        client=type(client)=="string" and client or "unknown", frames=0, measured=0,
        loading=0, unavailable=0, hitches=0, peak=0, addonSelfTotal=0, addonSelfSamples=0,
        addonTotal=0, addonSamples=0, appTotal=0, appSamples=0, capFrames=0, capSuspectSec=0,
        samplerMs=0, samplerPeak=0, bookMs=0, skippedDepth=0,
        hist={0,0,0,0,0,0}, contexts={}, operations={}, recent={data={},pos=0,count=0}, worst={},
        slow={data={},pos=0,count=0}, slowWorst={}}
    for i=1,#ids do s.operations[i] = stat() end
    for _, key in ipairs({"unknown","city","world","raid","party","scenario","arena","pvp","neighborhood","interior"}) do
        s.contexts[key] = {sec=0,hitches=0}
    end
    db.sessions[#db.sessions+1] = s
    if #db.sessions > MAX_SESSIONS then table.remove(db.sessions,1) end
    return s
end

-- Fixed identifiers prevent dynamic keys or private data entering the history.
function AvidAngler:MonitorWrap(label, fn)
    return function(...) return self:MonitorCall(label, fn, ...) end
end
local function finishCall(id, level, ok, ...)
    local ended = now()
    local elapsed = math.max(0, (ended-starts[level])*1000)
    local own = math.max(0, elapsed-children[level])
    local owner = stackSessions[level]
    stackSessions[level] = nil
    depth = level-1
    if depth > 0 then children[depth] = children[depth] + elapsed end
    if active and session == owner then
        intervalOwn=intervalOwn+own; intervalCalls=intervalCalls+1
        session.wrappedOwn=session.wrappedOwn+own; session.wrappedCalls=session.wrappedCalls+1
        local s = session.operations[id]
        s.n=s.n+1; s.total=s.total+elapsed; s.own=s.own+own; s.peak=math.max(s.peak,elapsed)
        local duringLoading=loading or ended<graceUntil
        if duringLoading then s.loading=s.loading+1 end
        if not ok then s.errors=s.errors+1 end
        if elapsed>=10 then s.over10=s.over10+1 end
        if elapsed>=50 then s.over50=s.over50+1 end
        if elapsed>=100 then s.over100=s.over100+1 end
        if elapsed>=500 then s.over500=s.over500+1 end
        if elapsed>=10 then
            local rec = {at=time(), offset=(ended-owner.clockStart)*1000, id=id, ms=elapsed, own=own, ctx=context, combat=combat, loading=duringLoading}
            ringPush(session.slow,rec,MAX_RECENT); keepWorst(session.slowWorst,rec)
            if ended-latestAt>0.5 or elapsed>=latestMs then latestID,latestMs,latestAt=id,elapsed,ended end
        end
        session.bookMs=session.bookMs+math.max(0,(now()-ended)*1000)
    end
    if not ok then error((...),0) end
    return ...
end
function AvidAngler:MonitorCall(label, fn, ...)
    if not active then return fn(...) end
    if not plain(label) then return fn(...) end
    local id = index[label]
    if not id then return fn(...) end
    if depth>=32 then session.skippedDepth=session.skippedDepth+1; return fn(...) end
    depth=depth+1
    local level=depth
    starts[level],children[level],stackSessions[level]=now(),0,session
    return finishCall(id,level,pcall(fn,...))
end

local function metric(method, ...)
    return number(read(method, ...))
end
-- Account event/stop boundaries separately: these are not observed frame intervals.
local function accountBoundary(at, excluded)
    if not active then return end
    local delta=math.max(0,at-accountedAt)
    session[excluded and "loading" or "unobserved"]=session[excluded and "loading" or "unobserved"]+delta
    accountedAt=at
    session.ended=time()
end
local function mark(kind, at)
    if active then ringPush(session.lifecycle,{kind=kind,offset=math.max(0,(at-session.clockStart)*1000)},32) end
end
local function samplerCost(started)
    local cost=math.max(0,(now()-started)*1000)
    session.samplerMs=session.samplerMs+cost; session.samplerPeak=math.max(session.samplerPeak,cost)
end
function Recorder:Tick()
    if not active then return end
    local started=now()
    local previous=lastTick
    local delta=math.max(0,started-accountedAt)
    local gap=previous and math.max(0,started-previous)*1000 or 0
    accountedAt=started; lastTick=started
    if started>=nextContext then refreshContext(); nextContext=started+2 end
    session.ended=time(); session.ticks=session.ticks+1
    if session.ticks==1 then mark("firstTick",started) end
    local phase=loading and "loading" or (started<graceUntil or (previous and previous<graceUntil)) and "grace"
        or not previous and "first" or "measured"
    local P,M=C_AddOnProfiler,Enum and Enum.AddOnProfilerMetric
    local aa,all,app
    if P and M and number(M.LastTime) and read(P.IsEnabled)==true then
        aa=metric(P.GetAddOnMetric,ADDON,M.LastTime)
        all=metric(P.GetOverallMetric,M.LastTime)
        app=metric(P.GetApplicationMetric,M.LastTime)
    end
    if aa and aa<0 then aa=nil end
    if all and all<0 then all=nil end
    if app and app<0 then app=nil end
    local startup=#session.startup<80
        and (session.ticks<=10 or ((started-session.clockStart)<=60 and started>=nextStartup))
    local worst=aa and aa>=10 and (#session.nativeWorst<MAX_WORST or aa>session.nativeWorst[#session.nativeWorst].aa)
    if startup or worst then
        local r={offset=math.max(0,(started-session.clockStart)*1000),gap=gap,span=delta*1000,
            phase=phase,aa=aa,all=all,app=app,own=intervalOwn,calls=intervalCalls,tick=session.ticks}
        if startup then session.startup[#session.startup+1]=r; nextStartup=started+1 end
        if worst then
            local pos=#session.nativeWorst+1
            while pos>1 and aa>session.nativeWorst[pos-1].aa do pos=pos-1 end
            table.insert(session.nativeWorst,pos,r); session.nativeWorst[MAX_WORST+1]=nil
        end
    end
    intervalOwn,intervalCalls=0,0
    if phase~="measured" or delta<=0 then
        local key=(phase=="loading" or phase=="grace") and "loading" or "unobserved"
        session[key]=session[key]+delta; baseline=0; samplerCost(started); return
    end
    local ms=gap
    session.frames=session.frames+1; session.measured=session.measured+delta
    session.contexts[context].sec=session.contexts[context].sec+delta
    local bucket = ms<16.7 and 1 or ms<33.4 and 2 or ms<50 and 3 or ms<100 and 4 or ms<500 and 5 or 6
    session.hist[bucket]=session.hist[bucket]+1
    if aa and aa>=0 then session.addonSelfTotal=session.addonSelfTotal+aa; session.addonSelfSamples=session.addonSelfSamples+1
    else aa=nil; session.unavailable=session.unavailable+delta end
    if all and all>=0 then session.addonTotal=session.addonTotal+all; session.addonSamples=session.addonSamples+1 else all=nil end
    if app and app>=0 then session.appTotal=session.appTotal+app; session.appSamples=session.appSamples+1 else app=nil end
    local matchesCap=capMs>0 and math.abs(ms-capMs)<capMs*0.08
    if matchesCap then session.capFrames=session.capFrames+1 end
    local suspect=backgroundCapMs>0 and math.abs(ms-backgroundCapMs)<backgroundCapMs*0.08
        and math.abs(backgroundCapMs-capMs)>backgroundCapMs*0.08
    if suspect then session.capSuspectSec=session.capSuspectSec+delta end
    local threshold=math.max(50,baseline*2,capMs*1.5)
    if ms>=threshold then
        session.hitches=session.hitches+1; session.peak=math.max(session.peak,ms)
        session.contexts[context].hitches=session.contexts[context].hitches+1
        local nearby=started-latestAt<=0.5
        local rec={at=time(),offset=(started-session.clockStart)*1000,ms=ms,aa=aa,all=all,app=app,ctx=context,combat=combat,cap=suspect,
            id=nearby and latestID or 0,nearMs=nearby and latestMs or 0,
            nearAge=nearby and (started-latestAt)*1000 or 0}
        ringPush(session.recent,rec,MAX_RECENT); keepWorst(session.worst,rec)
    end
    if baseline==0 then baseline=math.min(ms,50)
    elseif ms<threshold then baseline=baseline+(ms-baseline)*0.02 end
    samplerCost(started)
end
function Recorder:Start(automatic)
    if active or not db then return end
    db.enabled=true; active=true; session=newSession()
    accountedAt=session.clockStart; nextStartup=0; intervalOwn,intervalCalls=0,0
    mark(automatic and "autoStart" or "start",accountedAt)
    refreshContext(); lastTick=nil; baseline=0; nextContext=0; graceUntil=now()+3
    latestID,latestMs,latestAt=0,0,0
    -- An in-flight wrapper keeps its own stack when recording is restarted.
    if depth == 0 then
        for i=1,32 do starts[i]=0; children[i]=0 end
    end
    watcher:SetScript("OnUpdate",function() self:Tick() end)
end
function Recorder:Stop()
    if active and session then
        local at=now(); accountBoundary(at,loading or at<graceUntil); mark("stop",at)
    end
    active=false
    if db then db.enabled=false end
    if watcher then watcher:SetScript("OnUpdate",nil) end
end
local function validSession(s)
    if type(s)~="table" or type(s.version)~="string" or type(s.client)~="string" or type(s.build)~="string" then return false end
    for _,key in ipairs({"started","ended","clockStart","frames","measured","loading","unavailable","hitches","peak",
        "addonSelfTotal","addonSelfSamples","addonTotal","addonSamples","appTotal","appSamples","capFrames","capSuspectSec",
        "samplerMs","samplerPeak","bookMs","skippedDepth"}) do if not number(s[key]) then return false end end
    if type(s.hist)~="table" or #s.hist~=6 or type(s.operations)~="table" or #s.operations~=#ids then return false end
    for _, value in ipairs(s.hist) do if not number(value) or value < 0 then return false end end
    if type(s.contexts)~="table" then return false end
    for _,key in ipairs({"unknown","city","world","raid","party","scenario","arena","pvp","neighborhood","interior"}) do
        local c=s.contexts[key];if type(c)~="table" or not number(c.sec) or not number(c.hitches) then return false end
    end
    for _,r in ipairs(s.operations) do
        if type(r)~="table" then return false end
        for _,key in ipairs({"n","total","own","peak","errors","loading","over10","over50","over100","over500"}) do if not number(r[key]) then return false end end
    end
    local function validRecord(r, slow)
        if type(r) ~= "table" then return false end
        for _, key in ipairs({"at", "offset", "ms", "id"}) do
            if not number(r[key]) or r[key] < 0 then return false end
        end
        if r.id % 1 ~= 0 or r.id > #ids or (slow and r.id == 0) then return false end
        if type(r.ctx) ~= "string" or not s.contexts[r.ctx] then return false end
        if r.combat ~= "unknown" and r.combat ~= "combat" and r.combat ~= "calm" then return false end
        if slow then
            return number(r.own) ~= nil and r.own >= 0 and type(r.loading) == "boolean"
        end
        for _, key in ipairs({"aa", "all", "app"}) do
            if r[key] ~= nil and (not number(r[key]) or r[key] < 0) then return false end
        end
        return number(r.nearMs) ~= nil and number(r.nearAge) ~= nil and type(r.cap) == "boolean"
    end
    for _,key in ipairs({"recent","slow"}) do
        local r=s[key]
        if type(r)~="table" or type(r.data)~="table" or not number(r.pos) or not number(r.count)
            or r.pos%1~=0 or r.count%1~=0 or r.pos<0 or r.pos>MAX_RECENT or r.count<0 or r.count>MAX_RECENT or #r.data~=r.count then return false end
        if r.count < MAX_RECENT and r.pos ~= r.count then return false end
        if r.count > 0 and r.pos == 0 then return false end
        for _, record in ipairs(r.data) do if not validRecord(record, key == "slow") then return false end end
    end
    for _,key in ipairs({"worst","slowWorst"}) do
        if type(s[key])~="table" or #s[key]>MAX_WORST then return false end
        for _, record in ipairs(s[key]) do if not validRecord(record, key == "slowWorst") then return false end end
    end
    if s.diagnostics~=nil and s.diagnostics~=1 and s.diagnostics~=2 then return false end
    if s.diagnostics==2 then
        for _,key in ipairs({"unobserved","ticks","wrappedOwn","wrappedCalls"}) do
            if not number(s[key]) or s[key]<0 then return false end
        end
        for _,key in ipairs({"startup","nativeWorst"}) do
            if type(s[key])~="table" or #s[key]>(key=="startup" and 80 or MAX_WORST) then return false end
            for _,r in ipairs(s[key]) do
                if type(r)~="table" then return false end
                for _,field in ipairs({"offset","gap","span","own","calls","tick"}) do
                    if not number(r[field]) or r[field]<0 then return false end
                end
                if r.phase~="loading" and r.phase~="grace" and r.phase~="first" and r.phase~="measured" then return false end
                for _,field in ipairs({"aa","all","app"}) do
                    if r[field]~=nil and (not number(r[field]) or r[field]<0) then return false end
                end
                if key=="nativeWorst" and (not r.aa or r.aa<10) then return false end
            end
        end
        local r=s.lifecycle
        if type(r)~="table" or type(r.data)~="table" or not number(r.pos) or not number(r.count)
            or r.pos%1~=0 or r.count%1~=0 or r.pos<0 or r.pos>32 or r.count<0 or r.count>32
            or #r.data~=r.count or (r.count<32 and r.pos~=r.count) or (r.count>0 and r.pos==0) then return false end
        for _,v in ipairs(r.data) do
            if type(v)~="table" or type(v.kind)~="string" or not lifecycleIDs[v.kind] or not number(v.offset) or v.offset<0 then return false end
        end
    end
    return true
end
function Recorder:OnEnable()
    if initialized then return end
    initialized = true
    if type(AvidAnglerPerfDB)~="table" or AvidAnglerPerfDB.schema~=SCHEMA then
        AvidAnglerPerfDB={schema=SCHEMA,enabled=false,sessions={}}
    end
    db=AvidAnglerPerfDB
    if type(db.sessions)~="table" then db.sessions={} end
    local retained={}
    for i=math.max(1,#db.sessions-MAX_SESSIONS+1),#db.sessions do
        if validSession(db.sessions[i]) then retained[#retained+1]=db.sessions[i] end
    end
    db.sessions=retained
    db.enabled=db.enabled==true
    if not watcher then watcher=CreateFrame("Frame") end
    watcher:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_LEAVING_WORLD" then
            if active then local at=now(); accountBoundary(at,loading or at<graceUntil); mark("leaving",at) end
            loading=true; lastTick=nil
        elseif event=="PLAYER_ENTERING_WORLD" then
            local at=now()
            if active then accountBoundary(at,true); mark("entering",at) end
            loading=false; graceUntil=at+3; lastTick=nil
        elseif event=="PLAYER_LOGOUT" then
            if active then
                local at=now(); accountBoundary(at,loading or at<graceUntil); mark("logout",at)
                active=false; watcher:SetScript("OnUpdate",nil)
            end
        end
        if active then refreshContext() end
    end)
    for _, event in ipairs({"PLAYER_LEAVING_WORLD","PLAYER_ENTERING_WORLD","PLAYER_LOGOUT",
        "PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","ZONE_CHANGED_NEW_AREA"}) do watcher:RegisterEvent(event) end
    if AvidAngler.InstallPerformanceHooks then AvidAngler:InstallPerformanceHooks() end
    if db.enabled then self:Start(true) end
end
function Recorder:OnDisable()
    initialized = false
    if db then self:Stop() end
    if watcher then watcher:UnregisterAllEvents() end
end
function Recorder:GetState() return active,session,db end

function Recorder:Report()
    local L=AvidAngler.L
    local lines={L["PERF_AVID_ANGLER_PERFORMANCE_RECORDER_FORMAT"],
        L["PERF_FRAME_READINGS_ARE_SAMPLED_NEARBY_OPERATIONS"],
        L["PERF_STARTUP_DIAGNOSTICS"],
        L["PERF_SAMPLED_TIME_MAY_INCLUDE_BACKGROUND_PLAY"],
        L["PERF_OPERATION_TOTALS_ARE_SYNCHRONOUS_INCLUSIVE_OWN"],
        L["PERF_OPERATION_TOTALS_INCLUDE_LOADING_CALLS_WHICH"],
        L["PERF_MONITOR_COST_IS_INCLUDED_IN_AVIDANGLER"],
        L["PERF_LOCAL_HISTORY_SESSIONS_EACH_KEEPS_RECENT"],
        L["PERF_BUCKETS_MS_SLOW_CALLS_MS_NO"]}
    for n,s in ipairs(db.sessions) do
        lines[#lines+1]=string.format(L["PERF_SESSION_D_S_CLIENT_S_BUILD"],n,s.version,s.client,s.build,s.started,s.ended)
        lines[#lines+1]=string.format(L["PERF_SAMPLED_FS_D_FRAMES_LOADING_FS"],s.measured,s.frames,s.loading,s.unavailable,s.capFrames)
        lines[#lines+1]=string.format(L["PERF_HITCHES_D_PEAK_FMS_AVIDANGLER_ALL"],s.hitches,s.peak,s.addonSelfTotal/math.max(1,s.addonSelfSamples),s.addonTotal/math.max(1,s.addonSamples),s.appTotal/math.max(1,s.appSamples),s.addonSelfSamples,s.addonSamples,s.appSamples)
        lines[#lines+1]=string.format(L["PERF_SAMPLER_FMS_FRAME_PEAK_FMS_OPERATION"],s.samplerMs/math.max(1,s.ticks or s.frames),s.samplerPeak,s.bookMs,s.skippedDepth)
        lines[#lines+1]=string.format("possibleBackgroundCapSeconds=%.1f",s.capSuspectSec)
        lines[#lines+1]="diagnostics="..(s.diagnostics or 1)
        if s.diagnostics==2 then
            lines[#lines+1]=string.format("accountedSeconds=%.3f unobservedSeconds=%.3f ticks=%d wrappedOwnMs=%.3f wrappedCalls=%d",s.measured+s.loading+s.unobserved,s.unobserved,s.ticks,s.wrappedOwn,s.wrappedCalls)
            for j=1,s.lifecycle.count do
                local r=s.lifecycle.data[(s.lifecycle.pos-s.lifecycle.count+j-1)%32+1]
                lines[#lines+1]=string.format("lifecycle=%s offsetMs=%.3f",r.kind,r.offset)
            end
            for _,key in ipairs({"startup","nativeWorst"}) do
                for _,r in ipairs(s[key]) do
                    lines[#lines+1]=string.format("%s tick=%d offsetMs=%.3f phase=%s gapMs=%.3f accountedSpanMs=%.3f aa=%s all=%s app=%s wrappedOwnMs=%.3f wrappedCalls=%d",key,r.tick,r.offset,r.phase,r.gap,r.span,r.aa and string.format("%.3f",r.aa) or "?",r.all and string.format("%.3f",r.all) or "?",r.app and string.format("%.3f",r.app) or "?",r.own,r.calls)
                end
            end
        end
        lines[#lines+1]="hist="..table.concat(s.hist,",")
        for _,key in ipairs({"unknown","city","world","raid","party","scenario","arena","pvp","neighborhood","interior"}) do
            local c=s.contexts[key]
            if c.sec>0 then lines[#lines+1]=string.format("context=%s seconds=%.1f hitches=%d",key,c.sec,c.hitches) end
        end
        for i,r in ipairs(s.operations) do
            if r.n>0 then lines[#lines+1]=string.format("op=%s calls=%d inclusive=%.3f own=%.3f peak=%.3f errors=%d loadingCalls=%d >=10/50/100/500=%d/%d/%d/%d",ids[i],r.n,r.total,r.own,r.peak,r.errors,r.loading,r.over10,r.over50,r.over100,r.over500) end
        end
        local function frameLine(r,kind)
            return string.format("%s at=%d offsetMs=%.3f ms=%.2f aa=%s all=%s app=%s context=%s/%s nearby=%s nearMs=%.2f ageMs=%.2f capCandidate=%s",kind,r.at,r.offset,r.ms,r.aa and string.format("%.2f",r.aa) or "?",r.all and string.format("%.2f",r.all) or "?",r.app and string.format("%.2f",r.app) or "?",r.ctx,r.combat,ids[r.id] or "unknown",r.nearMs,r.nearAge,r.cap and "yes" or "no")
        end
        for _,r in ipairs(s.worst) do lines[#lines+1]=frameLine(r,"worstFrame") end
        for j=1,s.recent.count do
            local r=s.recent.data[(s.recent.pos-s.recent.count+j-1)%MAX_RECENT+1]
            lines[#lines+1]=frameLine(r,"recentFrame")
        end
        local function callLine(r,kind)
            local line = string.format("%s at=%d offsetMs=%.3f op=%s ms=%.3f own=%.3f context=%s/%s loading=%s",kind,r.at,r.offset,ids[r.id],r.ms,r.own,r.ctx,r.combat,r.loading and "yes" or "no")
            return line
        end
        for _,r in ipairs(s.slowWorst) do lines[#lines+1]=callLine(r,"worstCall") end
        for j=1,s.slow.count do
            lines[#lines+1]=callLine(s.slow.data[(s.slow.pos-s.slow.count+j-1)%MAX_RECENT+1],"recentCall")
        end
    end
    return table.concat(lines,"\n")
end
function Recorder:CanExport()
    refreshContext()
    return not loading and combat == "calm" and context ~= "unknown"
        and not AvidAngler:IsRuntimeDisabled()
end
function Recorder:Command(command)
    local L=AvidAngler.L
    refreshContext()
    if command=="start" then self:Start(); AvidAngler:Print(L["PERF_PERFORMANCE_RECORDING_STARTED_USE_AA_MONITOR"])
    elseif command=="stop" then self:Stop(); AvidAngler:Print(L["PERF_PERFORMANCE_RECORDING_STOPPED_SAVED_HISTORY_RETAINED"])
    elseif command=="reset" then AvidAngler:Print(L["PERF_USE_AA_MONITOR_RESET_CONFIRM_TO"])
    elseif command=="reset confirm" then self:Stop(); db.sessions={}; session=nil; AvidAngler:Print(L["PERF_PERFORMANCE_HISTORY_CLEARED_RECORDER_STOPPED"])
    elseif command=="export" then
        if not self:CanExport() then
            AvidAngler:Print(L["PERF_EXPORT_PERFORMANCE_HISTORY_OUTSIDE_COMBAT_AND"]); return
        end
        self:ShowExport()
    else
        AvidAngler:Print(active and L["PERF_PERFORMANCE_RECORDER_ON"] or L["PERF_PERFORMANCE_RECORDER_OFF"])
        AvidAngler:Print(L["PERF_AA_MONITOR_START_STOP_STATUS_EXPORT"])
        if session then AvidAngler:Print(string.format(L["PERF_CURRENT_RECORDING_F_MINUTES_D_HITCHES"],session.measured/60,session.hitches,session.peak)) end
    end
end
