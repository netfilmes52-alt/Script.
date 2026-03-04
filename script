-- ╔══════════════════════════════════════════════════════╗
-- ║      GLOBAL CHAT HUB v3  •  Delta Executor  💜       ║
-- ╚══════════════════════════════════════════════════════╝
local FIREBASE_URL  = "https://scriptroblox-adede-default-rtdb.firebaseio.com"
local POLL_INT      = 3
local MAX_MSGS      = 50
local PRES_EXPIRE   = 45

-- Serviços
local Players  = game:GetService("Players")
local UIS      = game:GetService("UserInputService")
local Tween    = game:GetService("TweenService")
local Http     = game:GetService("HttpService")
local RunSvc   = game:GetService("RunService")

local ME     = Players.LocalPlayer
local MYNAME = ME.Name
local MYUID  = ME.UserId
local MYGAME = tostring(game.PlaceId)

-- ── HTTP Detection ────────────────────────────────────────
local httpFn, httpName = nil, "none"
local useHttpSvc = false

local checks = {
    {n="request",         f=function() if typeof(request)=="function" then return request end end},
    {n="syn.request",     f=function() if syn and syn.request then return syn.request end end},
    {n="http.request",    f=function() if http and http.request then return http.request end end},
    {n="fluxus.request",  f=function() if fluxus and fluxus.request then return fluxus.request end end},
    {n="http_request",    f=function() if typeof(http_request)=="function" then return http_request end end},
}
for _,c in ipairs(checks) do
    local ok,r = pcall(c.f)
    if ok and r then httpFn=r; httpName=c.n; break end
end
if not httpFn then
    if pcall(function() Http:GetAsync(FIREBASE_URL.."/.json") end) then
        useHttpSvc=true; httpName="HttpService"
    end
end

local function doRequest(opts)
    if useHttpSvc then
        local ok,r = pcall(function()
            if opts.Method=="GET" then
                return Http:GetAsync(opts.Url)
            else
                return Http:PostAsync(opts.Url, opts.Body or "", Enum.HttpContentType.ApplicationJson)
            end
        end)
        if ok then return {Success=true, StatusCode=200, Body=r} end
        return nil
    end
    if not httpFn then return nil end
    local ok,r = pcall(httpFn, opts)
    if ok then return r end
    return nil
end

-- ── Firebase ──────────────────────────────────────────────
local function fbRaw(method, path, data)
    local opts = {Url=FIREBASE_URL..path, Method=method, Headers={["Content-Type"]="application/json"}}
    if data then opts.Body = Http:JSONEncode(data) end
    local res = doRequest(opts)
    if not res then return nil, "no_response" end
    local body = tostring(res.Body or res.body or "")
    local code  = tostring(res.StatusCode or res.status_code or "0")
    if body=="" or body=="null" then return {}, nil end
    if code=="200" or res.Success then
        local ok,d = pcall(Http.JSONDecode, Http, body)
        if ok then return d, nil end
        return nil, "json_err"
    end
    return nil, "http_"..code..": "..body:sub(1,60)
end

local function fbGet(p)    return fbRaw("GET",    p) end
local function fbPost(p,d) return fbRaw("POST",   p, d) end
local function fbPut(p,d)  return fbRaw("PUT",    p, d) end
local function fbDel(p)    return fbRaw("DELETE", p) end
local function fbList(ch)  return fbRaw("GET", "/"..ch..'.json?orderBy="$key"&limitToLast='..MAX_MSGS) end

local function mkCode()
    local c="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; local r=""
    for i=1,6 do r=r..c:sub(math.random(1,#c),math.random(1,#c)) end
    return r
end
local function sfen(s) return (tostring(s):gsub("[^%w%-_]","_")) end

-- ── Avatar cache ──────────────────────────────────────────
local avCache={}
local function fetchAvatar(uid, imgLbl)
    if not uid or uid==0 or not imgLbl then return end
    if avCache[uid] then pcall(function() imgLbl.Image=avCache[uid] end); return end
    task.spawn(function()
        local ok,url = pcall(Players.GetUserThumbnailAsync, Players, uid,
            Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        if ok and url then
            avCache[uid]=url
            pcall(function() if imgLbl.Parent then imgLbl.Image=url end end)
        end
    end)
end

-- ══════════════════════════════════════════════════════════
-- SCREEN GUI
-- ══════════════════════════════════════════════════════════
-- Destroy old instance
pcall(function()
    local cg = game:GetService("CoreGui")
    local old = cg:FindFirstChild("GlobalChatHub")
    if old then old:Destroy() end
    local old2 = ME:FindFirstChild("PlayerGui") and ME.PlayerGui:FindFirstChild("GlobalChatHub")
    if old2 then old2:Destroy() end
end)

local SG = Instance.new("ScreenGui")
SG.Name="GlobalChatHub"; SG.ResetOnSpawn=false
SG.IgnoreGuiInset=true; SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
SG.DisplayOrder=999
pcall(function() if syn and syn.protect_gui then syn.protect_gui(SG) end end)
if not pcall(function() SG.Parent=game:GetService("CoreGui") end) then
    SG.Parent=ME:WaitForChild("PlayerGui")
end

local mob = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- Sizes
local TITLE_H = mob and 62  or 52
local TAB_H   = mob and 44  or 36
local IN_H    = mob and 50  or 38
local FSZ     = mob and 14  or 12
local BFSZ    = mob and 11  or 10
local BTN_W   = mob and 88  or 78
local BTN_H   = mob and 32  or 26
local AV_SZ   = mob and 28  or 24  -- avatar size in messages

-- ── SPLASH ───────────────────────────────────────────────
local Splash = Instance.new("Frame", SG)
Splash.Size=UDim2.new(1,0,1,0); Splash.BackgroundColor3=Color3.fromRGB(5,3,15)
Splash.ZIndex=200; Splash.BorderSizePixel=0
Instance.new("UIGradient", Splash).Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(25,10,60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(5,3,15))
})

local splashMain = Instance.new("TextLabel", Splash)
splashMain.AnchorPoint=Vector2.new(0.5,0.5); splashMain.Position=UDim2.new(0.5,0,0.45,0)
splashMain.Size=UDim2.new(0.9,0,0,80); splashMain.BackgroundTransparency=1
splashMain.Text="✨ Feito com carinho para vocês ✨"
splashMain.TextColor3=Color3.fromRGB(200,170,255)
splashMain.TextSize=mob and 21 or 18; splashMain.Font=Enum.Font.GothamBold
splashMain.TextWrapped=true; splashMain.TextTransparency=1

local splashSub = Instance.new("TextLabel", Splash)
splashSub.AnchorPoint=Vector2.new(0.5,0.5); splashSub.Position=UDim2.new(0.5,0,0.58,0)
splashSub.Size=UDim2.new(0.7,0,0,26); splashSub.BackgroundTransparency=1
splashSub.Text="🌐 GlobalChat Hub"; splashSub.TextColor3=Color3.fromRGB(110,85,185)
splashSub.TextSize=mob and 14 or 12; splashSub.Font=Enum.Font.Gotham; splashSub.TextTransparency=1

task.spawn(function()
    task.wait(0.2)
    Tween:Create(splashMain, TweenInfo.new(0.6,Enum.EasingStyle.Quad), {TextTransparency=0}):Play()
    task.wait(0.4)
    Tween:Create(splashSub, TweenInfo.new(0.5), {TextTransparency=0}):Play()
    task.wait(2.2)
    Tween:Create(splashMain, TweenInfo.new(0.35), {TextTransparency=1}):Play()
    Tween:Create(splashSub,  TweenInfo.new(0.35), {TextTransparency=1}):Play()
    task.wait(0.2)
    Tween:Create(Splash, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play()
    for _,c in ipairs(Splash:GetChildren()) do
        if c:IsA("TextLabel") then
            Tween:Create(c, TweenInfo.new(0.4), {TextTransparency=1}):Play()
        end
    end
    task.wait(0.45); Splash:Destroy()
end)

-- ══════════════════════════════════════════════════════════
-- MAIN WINDOW
-- ══════════════════════════════════════════════════════════
local Main = Instance.new("Frame", SG)
Main.Name="MainWin"; Main.AnchorPoint=Vector2.new(0.5,0.5)
Main.Position=UDim2.new(0.5,0,0.5,0); Main.Size=UDim2.new(0,0,0,0)
Main.BackgroundColor3=Color3.fromRGB(8,6,20); Main.BorderSizePixel=0; Main.ClipsDescendants=true
Instance.new("UICorner", Main).CornerRadius=UDim.new(0,14)
local mStroke = Instance.new("UIStroke", Main); mStroke.Color=Color3.fromRGB(75,45,185); mStroke.Thickness=1.5
Instance.new("UIGradient", Main).Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(14,11,32)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(7,5,17))
})

local FINAL_W = mob and UDim2.new(0.96,0,0.88,0) or UDim2.new(0,550,0,490)
task.delay(0.1, function()
    Tween:Create(Main, TweenInfo.new(0.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out), {Size=FINAL_W}):Play()
end)

-- ── Title bar ─────────────────────────────────────────────
local TBar = Instance.new("Frame", Main)
TBar.Size=UDim2.new(1,0,0,TITLE_H); TBar.Position=UDim2.new(0,0,0,0)
TBar.BackgroundColor3=Color3.fromRGB(12,8,30); TBar.BorderSizePixel=0
Instance.new("UICorner", TBar).CornerRadius=UDim.new(0,14)
local tfix = Instance.new("Frame", TBar)  -- covers bottom rounded corners
tfix.Size=UDim2.new(1,0,0.5,0); tfix.Position=UDim2.new(0,0,0.5,0)
tfix.BackgroundColor3=Color3.fromRGB(12,8,30); tfix.BorderSizePixel=0
Instance.new("UIGradient", TBar).Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(70,42,180)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18,12,40)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12,8,30))
})

-- Avatar frame in title
local avOuter = Instance.new("Frame", TBar)
local avSzT = TITLE_H-14
avOuter.Size=UDim2.new(0,avSzT,0,avSzT); avOuter.Position=UDim2.new(0,9,0.5,-(avSzT/2))
avOuter.BackgroundColor3=Color3.fromRGB(40,28,85); avOuter.BorderSizePixel=0
Instance.new("UICorner", avOuter).CornerRadius=UDim.new(1,0)
local avSt = Instance.new("UIStroke", avOuter); avSt.Color=Color3.fromRGB(115,75,215); avSt.Thickness=2
local avImg = Instance.new("ImageLabel", avOuter)
avImg.Size=UDim2.new(1,0,1,0); avImg.BackgroundTransparency=1
avImg.ScaleType=Enum.ScaleType.Fit
Instance.new("UICorner", avImg).CornerRadius=UDim.new(1,0)
fetchAvatar(MYUID, avImg)

local ax = avSzT + 18
local nameLbl = Instance.new("TextLabel", TBar)
nameLbl.Text=MYNAME; nameLbl.Position=UDim2.new(0,ax,0,8)
nameLbl.Size=UDim2.new(1,-(ax+90),0,TITLE_H/2-4)
nameLbl.BackgroundTransparency=1; nameLbl.TextColor3=Color3.fromRGB(230,220,255)
nameLbl.TextSize=mob and 16 or 14; nameLbl.Font=Enum.Font.GothamBold
nameLbl.TextXAlignment=Enum.TextXAlignment.Left

local gameLbl = Instance.new("TextLabel", TBar)
gameLbl.Text="🎮 "..game.Name; gameLbl.Position=UDim2.new(0,ax,0,TITLE_H/2+2)
gameLbl.Size=UDim2.new(1,-(ax+90),0,TITLE_H/2-8)
gameLbl.BackgroundTransparency=1; gameLbl.TextColor3=Color3.fromRGB(100,85,165)
gameLbl.TextSize=mob and 11 or 10; gameLbl.Font=Enum.Font.Gotham
gameLbl.TextXAlignment=Enum.TextXAlignment.Left

local globeIco = Instance.new("TextLabel", TBar)
globeIco.Text="🌐"; globeIco.Size=UDim2.new(0,22,0,22)
globeIco.Position=UDim2.new(1,-(BTN_H*2+42),0.5,-11); globeIco.BackgroundTransparency=1
globeIco.TextSize=14; globeIco.Font=Enum.Font.GothamBold
task.spawn(function()
    while Main.Parent do
        Tween:Create(globeIco,TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{TextTransparency=0.6}):Play()
        task.wait(1)
        Tween:Create(globeIco,TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{TextTransparency=0}):Play()
        task.wait(1)
    end
end)

local function mkTitleBtn(txt, bg, xOff)
    local b = Instance.new("TextButton", TBar)
    b.Text=txt; b.Size=UDim2.new(0,BTN_H,0,BTN_H)
    b.Position=UDim2.new(1,xOff,0.5,-BTN_H/2)
    b.BackgroundColor3=bg; b.TextColor3=Color3.fromRGB(255,255,255)
    b.TextSize=mob and 18 or 15; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0
    Instance.new("UICorner", b).CornerRadius=UDim.new(0,7)
    return b
end
local MinBtn   = mkTitleBtn("−", Color3.fromRGB(220,160,0),  -(BTN_H*2+12))
local CloseBtn = mkTitleBtn("✕", Color3.fromRGB(210,45,45),  -(BTN_H+6))

-- ── Tab bar ───────────────────────────────────────────────
local TBar2 = Instance.new("Frame", Main)
TBar2.Size=UDim2.new(1,0,0,TAB_H); TBar2.Position=UDim2.new(0,0,0,TITLE_H)
TBar2.BackgroundColor3=Color3.fromRGB(10,7,22); TBar2.BorderSizePixel=0

local TabSF = Instance.new("ScrollingFrame", TBar2)
TabSF.Size=UDim2.new(1,0,1,0); TabSF.BackgroundTransparency=1
TabSF.ScrollBarThickness=0; TabSF.AutomaticCanvasSize=Enum.AutomaticSize.X
TabSF.ScrollingDirection=Enum.ScrollingDirection.X
local tbl = Instance.new("UIListLayout", TabSF)
tbl.FillDirection=Enum.FillDirection.Horizontal
tbl.VerticalAlignment=Enum.VerticalAlignment.Center; tbl.Padding=UDim.new(0,5)
local tbp = Instance.new("UIPadding", TabSF)
tbp.PaddingLeft=UDim.new(0,8); tbp.PaddingTop=UDim.new(0,5); tbp.PaddingBottom=UDim.new(0,5)

local divider = Instance.new("Frame", Main)
divider.Size=UDim2.new(1,0,0,1); divider.Position=UDim2.new(0,0,0,TITLE_H+TAB_H)
divider.BackgroundColor3=Color3.fromRGB(55,38,130); divider.BorderSizePixel=0

-- Content area starts right below title+tab bar
local HDR = TITLE_H + TAB_H + 1
local ContentFrame = Instance.new("Frame", Main)
ContentFrame.Name="Content"
ContentFrame.Size=UDim2.new(1,0,1,-HDR)
ContentFrame.Position=UDim2.new(0,0,0,HDR)
ContentFrame.BackgroundTransparency=1; ContentFrame.ClipsDescendants=true

-- ── Tab definitions ───────────────────────────────────────
local TABS = {
    {key="local",   lbl="💬 Local",   fb=nil,      info="Chat do servidor"},
    {key="global",  lbl="🌍 Global",  fb="global", info="Todos os servidores"},
    {key="brasil",  lbl="🇧🇷 Brasil",  fb="brasil", info="Sala Brasil"},
    {key="usa",     lbl="🇺🇸 USA",     fb="usa",    info="Sala USA"},
    {key="privado", lbl="🔒 Privado", fb=nil,      info="Sala privada"},
    {key="debug",   lbl="🔧 Debug",   fb=nil,      info="Diagnóstico"},
}

local tabBtns   = {}
local panels    = {}     -- panels[key] = { frame, scroll, input, send }
local msgCount  = {}
local activeKey = nil
local C_ON  = Color3.fromRGB(88,52,210)
local C_OFF = Color3.fromRGB(20,16,42)

-- ── Build a panel ─────────────────────────────────────────
local function buildPanel(key, noInput)
    msgCount[key] = 0
    local frame = Instance.new("Frame", ContentFrame)
    frame.Name=key; frame.Size=UDim2.new(1,0,1,0)
    frame.BackgroundTransparency=1; frame.Visible=false; frame.ClipsDescendants=true

    local iH = noInput and 0 or (IN_H+10)
    local scroll = Instance.new("ScrollingFrame", frame)
    scroll.Name="Scroll"
    scroll.Size=UDim2.new(1,-12, 1,-(iH+8))
    scroll.Position=UDim2.new(0,6,0,4)
    scroll.BackgroundColor3=Color3.fromRGB(9,7,20); scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=3; scroll.ScrollBarImageColor3=Color3.fromRGB(80,50,200)
    scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    Instance.new("UICorner", scroll).CornerRadius=UDim.new(0,10)
    local ll = Instance.new("UIListLayout", scroll)
    ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Padding=UDim.new(0,2)
    local sp = Instance.new("UIPadding", scroll)
    sp.PaddingLeft=UDim.new(0,6); sp.PaddingRight=UDim.new(0,6)
    sp.PaddingTop=UDim.new(0,5); sp.PaddingBottom=UDim.new(0,5)

    local inputBox, sendBtn
    if not noInput then
        local iFrame = Instance.new("Frame", frame)
        iFrame.Size=UDim2.new(1,-12,0,IN_H); iFrame.Position=UDim2.new(0,6,1,-(IN_H+5))
        iFrame.BackgroundColor3=Color3.fromRGB(14,11,33); iFrame.BorderSizePixel=0
        Instance.new("UICorner", iFrame).CornerRadius=UDim.new(0,10)
        local iSt = Instance.new("UIStroke", iFrame); iSt.Color=Color3.fromRGB(60,40,150); iSt.Thickness=1

        inputBox = Instance.new("TextBox", iFrame)
        inputBox.PlaceholderText="Escreva aqui..."; inputBox.Text=""
        inputBox.Size=UDim2.new(1,-90,1,0); inputBox.Position=UDim2.new(0,10,0,0)
        inputBox.BackgroundTransparency=1; inputBox.TextColor3=Color3.fromRGB(215,205,255)
        inputBox.PlaceholderColor3=Color3.fromRGB(65,55,115); inputBox.TextSize=FSZ
        inputBox.Font=Enum.Font.Gotham; inputBox.TextXAlignment=Enum.TextXAlignment.Left
        inputBox.ClearTextOnFocus=false; inputBox.MultiLine=false

        sendBtn = Instance.new("TextButton", iFrame)
        sendBtn.Text="Enviar"; sendBtn.Size=UDim2.new(0,72,0,IN_H-12)
        sendBtn.Position=UDim2.new(1,-78,0.5,-(IN_H-12)/2)
        sendBtn.BackgroundColor3=Color3.fromRGB(85,52,200); sendBtn.TextColor3=Color3.fromRGB(255,255,255)
        sendBtn.TextSize=mob and 12 or 11; sendBtn.Font=Enum.Font.GothamBold; sendBtn.BorderSizePixel=0
        Instance.new("UICorner", sendBtn).CornerRadius=UDim.new(0,8)
        sendBtn.MouseEnter:Connect(function() Tween:Create(sendBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(108,72,228)}):Play() end)
        sendBtn.MouseLeave:Connect(function() Tween:Create(sendBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(85,52,200)}):Play() end)
    end

    panels[key] = {frame=frame, scroll=scroll, input=inputBox, send=sendBtn}
    return panels[key]
end

-- ── Add message ───────────────────────────────────────────
local function addMsg(key, user, text, uid, isSys)
    local p = panels[key]; if not p or not p.scroll then return end
    msgCount[key] = (msgCount[key] or 0)+1
    if msgCount[key] > MAX_MSGS then
        local first = p.scroll:FindFirstChildWhichIsA("Frame")
        if first then first:Destroy(); msgCount[key]=msgCount[key]-1 end
    end

    local row = Instance.new("Frame", p.scroll)
    row.Name="msg"; row.LayoutOrder=msgCount[key]
    row.BackgroundTransparency=1; row.BorderSizePixel=0

    if isSys then
        row.Size=UDim2.new(1,0,0,22); row.AutomaticSize=Enum.AutomaticSize.Y
        local lbl = Instance.new("TextLabel", row)
        lbl.Size=UDim2.new(1,-6,0,0); lbl.AutomaticSize=Enum.AutomaticSize.Y
        lbl.Position=UDim2.new(0,3,0,2)
        lbl.BackgroundTransparency=1; lbl.TextColor3=Color3.fromRGB(120,110,185)
        lbl.TextSize=FSZ-1; lbl.Font=Enum.Font.GothamItalic
        lbl.TextWrapped=true; lbl.TextXAlignment=Enum.TextXAlignment.Center; lbl.RichText=true
        lbl.Text=tostring(text)
    else
        -- row with avatar + text
        row.Size=UDim2.new(1,0,0,AV_SZ+12)
        row.AutomaticSize=Enum.AutomaticSize.Y
        row.BackgroundColor3=Color3.fromRGB(26,20,52)
        row.BackgroundTransparency=0.55
        Instance.new("UICorner", row).CornerRadius=UDim.new(0,7)
        Tween:Create(row, TweenInfo.new(0.25,Enum.EasingStyle.Quad), {BackgroundTransparency=0.7}):Play()

        -- avatar
        local avF = Instance.new("Frame", row)
        avF.Size=UDim2.new(0,AV_SZ,0,AV_SZ); avF.Position=UDim2.new(0,5,0,6)
        avF.BackgroundColor3=Color3.fromRGB(38,26,75); avF.BorderSizePixel=0
        Instance.new("UICorner", avF).CornerRadius=UDim.new(1,0)
        local avI = Instance.new("ImageLabel", avF)
        avI.Size=UDim2.new(1,0,1,0); avI.BackgroundTransparency=1
        avI.ScaleType=Enum.ScaleType.Fit
        Instance.new("UICorner", avI).CornerRadius=UDim.new(1,0)
        if uid and uid~=0 then fetchAvatar(uid, avI) end

        -- text
        local txF = Instance.new("Frame", row)
        local leftOff = AV_SZ+13
        txF.Size=UDim2.new(1,-leftOff-8,0,0); txF.AutomaticSize=Enum.AutomaticSize.Y
        txF.Position=UDim2.new(0,leftOff,0,5); txF.BackgroundTransparency=1

        local nc = (user==MYNAME) and "#FFD700" or "#B09FFF"
        local nLbl = Instance.new("TextLabel", txF)
        nLbl.Size=UDim2.new(1,0,0,15); nLbl.BackgroundTransparency=1
        nLbl.TextColor3=Color3.fromRGB(190,180,240); nLbl.TextSize=FSZ-1
        nLbl.Font=Enum.Font.GothamBold; nLbl.TextXAlignment=Enum.TextXAlignment.Left
        nLbl.RichText=true; nLbl.Text=('<font color="%s">%s</font>'):format(nc,tostring(user))

        local mLbl = Instance.new("TextLabel", txF)
        mLbl.Size=UDim2.new(1,0,0,0); mLbl.AutomaticSize=Enum.AutomaticSize.Y
        mLbl.Position=UDim2.new(0,0,0,16)
        mLbl.BackgroundTransparency=1; mLbl.TextColor3=Color3.fromRGB(205,195,245)
        mLbl.TextSize=FSZ; mLbl.Font=Enum.Font.Gotham
        mLbl.TextWrapped=true; mLbl.TextXAlignment=Enum.TextXAlignment.Left
        mLbl.Text=tostring(text)

        -- bottom padding spacer
        local pad = Instance.new("Frame", txF)
        pad.Size=UDim2.new(1,0,0,6); pad.Position=UDim2.new(0,0,1,0); pad.BackgroundTransparency=1
    end

    task.defer(function() pcall(function() p.scroll.CanvasPosition=Vector2.new(0,99999) end) end)
end

local function sysMsg(key, txt)
    addMsg(key,"",txt,0,true)
end

-- ── Build tabs & buttons ──────────────────────────────────
for _,tab in ipairs(TABS) do
    local noIn = (tab.key=="local" or tab.key=="debug" or tab.key=="privado")
    buildPanel(tab.key, noIn)

    local btn = Instance.new("TextButton", TabSF)
    btn.Text=tab.lbl; btn.Size=UDim2.new(0,BTN_W,0,BTN_H)
    btn.BackgroundColor3=C_OFF; btn.TextColor3=Color3.fromRGB(115,105,165)
    btn.TextSize=BFSZ; btn.Font=Enum.Font.Gotham; btn.BorderSizePixel=0
    Instance.new("UICorner", btn).CornerRadius=UDim.new(0,7)
    tabBtns[tab.key]=btn
end

-- ── Switch tab ────────────────────────────────────────────
local function switchTab(key)
    if activeKey==key then return end
    activeKey=key
    for k,btn in pairs(tabBtns) do
        local on=(k==key)
        Tween:Create(btn,TweenInfo.new(0.18),{
            BackgroundColor3=on and C_ON or C_OFF,
            TextColor3=on and Color3.fromRGB(238,232,255) or Color3.fromRGB(115,105,165)
        }):Play()
    end
    for k,p in pairs(panels) do
        if k==key then
            p.frame.Visible=true
            p.frame.Position=UDim2.new(0.06,0,0,0)
            Tween:Create(p.frame,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{Position=UDim2.new(0,0,0,0)}):Play()
        else
            p.frame.Visible=false
        end
    end
end
for key,btn in pairs(tabBtns) do
    btn.MouseButton1Click:Connect(function() switchTab(key) end)
end

-- ══════════════════════════════════════════════════════════
-- LOCAL CHAT
-- ══════════════════════════════════════════════════════════
sysMsg("local","✅ Chat local conectado!")
local function hookLocalChat()
    local ok = pcall(function()
        if game:GetService("TextChatService").ChatVersion~=Enum.ChatVersion.TextChatService then error() end
        game:GetService("TextChatService").MessageReceived:Connect(function(msg)
            local nm=(msg.TextSource and msg.TextSource.Name) or "?"
            local uid2=0; pcall(function()
                local pp=Players:FindFirstChild(nm); if pp then uid2=pp.UserId end
            end)
            addMsg("local",nm,msg.Text,uid2)
        end)
    end)
    if ok then return end
    local function hk(p) p.Chatted:Connect(function(m) addMsg("local",p.Name,m,p.UserId) end) end
    for _,p in ipairs(Players:GetPlayers()) do hk(p) end
    Players.PlayerAdded:Connect(hk)
end
task.spawn(hookLocalChat)

-- ══════════════════════════════════════════════════════════
-- GLOBAL / BRASIL / USA
-- ══════════════════════════════════════════════════════════
local function setupChannel(key, fb)
    local p = panels[key]; if not p then return end
    sysMsg(key,"🔗 Canal: "..fb.." | Conectando...")

    local function enviar(txt)
        txt = txt and txt:match("^%s*(.-)%s*$") or ""
        if txt=="" then return end
        task.spawn(function()
            fbPost("/"..fb..".json", {u=MYNAME, uid=MYUID, t=txt, ts=os.time(), g=game.Name})
        end)
        if p.input then p.input.Text="" end
    end

    if p.send then p.send.MouseButton1Click:Connect(function() enviar(p.input and p.input.Text or "") end) end
    if p.input then p.input.FocusLost:Connect(function(enter) if enter then enviar(p.input.Text) end end) end

    task.spawn(function()
        local known={}; local first=true
        while Main.Parent do
            task.wait(first and 0.6 or POLL_INT)
            local data, err = fbList(fb)
            if data and type(data)=="table" then
                local list={}
                for k,v in pairs(data) do
                    if type(v)=="table" and not known[k] then
                        known[k]=true; table.insert(list,{ts=v.ts or 0, u=v.u or "?", t=v.t or "", uid=v.uid or 0})
                    end
                end
                table.sort(list, function(a,b) return a.ts<b.ts end)
                if first then
                    first=false
                    if #list==0 then sysMsg(key,"📭 Nenhuma mensagem. Seja o primeiro!") end
                end
                for _,m in ipairs(list) do addMsg(key, m.u, m.t, m.uid) end
            else
                if first then
                    first=false
                    sysMsg(key,"⚠️ Erro: "..(err or "?").." → vá em 🔧 Debug")
                end
            end
        end
    end)
end

setupChannel("global","global")
setupChannel("brasil","brasil")
setupChannel("usa","usa")

-- ══════════════════════════════════════════════════════════
-- PRESENÇA (saída automática)
-- ══════════════════════════════════════════════════════════
local myKey = sfen(MYNAME)
local knownUsers = {}

local function pushPresence()
    task.spawn(function()
        fbPut("/presence/"..myKey..".json", {n=MYNAME, uid=MYUID, ts=os.time(), g=game.Name})
    end)
end

local function pollPresence()
    task.spawn(function()
        local data = fbGet("/presence.json")
        if not data or type(data)~="table" then return end
        local now = os.time()
        for sk, info in pairs(data) do
            if sk~=myKey and type(info)=="table" then
                local fresh = (now-(info.ts or 0)) < PRES_EXPIRE
                if knownUsers[sk]==nil and fresh then
                    knownUsers[sk]={n=info.n or sk, alive=true}
                elseif knownUsers[sk] and knownUsers[sk].alive and not fresh then
                    knownUsers[sk].alive=false
                    local nm = info.n or sk
                    for _,ch in ipairs({"global","brasil","usa"}) do
                        sysMsg(ch,"👋 "..nm.." saiu do jogo")
                    end
                    task.delay(30, function() fbDel("/presence/"..sk..".json") end)
                end
            end
        end
    end)
end

pushPresence()
task.spawn(function()
    while Main.Parent do
        task.wait(12)
        pushPresence()
        pollPresence()
    end
end)

-- ══════════════════════════════════════════════════════════
-- SALA PRIVADA
-- ══════════════════════════════════════════════════════════
local privCode = nil
local privKnown = {}
local privPoll = false

local function startPrivateRoom(code, isCreator)
    privCode = code
    privKnown = {}
    privPoll  = false
    local p = panels["privado"]
    if not p then return end

    -- Clear panel & rebuild
    for _,c in ipairs(p.frame:GetChildren()) do
        if c:IsA("ScrollingFrame") or c:IsA("Frame") then c:Destroy() end
    end

    -- New scroll
    local scroll = Instance.new("ScrollingFrame", p.frame)
    scroll.Size=UDim2.new(1,-12,1,-(IN_H+34))
    scroll.Position=UDim2.new(0,6,0,28)
    scroll.BackgroundColor3=Color3.fromRGB(9,7,20); scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=3; scroll.ScrollBarImageColor3=Color3.fromRGB(140,45,210)
    scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    Instance.new("UICorner", scroll).CornerRadius=UDim.new(0,10)
    local ll2 = Instance.new("UIListLayout", scroll)
    ll2.SortOrder=Enum.SortOrder.LayoutOrder; ll2.Padding=UDim.new(0,2)
    local sp2 = Instance.new("UIPadding", scroll)
    sp2.PaddingLeft=UDim.new(0,6); sp2.PaddingRight=UDim.new(0,6)
    sp2.PaddingTop=UDim.new(0,5); sp2.PaddingBottom=UDim.new(0,5)
    p.scroll=scroll
    msgCount["privado"]=0

    -- Code label
    local codeLbl = Instance.new("TextLabel", p.frame)
    codeLbl.Size=UDim2.new(1,-12,0,22); codeLbl.Position=UDim2.new(0,6,0,3)
    codeLbl.BackgroundTransparency=1; codeLbl.TextXAlignment=Enum.TextXAlignment.Left
    codeLbl.TextColor3=Color3.fromRGB(180,160,240); codeLbl.TextSize=FSZ-1; codeLbl.Font=Enum.Font.Gotham
    codeLbl.RichText=true
    codeLbl.Text='🔒 Código: <font color="#FFD700"><b>'..code.."</b></font>"..(isCreator and " (você criou)" or " (você entrou)")

    -- Input
    local iFrame = Instance.new("Frame", p.frame)
    iFrame.Size=UDim2.new(1,-12,0,IN_H); iFrame.Position=UDim2.new(0,6,1,-(IN_H+5))
    iFrame.BackgroundColor3=Color3.fromRGB(14,10,34); iFrame.BorderSizePixel=0
    Instance.new("UICorner", iFrame).CornerRadius=UDim.new(0,10)
    local iSt=Instance.new("UIStroke", iFrame); iSt.Color=Color3.fromRGB(115,38,175); iSt.Thickness=1

    local inBox = Instance.new("TextBox", iFrame)
    inBox.PlaceholderText="Mensagem privada..."; inBox.Text=""
    inBox.Size=UDim2.new(1,-90,1,0); inBox.Position=UDim2.new(0,10,0,0)
    inBox.BackgroundTransparency=1; inBox.TextColor3=Color3.fromRGB(215,205,255)
    inBox.PlaceholderColor3=Color3.fromRGB(80,60,130); inBox.TextSize=FSZ
    inBox.Font=Enum.Font.Gotham; inBox.TextXAlignment=Enum.TextXAlignment.Left
    inBox.ClearTextOnFocus=false

    local sBtn = Instance.new("TextButton", iFrame)
    sBtn.Text="Enviar"; sBtn.Size=UDim2.new(0,72,0,IN_H-12)
    sBtn.Position=UDim2.new(1,-78,0.5,-(IN_H-12)/2)
    sBtn.BackgroundColor3=Color3.fromRGB(140,38,200); sBtn.TextColor3=Color3.fromRGB(255,255,255)
    sBtn.TextSize=mob and 12 or 11; sBtn.Font=Enum.Font.GothamBold; sBtn.BorderSizePixel=0
    Instance.new("UICorner", sBtn).CornerRadius=UDim.new(0,8)
    sBtn.MouseEnter:Connect(function() Tween:Create(sBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(175,55,230)}):Play() end)
    sBtn.MouseLeave:Connect(function() Tween:Create(sBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(140,38,200)}):Play() end)

    local function addPrivMsg(user, txt, uid2)
        if not p.scroll then return end
        msgCount["privado"]=(msgCount["privado"] or 0)+1
        if msgCount["privado"]>MAX_MSGS then
            local f=p.scroll:FindFirstChildWhichIsA("Frame"); if f then f:Destroy(); msgCount["privado"]=msgCount["privado"]-1 end
        end
        local row=Instance.new("Frame",p.scroll)
        row.Name="msg"; row.LayoutOrder=msgCount["privado"]
        row.Size=UDim2.new(1,0,0,AV_SZ+12); row.AutomaticSize=Enum.AutomaticSize.Y
        row.BackgroundColor3=Color3.fromRGB(26,14,50); row.BackgroundTransparency=0.55; row.BorderSizePixel=0
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
        Tween:Create(row,TweenInfo.new(0.25),{BackgroundTransparency=0.7}):Play()
        local avF=Instance.new("Frame",row)
        avF.Size=UDim2.new(0,AV_SZ,0,AV_SZ); avF.Position=UDim2.new(0,5,0,6)
        avF.BackgroundColor3=Color3.fromRGB(45,18,80); avF.BorderSizePixel=0
        Instance.new("UICorner",avF).CornerRadius=UDim.new(1,0)
        local avI=Instance.new("ImageLabel",avF); avI.Size=UDim2.new(1,0,1,0); avI.BackgroundTransparency=1
        avI.ScaleType=Enum.ScaleType.Fit; Instance.new("UICorner",avI).CornerRadius=UDim.new(1,0)
        if uid2 and uid2~=0 then fetchAvatar(uid2,avI) end
        local txF=Instance.new("Frame",row); local lx=AV_SZ+13
        txF.Size=UDim2.new(1,-lx-8,0,0); txF.AutomaticSize=Enum.AutomaticSize.Y
        txF.Position=UDim2.new(0,lx,0,5); txF.BackgroundTransparency=1
        local nc=(user==MYNAME) and "#FFD700" or "#D580FF"
        local nl=Instance.new("TextLabel",txF); nl.Size=UDim2.new(1,0,0,15); nl.BackgroundTransparency=1
        nl.TextColor3=Color3.fromRGB(190,170,240); nl.TextSize=FSZ-1; nl.Font=Enum.Font.GothamBold
        nl.TextXAlignment=Enum.TextXAlignment.Left; nl.RichText=true
        nl.Text=('<font color="%s">%s</font>'):format(nc,user)
        local ml=Instance.new("TextLabel",txF); ml.Size=UDim2.new(1,0,0,0); ml.AutomaticSize=Enum.AutomaticSize.Y
        ml.Position=UDim2.new(0,0,0,16); ml.BackgroundTransparency=1
        ml.TextColor3=Color3.fromRGB(210,195,250); ml.TextSize=FSZ; ml.Font=Enum.Font.Gotham
        ml.TextWrapped=true; ml.TextXAlignment=Enum.TextXAlignment.Left; ml.Text=tostring(txt)
        task.defer(function() pcall(function() p.scroll.CanvasPosition=Vector2.new(0,99999) end) end)
    end

    local function addPrivSys(txt)
        if not p.scroll then return end
        msgCount["privado"]=(msgCount["privado"] or 0)+1
        local row=Instance.new("Frame",p.scroll)
        row.Name="sys"; row.LayoutOrder=msgCount["privado"]
        row.Size=UDim2.new(1,0,0,22); row.AutomaticSize=Enum.AutomaticSize.Y; row.BackgroundTransparency=1
        local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-6,0,0); lbl.AutomaticSize=Enum.AutomaticSize.Y
        lbl.Position=UDim2.new(0,3,0,2); lbl.BackgroundTransparency=1; lbl.TextColor3=Color3.fromRGB(165,80,225)
        lbl.TextSize=FSZ-1; lbl.Font=Enum.Font.GothamItalic; lbl.TextWrapped=true
        lbl.TextXAlignment=Enum.TextXAlignment.Center; lbl.Text=tostring(txt)
        task.defer(function() pcall(function() p.scroll.CanvasPosition=Vector2.new(0,99999) end) end)
    end

    p.input=inBox; p.send=sBtn
    local function sendPriv(txt)
        txt=txt and txt:match("^%s*(.-)%s*$") or ""; if txt=="" then return end
        task.spawn(function()
            fbPost("/rooms/"..code.."/msgs.json",{u=MYNAME,uid=MYUID,t=txt,ts=os.time()})
        end)
        inBox.Text=""
    end
    sBtn.MouseButton1Click:Connect(function() sendPriv(inBox.Text) end)
    inBox.FocusLost:Connect(function(enter) if enter then sendPriv(inBox.Text) end end)

    addPrivSys("🔒 Sala: "..code..(isCreator and " — aguardando amigo..." or " — conectado!"))

    -- Poll
    privPoll=true
    task.spawn(function()
        local first=true
        while Main.Parent and privCode==code do
            task.wait(first and 0.7 or POLL_INT)
            local ch2="rooms/"..code.."/msgs"
            local data2,err2 = fbList(ch2)
            if data2 and type(data2)=="table" then
                local list2={}
                for k,v in pairs(data2) do
                    if type(v)=="table" and not privKnown[k] then
                        privKnown[k]=true; table.insert(list2,{ts=v.ts or 0,u=v.u or "?",t=v.t or "",uid=v.uid or 0})
                    end
                end
                table.sort(list2, function(a,b) return a.ts<b.ts end)
                if first then first=false
                    if #list2==0 then addPrivSys("📭 Sala vazia. Manda o código pro seu amigo!") end
                end
                for _,m in ipairs(list2) do addPrivMsg(m.u,m.t,m.uid) end
            else
                if first then first=false; addPrivSys("⚠️ Erro: "..(err2 or "?")) end
            end
        end
    end)

    switchTab("privado")
end

-- Private UI (create/join)
task.defer(function()
    task.wait(0.6)
    local p=panels["privado"]; if not p then return end
    sysMsg("privado","🔒 Sala privada global")

    local ctrlF = Instance.new("Frame", p.frame)
    ctrlF.Name="PrivCtrl"; ctrlF.Size=UDim2.new(1,-12,0,0); ctrlF.AutomaticSize=Enum.AutomaticSize.Y
    ctrlF.Position=UDim2.new(0,6,0.5,-60); ctrlF.BackgroundTransparency=1
    local cll = Instance.new("UIListLayout",ctrlF)
    cll.FillDirection=Enum.FillDirection.Vertical; cll.Padding=UDim.new(0,10)
    cll.HorizontalAlignment=Enum.HorizontalAlignment.Center

    local createBtn = Instance.new("TextButton", ctrlF)
    createBtn.Text="✨ Criar Sala Privada"; createBtn.Size=UDim2.new(1,0,0,IN_H)
    createBtn.BackgroundColor3=Color3.fromRGB(90,38,185); createBtn.TextColor3=Color3.fromRGB(255,255,255)
    createBtn.TextSize=mob and 14 or 12; createBtn.Font=Enum.Font.GothamBold; createBtn.BorderSizePixel=0
    Instance.new("UICorner",createBtn).CornerRadius=UDim.new(0,10)

    local joinRow = Instance.new("Frame", ctrlF)
    joinRow.Size=UDim2.new(1,0,0,IN_H); joinRow.BackgroundColor3=Color3.fromRGB(14,11,34); joinRow.BorderSizePixel=0
    Instance.new("UICorner",joinRow).CornerRadius=UDim.new(0,10)
    Instance.new("UIStroke",joinRow).Color=Color3.fromRGB(80,48,165)

    local codeBox = Instance.new("TextBox", joinRow)
    codeBox.PlaceholderText="Código da sala (ex: AB3X7K)"; codeBox.Text=""
    codeBox.Size=UDim2.new(1,-96,1,0); codeBox.Position=UDim2.new(0,10,0,0)
    codeBox.BackgroundTransparency=1; codeBox.TextColor3=Color3.fromRGB(220,210,255)
    codeBox.PlaceholderColor3=Color3.fromRGB(80,65,130); codeBox.TextSize=FSZ
    codeBox.Font=Enum.Font.Gotham; codeBox.TextXAlignment=Enum.TextXAlignment.Left; codeBox.ClearTextOnFocus=false

    local joinBtn = Instance.new("TextButton", joinRow)
    joinBtn.Text="Entrar"; joinBtn.Size=UDim2.new(0,78,0,IN_H-10)
    joinBtn.Position=UDim2.new(1,-85,0.5,-(IN_H-10)/2)
    joinBtn.BackgroundColor3=Color3.fromRGB(28,118,55); joinBtn.TextColor3=Color3.fromRGB(255,255,255)
    joinBtn.TextSize=mob and 13 or 11; joinBtn.Font=Enum.Font.GothamBold; joinBtn.BorderSizePixel=0
    Instance.new("UICorner",joinBtn).CornerRadius=UDim.new(0,8)

    createBtn.MouseButton1Click:Connect(function()
        createBtn.Text="⏳ Criando..."; createBtn.BackgroundColor3=Color3.fromRGB(55,24,120)
        task.spawn(function()
            local code = mkCode()
            fbPut("/rooms/"..code.."/info.json",{c=MYNAME,uid=MYUID,ts=os.time()})
            ctrlF:Destroy()
            startPrivateRoom(code, true)
        end)
    end)

    local function doJoin()
        local code = codeBox.Text:upper():gsub("%s","")
        if #code < 4 then sysMsg("privado","⚠️ Código inválido."); return end
        joinBtn.Text="⏳"; joinBtn.BackgroundColor3=Color3.fromRGB(18,78,35)
        task.spawn(function()
            local info = fbGet("/rooms/"..code.."/info.json")
            if info and type(info)=="table" and info.c then
                ctrlF:Destroy()
                startPrivateRoom(code, false)
            else
                joinBtn.Text="Entrar"; joinBtn.BackgroundColor3=Color3.fromRGB(28,118,55)
                sysMsg("privado","❌ Sala não encontrada. Verifique o código!")
            end
        end)
    end
    joinBtn.MouseButton1Click:Connect(doJoin)
    codeBox.FocusLost:Connect(function(e) if e then doJoin() end end)
end)

-- ══════════════════════════════════════════════════════════
-- DEBUG
-- ══════════════════════════════════════════════════════════
local function runDiag()
    sysMsg("debug","🔍 Diagnosticando...")
    task.wait(0.1)
    addMsg("debug","HTTP","Função: "..httpName,0,false)
    if not httpFn and not useHttpSvc then
        sysMsg("debug","❌ NENHUMA função HTTP! Ative rede no Delta.")
        return
    end
    sysMsg("debug","📡 Testando Firebase...")
    task.wait(0.1)
    local res = doRequest({Url=FIREBASE_URL.."/ping.json", Method="GET"})
    if not res then
        sysMsg("debug","❌ Sem resposta! Verifique internet e permissões.")
        return
    end
    local code = tostring(res.StatusCode or res.status_code or "?")
    local body = tostring(res.Body or res.body or "")
    addMsg("debug","Status","HTTP "..code,0,false)
    if body:find("Permission denied") or code=="401" then
        sysMsg("debug","❌ Firebase bloqueou! Vá em Regras → read/write: true")
        return
    end
    if code=="200" or res.Success then
        sysMsg("debug","✅ Tudo OK! Firebase respondendo.")
    else
        addMsg("debug","Resp",body:sub(1,60),0,false)
    end
end

task.defer(function()
    task.wait(0.6)
    sysMsg("debug","Clique para testar conexão.")
    addMsg("debug","Info","Executor: "..httpName,0,false)
    local p=panels["debug"]; if not p then return end
    local db = Instance.new("TextButton", p.frame)
    db.Text="🔍 Testar Conexão"; db.Size=UDim2.new(1,-12,0,40)
    db.Position=UDim2.new(0,6,1,-46)
    db.BackgroundColor3=Color3.fromRGB(32,120,52); db.TextColor3=Color3.fromRGB(255,255,255)
    db.TextSize=mob and 14 or 12; db.Font=Enum.Font.GothamBold; db.BorderSizePixel=0
    Instance.new("UICorner",db).CornerRadius=UDim.new(0,10)
    db.MouseButton1Click:Connect(function()
        db.Text="Testando..."; db.BackgroundColor3=Color3.fromRGB(20,80,35)
        task.spawn(function()
            runDiag(); task.wait(2)
            db.Text="🔍 Testar Conexão"; db.BackgroundColor3=Color3.fromRGB(32,120,52)
        end)
    end)
end)

-- ══════════════════════════════════════════════════════════
-- DRAG
-- ══════════════════════════════════════════════════════════
do
    local drag,ds,dp=false,nil,nil
    TBar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; ds=i.Position; dp=Main.Position
        end
    end)
    TBar.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-ds
            Main.Position=UDim2.new(dp.X.Scale, dp.X.Offset+d.X, dp.Y.Scale, dp.Y.Offset+d.Y)
        end
    end)
end

-- ══════════════════════════════════════════════════════════
-- MIN / CLOSE
-- ══════════════════════════════════════════════════════════
local minimized=false
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    Tween:Create(Main, TweenInfo.new(0.28,Enum.EasingStyle.Quart), {
        Size=minimized and UDim2.new(FINAL_W.X.Scale,FINAL_W.X.Offset,0,TITLE_H) or FINAL_W
    }):Play()
    MinBtn.Text=minimized and "□" or "−"
end)
CloseBtn.MouseButton1Click:Connect(function()
    task.spawn(function() fbDel("/presence/"..myKey..".json") end)
    Tween:Create(Main, TweenInfo.new(0.25,Enum.EasingStyle.Back,Enum.EasingDirection.In), {Size=UDim2.new(0,0,0,0)}):Play()
    task.delay(0.3, function() SG:Destroy() end)
end)

-- ══════════════════════════════════════════════════════════
-- START
-- ══════════════════════════════════════════════════════════
switchTab("local")
print("[GlobalChatHub v3] Loaded! User:"..MYNAME.." | HTTP:"..httpName)
