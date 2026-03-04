-- ╔══════════════════════════════════════════════════════╗
-- ║    GLOBAL CHAT HUB v4  •  Mobile First  💜           ║
-- ║    • Menu lateral esquerdo                           ║
-- ║    • Minimizar → bolinha flutuante arrastrável       ║
-- ║    • UI compacta e otimizada pro celular             ║
-- ╚══════════════════════════════════════════════════════╝
local FIREBASE_URL = "https://scriptroblox-adede-default-rtdb.firebaseio.com"
local POLL_INT     = 3
local MAX_MSGS     = 50
local PRES_EXPIRE  = 45

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local Tween   = game:GetService("TweenService")
local Http    = game:GetService("HttpService")

local ME     = Players.LocalPlayer
local MYNAME = ME.Name
local MYUID  = ME.UserId

-- ── HTTP Detection ────────────────────────────────────────
local httpFn, httpName = nil, "none"
local useHttpSvc = false

local checks = {
    {n="request",        f=function() if typeof(request)=="function" then return request end end},
    {n="syn.request",    f=function() if syn and syn.request then return syn.request end end},
    {n="http.request",   f=function() if http and http.request then return http.request end end},
    {n="fluxus.request", f=function() if fluxus and fluxus.request then return fluxus.request end end},
    {n="http_request",   f=function() if typeof(http_request)=="function" then return http_request end end},
}
for _, c in ipairs(checks) do
    local ok, r = pcall(c.f)
    if ok and r then httpFn = r; httpName = c.n; break end
end
if not httpFn then
    if pcall(function() Http:GetAsync(FIREBASE_URL .. "/.json") end) then
        useHttpSvc = true; httpName = "HttpService"
    end
end

local function doRequest(opts)
    if useHttpSvc then
        local ok, r = pcall(function()
            if opts.Method == "GET" then return Http:GetAsync(opts.Url)
            else return Http:PostAsync(opts.Url, opts.Body or "", Enum.HttpContentType.ApplicationJson) end
        end)
        if ok then return {Success=true, StatusCode=200, Body=r} end
        return nil
    end
    if not httpFn then return nil end
    local ok, r = pcall(httpFn, opts)
    if ok then return r end
    return nil
end

-- ── Firebase helpers ──────────────────────────────────────
local function fbRaw(method, path, data)
    local opts = {Url=FIREBASE_URL..path, Method=method, Headers={["Content-Type"]="application/json"}}
    if data then opts.Body = Http:JSONEncode(data) end
    local res = doRequest(opts)
    if not res then return nil, "no_response" end
    local body = tostring(res.Body or res.body or "")
    local code = tostring(res.StatusCode or res.status_code or "0")
    if body == "" or body == "null" then return {}, nil end
    if code == "200" or res.Success then
        local ok, d = pcall(Http.JSONDecode, Http, body)
        if ok then return d, nil end
        return nil, "json_err"
    end
    return nil, "http_" .. code
end
local function fbGet(p)    return fbRaw("GET",    p) end
local function fbPost(p,d) return fbRaw("POST",   p, d) end
local function fbPut(p,d)  return fbRaw("PUT",    p, d) end
local function fbDel(p)    return fbRaw("DELETE", p) end
local function fbList(ch)
    return fbRaw("GET", "/" .. ch .. '.json?orderBy="$key"&limitToLast=' .. MAX_MSGS)
end

local function mkCode()
    local c = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; local r = ""
    for _ = 1, 6 do local i = math.random(1,#c); r = r .. c:sub(i,i) end
    return r
end
local function sfen(s) return (tostring(s):gsub("[^%w%-_]","_")) end

-- ── Avatar cache ──────────────────────────────────────────
local avCache = {}
local function fetchAvatar(uid, imgLbl)
    if not uid or uid == 0 or not imgLbl then return end
    if avCache[uid] then pcall(function() imgLbl.Image = avCache[uid] end); return end
    task.spawn(function()
        local ok, url = pcall(Players.GetUserThumbnailAsync, Players, uid,
            Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        if ok and url then
            avCache[uid] = url
            pcall(function() if imgLbl.Parent then imgLbl.Image = url end end)
        end
    end)
end

-- ── Destroy old instance ──────────────────────────────────
pcall(function()
    local cg = game:GetService("CoreGui")
    local o = cg:FindFirstChild("GlobalChatHub"); if o then o:Destroy() end
    local o2 = ME:FindFirstChild("PlayerGui") and ME.PlayerGui:FindFirstChild("GlobalChatHub")
    if o2 then o2:Destroy() end
end)

-- ── ScreenGui ─────────────────────────────────────────────
local SG = Instance.new("ScreenGui")
SG.Name = "GlobalChatHub"; SG.ResetOnSpawn = false
SG.IgnoreGuiInset = true; SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.DisplayOrder = 999
pcall(function() if syn and syn.protect_gui then syn.protect_gui(SG) end end)
if not pcall(function() SG.Parent = game:GetService("CoreGui") end) then
    SG.Parent = ME:WaitForChild("PlayerGui")
end

-- ── Detect mobile ─────────────────────────────────────────
local mob = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- ── Dimensions ────────────────────────────────────────────
local vp = workspace.CurrentCamera.ViewportSize
local WIN_W   = mob and math.min(math.floor(vp.X * 0.90), 400) or 520
local WIN_H   = mob and math.min(math.floor(vp.Y * 0.72), 480) or 470
local TITLE_H = mob and 52  or 44
local TAB_W   = mob and 56  or 50
local IN_H    = mob and 44  or 34
local FSZ     = mob and 13  or 12
local AV_SZ   = mob and 26  or 22
local BTN_SZ  = mob and 28  or 23

-- ── Colors ────────────────────────────────────────────────
local C_BG       = Color3.fromRGB(8,  6,  20)
local C_TITLE    = Color3.fromRGB(12, 8,  30)
local C_TABS_BG  = Color3.fromRGB(10, 7,  24)
local C_TAB_ON   = Color3.fromRGB(85, 50, 205)
local C_TAB_OFF  = Color3.fromRGB(17, 13, 36)
local C_SEND     = Color3.fromRGB(82, 50, 195)
local C_ACCENT   = Color3.fromRGB(72, 42, 180)
local C_INPUT    = Color3.fromRGB(13, 10, 32)

-- ══════════════════════════════════════════════════════════
-- BUBBLE (estado minimizado)
-- ══════════════════════════════════════════════════════════
local Bubble = Instance.new("ImageButton", SG)
Bubble.Name = "MiniBubble"
Bubble.Size = UDim2.new(0, 54, 0, 54)
Bubble.Position = UDim2.new(0, 14, 0.5, -27)
Bubble.BackgroundColor3 = C_ACCENT
Bubble.BorderSizePixel = 0
Bubble.Visible = false
Bubble.ZIndex = 100
Bubble.AutoButtonColor = false
Instance.new("UICorner", Bubble).CornerRadius = UDim.new(1, 0)
local bSt = Instance.new("UIStroke", Bubble)
bSt.Color = Color3.fromRGB(145, 105, 255); bSt.Thickness = 2

local bIco = Instance.new("TextLabel", Bubble)
bIco.Size = UDim2.new(1,0,1,0); bIco.BackgroundTransparency = 1
bIco.Text = "💬"; bIco.TextSize = 24; bIco.Font = Enum.Font.GothamBold
bIco.TextColor3 = Color3.new(1,1,1)

-- Badge de mensagens não lidas na bolinha
local bBadge = Instance.new("TextLabel", Bubble)
bBadge.Size = UDim2.new(0,18,0,18); bBadge.Position = UDim2.new(1,-14,0,-4)
bBadge.BackgroundColor3 = Color3.fromRGB(220,45,45); bBadge.TextColor3 = Color3.new(1,1,1)
bBadge.TextSize = 9; bBadge.Font = Enum.Font.GothamBold; bBadge.Text = ""
bBadge.BorderSizePixel = 0; bBadge.Visible = false
Instance.new("UICorner", bBadge).CornerRadius = UDim.new(1,0)

-- Pulso da bolinha
task.spawn(function()
    while SG.Parent do
        if Bubble.Visible then
            Tween:Create(Bubble, TweenInfo.new(0.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                {BackgroundColor3=Color3.fromRGB(108,65,240)}):Play()
            task.wait(0.9)
            Tween:Create(Bubble, TweenInfo.new(0.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
                {BackgroundColor3=Color3.fromRGB(58,32,145)}):Play()
        end
        task.wait(0.9)
    end
end)

-- Drag da bolinha
do
    local bd, bs, bp, bmoved = false, nil, nil, false
    Bubble.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            bd=true; bs=i.Position; bp=Bubble.Position; bmoved=false
        end
    end)
    Bubble.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            bd=false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if bd and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d = i.Position - bs
            if (math.abs(d.X)+math.abs(d.Y)) > 8 then bmoved = true end
            Bubble.Position = UDim2.new(bp.X.Scale, bp.X.Offset+d.X, bp.Y.Scale, bp.Y.Offset+d.Y)
        end
    end)
    Bubble.MouseButton1Click:Connect(function()
        if bmoved then return end -- era drag, não clique
        -- expandir
        Bubble.Visible = false
        Main.Visible = true -- Main definido abaixo, ok pois closure
        Main.Size = UDim2.new(0,0,0,0)
        Tween:Create(Main, TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
            {Size=UDim2.new(0,WIN_W,0,WIN_H)}):Play()
        bBadge.Text = ""; bBadge.Visible = false
    end)
end

-- ══════════════════════════════════════════════════════════
-- JANELA PRINCIPAL
-- ══════════════════════════════════════════════════════════
local Main = Instance.new("Frame", SG)
Main.Name = "MainWin"; Main.AnchorPoint = Vector2.new(0.5,0.5)
Main.Position = UDim2.new(0.5,0,0.5,0)
Main.Size = UDim2.new(0,0,0,0)
Main.BackgroundColor3 = C_BG; Main.BorderSizePixel = 0; Main.ClipsDescendants = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,14)
local mSt = Instance.new("UIStroke", Main); mSt.Color = C_ACCENT; mSt.Thickness = 1.5

-- Main começa invisível até o age gate ser confirmado
Main.Visible = false

-- ── BARRA DE TÍTULO ───────────────────────────────────────
local TBar = Instance.new("Frame", Main)
TBar.Size = UDim2.new(1,0,0,TITLE_H)
TBar.BackgroundColor3 = C_TITLE; TBar.BorderSizePixel = 0
Instance.new("UICorner", TBar).CornerRadius = UDim.new(0,14)
local tfix = Instance.new("Frame", TBar)
tfix.Size = UDim2.new(1,0,0.5,0); tfix.Position = UDim2.new(0,0,0.5,0)
tfix.BackgroundColor3 = C_TITLE; tfix.BorderSizePixel = 0
local tGrad = Instance.new("UIGradient", TBar)
tGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(68,40,175)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12,8,30))
}); tGrad.Rotation = 90

-- Avatar no título
local avSzT = TITLE_H - 14
local avOut = Instance.new("Frame", TBar)
avOut.Size = UDim2.new(0,avSzT,0,avSzT); avOut.Position = UDim2.new(0,9,0.5,-avSzT/2)
avOut.BackgroundColor3 = Color3.fromRGB(38,26,80); avOut.BorderSizePixel = 0
Instance.new("UICorner", avOut).CornerRadius = UDim.new(1,0)
Instance.new("UIStroke", avOut).Color = Color3.fromRGB(110,70,210)
local avI = Instance.new("ImageLabel", avOut)
avI.Size = UDim2.new(1,0,1,0); avI.BackgroundTransparency = 1; avI.ScaleType = Enum.ScaleType.Fit
Instance.new("UICorner", avI).CornerRadius = UDim.new(1,0)
fetchAvatar(MYUID, avI)

local ax = avSzT + 16
local nLbl = Instance.new("TextLabel", TBar)
nLbl.Text = MYNAME; nLbl.Position = UDim2.new(0,ax,0,5)
nLbl.Size = UDim2.new(1,-(ax+BTN_SZ*2+22),0,TITLE_H/2-3)
nLbl.BackgroundTransparency = 1; nLbl.TextColor3 = Color3.fromRGB(228,218,255)
nLbl.TextSize = mob and 14 or 13; nLbl.Font = Enum.Font.GothamBold
nLbl.TextXAlignment = Enum.TextXAlignment.Left; nLbl.TextTruncate = Enum.TextTruncate.AtEnd

local gLbl = Instance.new("TextLabel", TBar)
gLbl.Text = "🎮 " .. game.Name; gLbl.Position = UDim2.new(0,ax,0,TITLE_H/2+2)
gLbl.Size = UDim2.new(1,-(ax+BTN_SZ*2+22),0,TITLE_H/2-8)
gLbl.BackgroundTransparency = 1; gLbl.TextColor3 = Color3.fromRGB(95,80,158)
gLbl.TextSize = mob and 10 or 9; gLbl.Font = Enum.Font.Gotham
gLbl.TextXAlignment = Enum.TextXAlignment.Left; gLbl.TextTruncate = Enum.TextTruncate.AtEnd

-- Botões do título
local function mkTBtn(txt, bg, x)
    local b = Instance.new("TextButton", TBar)
    b.Text=txt; b.Size=UDim2.new(0,BTN_SZ,0,BTN_SZ)
    b.Position=UDim2.new(1,x,0.5,-BTN_SZ/2)
    b.BackgroundColor3=bg; b.TextColor3=Color3.new(1,1,1)
    b.TextSize=mob and 15 or 12; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0
    b.AutoButtonColor=false
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,7)
    b.MouseEnter:Connect(function() Tween:Create(b,TweenInfo.new(0.12),{BackgroundTransparency=0.25}):Play() end)
    b.MouseLeave:Connect(function() Tween:Create(b,TweenInfo.new(0.12),{BackgroundTransparency=0}):Play() end)
    return b
end
local MinBtn   = mkTBtn("−", Color3.fromRGB(200,145,0), -(BTN_SZ*2+13))
local CloseBtn = mkTBtn("✕", Color3.fromRGB(195,38,38), -(BTN_SZ+7))

-- ── CORPO (tabs esquerda + conteúdo direita) ──────────────
local Body = Instance.new("Frame", Main)
Body.Size = UDim2.new(1,0,1,-TITLE_H); Body.Position = UDim2.new(0,0,0,TITLE_H)
Body.BackgroundTransparency = 1; Body.ClipsDescendants = true

-- Painel lateral esquerdo (abas)
local LeftPanel = Instance.new("ScrollingFrame", Body)
LeftPanel.Size = UDim2.new(0,TAB_W,1,0)
LeftPanel.BackgroundColor3 = C_TABS_BG; LeftPanel.BorderSizePixel = 0
LeftPanel.ScrollBarThickness = 0; LeftPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
LeftPanel.ScrollingDirection = Enum.ScrollingDirection.Y
local ltl = Instance.new("UIListLayout", LeftPanel)
ltl.FillDirection = Enum.FillDirection.Vertical
ltl.HorizontalAlignment = Enum.HorizontalAlignment.Center
ltl.Padding = UDim.new(0,5)
local ltp = Instance.new("UIPadding", LeftPanel)
ltp.PaddingTop = UDim.new(0,8); ltp.PaddingBottom = UDim.new(0,8)

-- Divisor vertical
local vDiv = Instance.new("Frame", Body)
vDiv.Size = UDim2.new(0,1,1,0); vDiv.Position = UDim2.new(0,TAB_W,0,0)
vDiv.BackgroundColor3 = Color3.fromRGB(50,34,122); vDiv.BorderSizePixel = 0

-- Área de conteúdo
local Content = Instance.new("Frame", Body)
Content.Size = UDim2.new(1,-TAB_W-1,1,0); Content.Position = UDim2.new(0,TAB_W+1,0,0)
Content.BackgroundTransparency = 1; Content.ClipsDescendants = true

-- ══════════════════════════════════════════════════════════
-- SISTEMA DE ABAS
-- ══════════════════════════════════════════════════════════
local TABS = {
    {key="local",   ico="💬", lbl="Local",   fb=nil},
    {key="global",  ico="🌍", lbl="Global",  fb="global"},
    {key="brasil",  ico="🇧🇷", lbl="Brasil",  fb="brasil"},
    {key="usa",     ico="🇺🇸", lbl="USA",     fb="usa"},
    {key="privado", ico="🔒", lbl="Privado", fb=nil},
    {key="debug",   ico="🔧", lbl="Debug",   fb=nil},
}
local tabBtns  = {}
local panels   = {}
local msgCount = {}
local activeKey = nil
local unreadCount = 0

-- switchTab definida antes do loop
local function switchTab(key)
    if activeKey == key then return end
    activeKey = key
    for k, t in pairs(tabBtns) do
        local on = (k == key)
        Tween:Create(t.btn, TweenInfo.new(0.15), {BackgroundColor3 = on and C_TAB_ON or C_TAB_OFF}):Play()
        t.ico.TextColor3 = on and Color3.fromRGB(255,248,255) or Color3.fromRGB(118,105,185)
        t.lbl.TextColor3 = on and Color3.fromRGB(215,208,255) or Color3.fromRGB(80,68,135)
        -- indicador lateral
        t.ind.BackgroundTransparency = on and 0 or 1
    end
    for k, p in pairs(panels) do
        if k == key then
            p.frame.Visible = true
            p.frame.Position = UDim2.new(0.04,0,0,0)
            Tween:Create(p.frame, TweenInfo.new(0.18,Enum.EasingStyle.Quad),
                {Position=UDim2.new(0,0,0,0)}):Play()
        else
            p.frame.Visible = false
        end
    end
end

-- Cria botão de aba (vertical, lado esquerdo)
local function mkTabBtn(tab)
    local btn = Instance.new("TextButton", LeftPanel)
    btn.Name = tab.key
    local BH = mob and 62 or 54
    btn.Size = UDim2.new(1,-6,0,BH)
    btn.BackgroundColor3 = C_TAB_OFF; btn.BorderSizePixel = 0
    btn.Text = ""; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,9)

    -- Indicador ativo (barra esquerda)
    local ind = Instance.new("Frame", btn)
    ind.Size = UDim2.new(0,3,0.6,0); ind.Position = UDim2.new(0,0,0.2,0)
    ind.BackgroundColor3 = Color3.fromRGB(165,120,255); ind.BorderSizePixel = 0
    ind.BackgroundTransparency = 1
    Instance.new("UICorner", ind).CornerRadius = UDim.new(0,2)

    local ico = Instance.new("TextLabel", btn)
    ico.Size = UDim2.new(1,0,0, mob and 28 or 22)
    ico.Position = UDim2.new(0,0,0, mob and 6 or 4)
    ico.BackgroundTransparency = 1; ico.TextSize = mob and 18 or 15
    ico.Font = Enum.Font.GothamBold; ico.Text = tab.ico
    ico.TextColor3 = Color3.fromRGB(118,105,185)

    local lbl = Instance.new("TextLabel", btn)
    lbl.Size = UDim2.new(1,0,0, mob and 14 or 12)
    lbl.Position = UDim2.new(0,0,1, mob and -20 or -16)
    lbl.BackgroundTransparency = 1; lbl.TextSize = mob and 8 or 7
    lbl.Font = Enum.Font.Gotham; lbl.Text = tab.lbl
    lbl.TextColor3 = Color3.fromRGB(80,68,135)

    tabBtns[tab.key] = {btn=btn, ico=ico, lbl=lbl, ind=ind}
    btn.MouseButton1Click:Connect(function() switchTab(tab.key) end)
    return btn
end

-- Cria painel de conteúdo
local function buildPanel(key, noInput)
    msgCount[key] = 0
    local frame = Instance.new("Frame", Content)
    frame.Name = key; frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundTransparency = 1; frame.Visible = false; frame.ClipsDescendants = true

    local iH = noInput and 0 or (IN_H + 10)
    local scroll = Instance.new("ScrollingFrame", frame)
    scroll.Name = "Scroll"
    scroll.Size = UDim2.new(1,-8,1,-(iH+6))
    scroll.Position = UDim2.new(0,4,0,3)
    scroll.BackgroundColor3 = Color3.fromRGB(9,7,20); scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3; scroll.ScrollBarImageColor3 = C_ACCENT
    scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,8)
    local ll = Instance.new("UIListLayout", scroll)
    ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Padding = UDim.new(0,2)
    local sp = Instance.new("UIPadding", scroll)
    sp.PaddingLeft=UDim.new(0,5); sp.PaddingRight=UDim.new(0,5)
    sp.PaddingTop=UDim.new(0,4); sp.PaddingBottom=UDim.new(0,4)

    local inputBox, sendBtn
    if not noInput then
        local iF = Instance.new("Frame", frame)
        iF.Size = UDim2.new(1,-8,0,IN_H); iF.Position = UDim2.new(0,4,1,-(IN_H+5))
        iF.BackgroundColor3 = C_INPUT; iF.BorderSizePixel = 0
        Instance.new("UICorner", iF).CornerRadius = UDim.new(0,10)
        local iSt = Instance.new("UIStroke", iF); iSt.Color = Color3.fromRGB(58,38,148); iSt.Thickness = 1

        inputBox = Instance.new("TextBox", iF)
        inputBox.PlaceholderText = "Escreva aqui..."
        inputBox.Size = UDim2.new(1,-(IN_H+12),1,0); inputBox.Position = UDim2.new(0,10,0,0)
        inputBox.BackgroundTransparency = 1; inputBox.TextColor3 = Color3.fromRGB(215,205,255)
        inputBox.PlaceholderColor3 = Color3.fromRGB(62,52,112); inputBox.TextSize = FSZ
        inputBox.Font = Enum.Font.Gotham; inputBox.TextXAlignment = Enum.TextXAlignment.Left
        inputBox.ClearTextOnFocus = false; inputBox.MultiLine = false

        sendBtn = Instance.new("TextButton", iF)
        sendBtn.Text = "➤"; sendBtn.Size = UDim2.new(0,IN_H-4,0,IN_H-8)
        sendBtn.Position = UDim2.new(1,-(IN_H+2),0.5,-(IN_H-8)/2)
        sendBtn.BackgroundColor3 = C_SEND; sendBtn.TextColor3 = Color3.new(1,1,1)
        sendBtn.TextSize = mob and 18 or 16; sendBtn.Font = Enum.Font.GothamBold
        sendBtn.BorderSizePixel = 0; sendBtn.AutoButtonColor = false
        Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0,8)
        sendBtn.MouseEnter:Connect(function()
            Tween:Create(sendBtn,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(105,70,225)}):Play() end)
        sendBtn.MouseLeave:Connect(function()
            Tween:Create(sendBtn,TweenInfo.new(0.12),{BackgroundColor3=C_SEND}):Play() end)
    end

    panels[key] = {frame=frame, scroll=scroll, input=inputBox, send=sendBtn}
    return panels[key]
end

-- Adiciona mensagem ao painel
local function addMsg(key, user, text, uid, isSys)
    local p = panels[key]; if not p or not p.scroll then return end
    msgCount[key] = (msgCount[key] or 0) + 1
    if msgCount[key] > MAX_MSGS then
        local f = p.scroll:FindFirstChildWhichIsA("Frame")
        if f then f:Destroy(); msgCount[key] = msgCount[key] - 1 end
    end

    -- Badge na bolinha se minimizado
    if Bubble.Visible and not isSys and user ~= MYNAME then
        unreadCount = unreadCount + 1
        bBadge.Text = unreadCount > 9 and "9+" or tostring(unreadCount)
        bBadge.Visible = true
    end

    local row = Instance.new("Frame", p.scroll)
    row.Name = "msg"; row.LayoutOrder = msgCount[key]
    row.BackgroundTransparency = 1; row.BorderSizePixel = 0

    if isSys then
        row.Size = UDim2.new(1,0,0,20); row.AutomaticSize = Enum.AutomaticSize.Y
        local lb = Instance.new("TextLabel", row)
        lb.Size = UDim2.new(1,-4,0,0); lb.AutomaticSize = Enum.AutomaticSize.Y
        lb.Position = UDim2.new(0,2,0,2); lb.BackgroundTransparency = 1
        lb.TextColor3 = Color3.fromRGB(112,102,175); lb.TextSize = FSZ-1
        lb.Font = Enum.Font.GothamItalic; lb.TextWrapped = true
        lb.TextXAlignment = Enum.TextXAlignment.Center; lb.RichText = true
        lb.Text = tostring(text)
    else
        row.Size = UDim2.new(1,0,0,AV_SZ+14); row.AutomaticSize = Enum.AutomaticSize.Y
        row.BackgroundColor3 = Color3.fromRGB(22,16,48); row.BackgroundTransparency = 0.58
        Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)
        Tween:Create(row,TweenInfo.new(0.2),{BackgroundTransparency=0.72}):Play()

        local avF = Instance.new("Frame", row)
        avF.Size = UDim2.new(0,AV_SZ,0,AV_SZ); avF.Position = UDim2.new(0,5,0,6)
        avF.BackgroundColor3 = Color3.fromRGB(36,24,72); avF.BorderSizePixel = 0
        Instance.new("UICorner", avF).CornerRadius = UDim.new(1,0)
        local avImg2 = Instance.new("ImageLabel", avF)
        avImg2.Size = UDim2.new(1,0,1,0); avImg2.BackgroundTransparency = 1
        avImg2.ScaleType = Enum.ScaleType.Fit
        Instance.new("UICorner", avImg2).CornerRadius = UDim.new(1,0)
        if uid and uid ~= 0 then fetchAvatar(uid, avImg2) end

        local lx = AV_SZ + 11
        local txF = Instance.new("Frame", row)
        txF.Size = UDim2.new(1,-(lx+5),0,0); txF.AutomaticSize = Enum.AutomaticSize.Y
        txF.Position = UDim2.new(0,lx,0,5); txF.BackgroundTransparency = 1

        local nc = (user==MYNAME) and "#FFD700" or "#AE9DFF"
        local nL = Instance.new("TextLabel", txF)
        nL.Size = UDim2.new(1,0,0,14); nL.BackgroundTransparency = 1
        nL.TextSize = FSZ-1; nL.Font = Enum.Font.GothamBold
        nL.TextXAlignment = Enum.TextXAlignment.Left; nL.RichText = true
        nL.Text = ('<font color="%s">%s</font>'):format(nc, tostring(user))

        local mL = Instance.new("TextLabel", txF)
        mL.Size = UDim2.new(1,0,0,0); mL.AutomaticSize = Enum.AutomaticSize.Y
        mL.Position = UDim2.new(0,0,0,15); mL.BackgroundTransparency = 1
        mL.TextColor3 = Color3.fromRGB(202,192,242); mL.TextSize = FSZ
        mL.Font = Enum.Font.Gotham; mL.TextWrapped = true
        mL.TextXAlignment = Enum.TextXAlignment.Left; mL.Text = tostring(text)

        -- Espaço em baixo
        local pad = Instance.new("Frame", txF)
        pad.Size = UDim2.new(1,0,0,7); pad.Position = UDim2.new(0,0,1,0); pad.BackgroundTransparency = 1
    end
    task.defer(function() pcall(function() p.scroll.CanvasPosition = Vector2.new(0,99999) end) end)
end

local function sysMsg(key, txt) addMsg(key,"",txt,0,true) end

-- ── Constrói abas e painéis ───────────────────────────────
for _, tab in ipairs(TABS) do
    mkTabBtn(tab)
    local noIn = (tab.key=="local" or tab.key=="debug" or tab.key=="privado")
    buildPanel(tab.key, noIn)
end

-- ══════════════════════════════════════════════════════════
-- CHAT LOCAL
-- ══════════════════════════════════════════════════════════
sysMsg("local","✅ Chat local conectado!")
local function hookLocalChat()
    local ok = pcall(function()
        local tcs = game:GetService("TextChatService")
        if tcs.ChatVersion ~= Enum.ChatVersion.TextChatService then error() end
        tcs.MessageReceived:Connect(function(msg)
            local nm = (msg.TextSource and msg.TextSource.Name) or "?"
            local uid2 = 0; pcall(function()
                local pp = Players:FindFirstChild(nm); if pp then uid2 = pp.UserId end
            end)
            addMsg("local", nm, msg.Text, uid2)
        end)
    end)
    if ok then return end
    local function hk(p2) p2.Chatted:Connect(function(m) addMsg("local",p2.Name,m,p2.UserId) end) end
    for _, p2 in ipairs(Players:GetPlayers()) do hk(p2) end
    Players.PlayerAdded:Connect(hk)
end
task.spawn(hookLocalChat)

-- ══════════════════════════════════════════════════════════
-- CANAIS FIREBASE (global / brasil / usa)
-- ══════════════════════════════════════════════════════════
local function setupChannel(key, fb)
    local p = panels[key]; if not p then return end
    sysMsg(key, "🔗 Canal [" .. fb .. "] conectando...")

    local function enviar(txt)
        txt = txt and txt:match("^%s*(.-)%s*$") or ""
        if txt == "" then return end
        task.spawn(function()
            fbPost("/"..fb..".json", {u=MYNAME, uid=MYUID, t=txt, ts=os.time(), g=game.Name})
        end)
        if p.input then p.input.Text = "" end
    end

    if p.send  then p.send.MouseButton1Click:Connect(function() enviar(p.input and p.input.Text or "") end) end
    if p.input then p.input.FocusLost:Connect(function(enter) if enter then enviar(p.input.Text) end end) end

    task.spawn(function()
        local known = {}; local first = true
        while Main.Parent do
            task.wait(first and 0.5 or POLL_INT)
            local data, err = fbList(fb)
            if data and type(data)=="table" then
                local list = {}
                for k, v in pairs(data) do
                    if type(v)=="table" and not known[k] then
                        known[k]=true
                        table.insert(list, {ts=v.ts or 0, u=v.u or "?", t=v.t or "", uid=v.uid or 0})
                    end
                end
                table.sort(list, function(a,b) return a.ts < b.ts end)
                if first then
                    first = false
                    if #list == 0 then sysMsg(key,"📭 Vazio. Seja o primeiro!") else sysMsg(key,"✅ Conectado!") end
                end
                for _, m in ipairs(list) do addMsg(key, m.u, m.t, m.uid) end
            else
                if first then first=false; sysMsg(key,"⚠️ Erro: "..(err or "?").." | Veja 🔧 Debug") end
            end
        end
    end)
end

setupChannel("global","global")
setupChannel("brasil","brasil")
setupChannel("usa","usa")

-- ══════════════════════════════════════════════════════════
-- PRESENÇA
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
                    knownUsers[sk] = {n=info.n or sk, alive=true}
                elseif knownUsers[sk] and knownUsers[sk].alive and not fresh then
                    knownUsers[sk].alive = false
                    local nm = info.n or sk
                    for _, ch in ipairs({"global","brasil","usa"}) do sysMsg(ch,"👋 "..nm.." saiu") end
                    task.delay(30, function() fbDel("/presence/"..sk..".json") end)
                end
            end
        end
    end)
end
pushPresence()
task.spawn(function()
    while Main.Parent do task.wait(12); pushPresence(); pollPresence() end
end)

-- ══════════════════════════════════════════════════════════
-- SALA PRIVADA
-- ══════════════════════════════════════════════════════════
local privCode  = nil
local privKnown = {}

local function startPrivateRoom(code, isCreator)
    privCode = code; privKnown = {}
    local p = panels["privado"]; if not p then return end
    -- Limpa painel
    for _, c in ipairs(p.frame:GetChildren()) do c:Destroy() end

    -- Scroll
    local scroll2 = Instance.new("ScrollingFrame", p.frame)
    scroll2.Size = UDim2.new(1,-8,1,-(IN_H+36)); scroll2.Position = UDim2.new(0,4,0,30)
    scroll2.BackgroundColor3 = Color3.fromRGB(9,7,20); scroll2.BorderSizePixel = 0
    scroll2.ScrollBarThickness = 3; scroll2.ScrollBarImageColor3 = Color3.fromRGB(138,42,205)
    scroll2.CanvasSize = UDim2.new(0,0,0,0); scroll2.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", scroll2).CornerRadius = UDim.new(0,8)
    local ll2 = Instance.new("UIListLayout", scroll2)
    ll2.SortOrder = Enum.SortOrder.LayoutOrder; ll2.Padding = UDim.new(0,2)
    local sp2 = Instance.new("UIPadding", scroll2)
    sp2.PaddingLeft=UDim.new(0,5); sp2.PaddingRight=UDim.new(0,5)
    sp2.PaddingTop=UDim.new(0,4); sp2.PaddingBottom=UDim.new(0,4)
    p.scroll = scroll2; msgCount["privado"] = 0

    -- Label do código
    local cLbl = Instance.new("TextLabel", p.frame)
    cLbl.Size = UDim2.new(1,-8,0,24); cLbl.Position = UDim2.new(0,4,0,3)
    cLbl.BackgroundTransparency = 1; cLbl.TextXAlignment = Enum.TextXAlignment.Left
    cLbl.TextColor3 = Color3.fromRGB(185,162,240); cLbl.TextSize = FSZ-1; cLbl.Font = Enum.Font.Gotham
    cLbl.RichText = true
    cLbl.Text = '🔒 <font color="#FFD700"><b>'..code.."</b></font> "..(isCreator and "· você criou" or "· você entrou")

    -- Input
    local iF2 = Instance.new("Frame", p.frame)
    iF2.Size = UDim2.new(1,-8,0,IN_H); iF2.Position = UDim2.new(0,4,1,-(IN_H+5))
    iF2.BackgroundColor3 = Color3.fromRGB(13,10,32); iF2.BorderSizePixel = 0
    Instance.new("UICorner", iF2).CornerRadius = UDim.new(0,10)
    Instance.new("UIStroke", iF2).Color = Color3.fromRGB(112,36,170)

    local inBox = Instance.new("TextBox", iF2)
    inBox.PlaceholderText="Mensagem privada..."; inBox.Text=""
    inBox.Size=UDim2.new(1,-(IN_H+12),1,0); inBox.Position=UDim2.new(0,10,0,0)
    inBox.BackgroundTransparency=1; inBox.TextColor3=Color3.fromRGB(215,205,255)
    inBox.PlaceholderColor3=Color3.fromRGB(78,58,128); inBox.TextSize=FSZ
    inBox.Font=Enum.Font.Gotham; inBox.TextXAlignment=Enum.TextXAlignment.Left; inBox.ClearTextOnFocus=false

    local sBtn2 = Instance.new("TextButton", iF2)
    sBtn2.Text="➤"; sBtn2.Size=UDim2.new(0,IN_H-4,0,IN_H-8)
    sBtn2.Position=UDim2.new(1,-(IN_H+2),0.5,-(IN_H-8)/2)
    sBtn2.BackgroundColor3=Color3.fromRGB(138,36,195); sBtn2.TextColor3=Color3.new(1,1,1)
    sBtn2.TextSize=mob and 18 or 16; sBtn2.Font=Enum.Font.GothamBold
    sBtn2.BorderSizePixel=0; sBtn2.AutoButtonColor=false
    Instance.new("UICorner", sBtn2).CornerRadius=UDim.new(0,8)
    p.input=inBox; p.send=sBtn2

    local function addPS(txt)
        if not p.scroll then return end
        msgCount["privado"]=(msgCount["privado"] or 0)+1
        local row=Instance.new("Frame",p.scroll)
        row.LayoutOrder=msgCount["privado"]; row.BackgroundTransparency=1
        row.Size=UDim2.new(1,0,0,20); row.AutomaticSize=Enum.AutomaticSize.Y
        local lb=Instance.new("TextLabel",row)
        lb.Size=UDim2.new(1,-4,0,0); lb.AutomaticSize=Enum.AutomaticSize.Y
        lb.Position=UDim2.new(0,2,0,2); lb.BackgroundTransparency=1
        lb.TextColor3=Color3.fromRGB(162,78,220); lb.TextSize=FSZ-1; lb.Font=Enum.Font.GothamItalic
        lb.TextWrapped=true; lb.TextXAlignment=Enum.TextXAlignment.Center; lb.Text=tostring(txt)
        task.defer(function() pcall(function() p.scroll.CanvasPosition=Vector2.new(0,99999) end) end)
    end

    local function addPM(user, txt, uid2)
        if not p.scroll then return end
        msgCount["privado"]=(msgCount["privado"] or 0)+1
        if msgCount["privado"]>MAX_MSGS then
            local f=p.scroll:FindFirstChildWhichIsA("Frame")
            if f then f:Destroy(); msgCount["privado"]=msgCount["privado"]-1 end
        end
        local row=Instance.new("Frame",p.scroll)
        row.LayoutOrder=msgCount["privado"]; row.BackgroundTransparency=0.6
        row.Size=UDim2.new(1,0,0,AV_SZ+14); row.AutomaticSize=Enum.AutomaticSize.Y
        row.BackgroundColor3=Color3.fromRGB(24,12,48); row.BorderSizePixel=0
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
        local avF=Instance.new("Frame",row)
        avF.Size=UDim2.new(0,AV_SZ,0,AV_SZ); avF.Position=UDim2.new(0,5,0,6)
        avF.BackgroundColor3=Color3.fromRGB(42,16,78); avF.BorderSizePixel=0
        Instance.new("UICorner",avF).CornerRadius=UDim.new(1,0)
        local avIp=Instance.new("ImageLabel",avF)
        avIp.Size=UDim2.new(1,0,1,0); avIp.BackgroundTransparency=1; avIp.ScaleType=Enum.ScaleType.Fit
        Instance.new("UICorner",avIp).CornerRadius=UDim.new(1,0)
        if uid2 and uid2~=0 then fetchAvatar(uid2,avIp) end
        local lx=AV_SZ+11
        local txF=Instance.new("Frame",row)
        txF.Size=UDim2.new(1,-(lx+5),0,0); txF.AutomaticSize=Enum.AutomaticSize.Y
        txF.Position=UDim2.new(0,lx,0,5); txF.BackgroundTransparency=1
        local nc=(user==MYNAME) and "#FFD700" or "#D07AFF"
        local nl=Instance.new("TextLabel",txF); nl.Size=UDim2.new(1,0,0,14); nl.BackgroundTransparency=1
        nl.TextSize=FSZ-1; nl.Font=Enum.Font.GothamBold; nl.TextXAlignment=Enum.TextXAlignment.Left
        nl.RichText=true; nl.Text=('<font color="%s">%s</font>'):format(nc,user)
        local ml=Instance.new("TextLabel",txF); ml.Size=UDim2.new(1,0,0,0); ml.AutomaticSize=Enum.AutomaticSize.Y
        ml.Position=UDim2.new(0,0,0,15); ml.BackgroundTransparency=1
        ml.TextColor3=Color3.fromRGB(208,192,248); ml.TextSize=FSZ; ml.Font=Enum.Font.Gotham
        ml.TextWrapped=true; ml.TextXAlignment=Enum.TextXAlignment.Left; ml.Text=tostring(txt)
        task.defer(function() pcall(function() p.scroll.CanvasPosition=Vector2.new(0,99999) end) end)
    end

    local function sendP(txt)
        txt=txt and txt:match("^%s*(.-)%s*$") or ""; if txt=="" then return end
        task.spawn(function()
            fbPost("/rooms/"..code.."/msgs.json",{u=MYNAME,uid=MYUID,t=txt,ts=os.time()})
        end)
        inBox.Text=""
    end
    sBtn2.MouseButton1Click:Connect(function() sendP(inBox.Text) end)
    inBox.FocusLost:Connect(function(enter) if enter then sendP(inBox.Text) end end)

    addPS("🔒 Sala: "..code..(isCreator and " — aguarde amigo..." or " — você entrou!"))

    task.spawn(function()
        local first=true
        while Main.Parent and privCode==code do
            task.wait(first and 0.5 or POLL_INT)
            local data2,err2 = fbList("rooms/"..code.."/msgs")
            if data2 and type(data2)=="table" then
                local list2={}
                for k,v in pairs(data2) do
                    if type(v)=="table" and not privKnown[k] then
                        privKnown[k]=true
                        table.insert(list2,{ts=v.ts or 0,u=v.u or "?",t=v.t or "",uid=v.uid or 0})
                    end
                end
                table.sort(list2,function(a,b) return a.ts<b.ts end)
                if first then first=false
                    if #list2==0 then addPS("📭 Sala vazia. Manda o código pro amigo!") else addPS("✅ Sala ativa!") end
                end
                for _,m in ipairs(list2) do addPM(m.u,m.t,m.uid) end
            else
                if first then first=false; addPS("⚠️ Erro: "..(err2 or "?")) end
            end
        end
    end)
    switchTab("privado")
end

-- UI de criação/entrada na sala privada
task.defer(function()
    task.wait(0.5)
    local p = panels["privado"]; if not p then return end
    sysMsg("privado","🔒 Sala Privada Global")
    sysMsg("privado","Crie ou entre com código")

    local ctrl = Instance.new("Frame", p.frame)
    ctrl.Name = "PrivCtrl"; ctrl.AnchorPoint = Vector2.new(0.5,0.5)
    ctrl.Size = UDim2.new(0.90,0,0,0); ctrl.AutomaticSize = Enum.AutomaticSize.Y
    ctrl.Position = UDim2.new(0.5,0,0.46,0); ctrl.BackgroundTransparency = 1
    local cll = Instance.new("UIListLayout",ctrl)
    cll.FillDirection=Enum.FillDirection.Vertical; cll.Padding=UDim.new(0,10)
    cll.HorizontalAlignment=Enum.HorizontalAlignment.Center

    local cBtn = Instance.new("TextButton",ctrl)
    cBtn.Text="✨ Criar Sala Privada"; cBtn.Size=UDim2.new(1,0,0,IN_H+4)
    cBtn.BackgroundColor3=Color3.fromRGB(88,36,182); cBtn.TextColor3=Color3.new(1,1,1)
    cBtn.TextSize=mob and 13 or 12; cBtn.Font=Enum.Font.GothamBold; cBtn.BorderSizePixel=0
    cBtn.AutoButtonColor=false
    Instance.new("UICorner",cBtn).CornerRadius=UDim.new(0,10)
    cBtn.MouseEnter:Connect(function() Tween:Create(cBtn,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(112,55,215)}):Play() end)
    cBtn.MouseLeave:Connect(function() Tween:Create(cBtn,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(88,36,182)}):Play() end)

    local joinF = Instance.new("Frame",ctrl)
    joinF.Size=UDim2.new(1,0,0,IN_H+4); joinF.BackgroundColor3=Color3.fromRGB(13,10,32); joinF.BorderSizePixel=0
    Instance.new("UICorner",joinF).CornerRadius=UDim.new(0,10)
    local jSt = Instance.new("UIStroke",joinF); jSt.Color=Color3.fromRGB(78,46,162)

    local codeBox2 = Instance.new("TextBox",joinF)
    codeBox2.PlaceholderText="Código da sala..."; codeBox2.Text=""
    codeBox2.Size=UDim2.new(1,-(IN_H+16),1,0); codeBox2.Position=UDim2.new(0,10,0,0)
    codeBox2.BackgroundTransparency=1; codeBox2.TextColor3=Color3.fromRGB(220,210,255)
    codeBox2.PlaceholderColor3=Color3.fromRGB(78,64,128); codeBox2.TextSize=FSZ
    codeBox2.Font=Enum.Font.Gotham; codeBox2.TextXAlignment=Enum.TextXAlignment.Left
    codeBox2.ClearTextOnFocus=false

    local jBtn = Instance.new("TextButton",joinF)
    jBtn.Text="➤"; jBtn.Size=UDim2.new(0,IN_H-2,0,IN_H-4)
    jBtn.Position=UDim2.new(1,-(IN_H+4),0.5,-(IN_H-4)/2)
    jBtn.BackgroundColor3=Color3.fromRGB(26,112,52); jBtn.TextColor3=Color3.new(1,1,1)
    jBtn.TextSize=mob and 18 or 16; jBtn.Font=Enum.Font.GothamBold
    jBtn.BorderSizePixel=0; jBtn.AutoButtonColor=false
    Instance.new("UICorner",jBtn).CornerRadius=UDim.new(0,8)

    cBtn.MouseButton1Click:Connect(function()
        cBtn.Text="⏳ Criando..."; cBtn.Active=false
        task.spawn(function()
            local code = mkCode()
            fbPut("/rooms/"..code.."/info.json",{c=MYNAME,uid=MYUID,ts=os.time()})
            ctrl:Destroy(); startPrivateRoom(code,true)
        end)
    end)
    local function doJoin()
        local code = codeBox2.Text:upper():gsub("%s","")
        if #code < 4 then sysMsg("privado","⚠️ Código inválido!"); return end
        jBtn.Text="⏳"; jBtn.Active=false
        task.spawn(function()
            local info = fbGet("/rooms/"..code.."/info.json")
            if info and type(info)=="table" and info.c then
                ctrl:Destroy(); startPrivateRoom(code,false)
            else
                jBtn.Text="➤"; jBtn.Active=true
                sysMsg("privado","❌ Sala não encontrada!")
            end
        end)
    end
    jBtn.MouseButton1Click:Connect(doJoin)
    codeBox2.FocusLost:Connect(function(e) if e then doJoin() end end)
end)

-- ══════════════════════════════════════════════════════════
-- DEBUG
-- ══════════════════════════════════════════════════════════
local function runDiag()
    sysMsg("debug","🔍 Iniciando diagnóstico...")
    task.wait(0.1)
    addMsg("debug","HTTP","Função: "..httpName,0,false)
    if not httpFn and not useHttpSvc then
        sysMsg("debug","❌ Sem HTTP! Ative a rede/internet no executor.")
        return
    end
    sysMsg("debug","📡 Testando Firebase...")
    local res = doRequest({Url=FIREBASE_URL.."/ping.json", Method="GET"})
    if not res then sysMsg("debug","❌ Sem resposta do Firebase!"); return end
    local code = tostring(res.StatusCode or res.status_code or "?")
    local body = tostring(res.Body or res.body or "")
    if body:find("Permission denied") or code=="401" then
        sysMsg("debug","❌ Firebase bloqueado! Vá nas Regras do DB → read/write: true"); return
    end
    if code=="200" or res.Success then
        sysMsg("debug","✅ Firebase OK! Tudo funcionando.")
    else
        sysMsg("debug","⚠️ HTTP "..code.." | "..body:sub(1,50))
    end
end

task.defer(function()
    task.wait(0.5)
    sysMsg("debug","Executor: "..httpName)
    sysMsg("debug","Pressione o botão para testar a conexão.")
    local p = panels["debug"]; if not p then return end
    local db = Instance.new("TextButton",p.frame)
    db.Text="🔍 Testar Conexão"; db.Size=UDim2.new(1,-8,0,40)
    db.Position=UDim2.new(0,4,1,-45)
    db.BackgroundColor3=Color3.fromRGB(30,115,50); db.TextColor3=Color3.new(1,1,1)
    db.TextSize=mob and 13 or 12; db.Font=Enum.Font.GothamBold; db.BorderSizePixel=0
    db.AutoButtonColor=false
    Instance.new("UICorner",db).CornerRadius=UDim.new(0,10)
    db.MouseButton1Click:Connect(function()
        db.Text="Testando..."; db.BackgroundColor3=Color3.fromRGB(18,78,35)
        task.spawn(function()
            runDiag(); task.wait(2.5)
            db.Text="🔍 Testar Conexão"; db.BackgroundColor3=Color3.fromRGB(30,115,50)
        end)
    end)
end)

-- ══════════════════════════════════════════════════════════
-- ARRASTAR JANELA
-- ══════════════════════════════════════════════════════════
do
    local drag, ds, dp = false, nil, nil
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
            local d = i.Position - ds
            Main.Position = UDim2.new(dp.X.Scale, dp.X.Offset+d.X, dp.Y.Scale, dp.Y.Offset+d.Y)
        end
    end)
end

-- ══════════════════════════════════════════════════════════
-- MINIMIZAR → BOLINHA  /  FECHAR
-- ══════════════════════════════════════════════════════════
local minimized = false
local savedPos  = Main.Position

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        savedPos = Main.Position
        Tween:Create(Main, TweenInfo.new(0.28,Enum.EasingStyle.Quart,Enum.EasingDirection.In),
            {Size=UDim2.new(0,0,0,0)}):Play()
        task.delay(0.28, function()
            Main.Visible = false
            unreadCount = 0
            Bubble.Visible = true
            Bubble.Size = UDim2.new(0,0,0,0)
            Tween:Create(Bubble, TweenInfo.new(0.32,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
                {Size=UDim2.new(0,54,0,54)}):Play()
        end)
    else
        Bubble.Visible = false
        Main.Visible = true
        Main.Position = savedPos
        Main.Size = UDim2.new(0,0,0,0)
        Tween:Create(Main, TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
            {Size=UDim2.new(0,WIN_W,0,WIN_H)}):Play()
    end
    MinBtn.Text = minimized and "□" or "−"
end)

CloseBtn.MouseButton1Click:Connect(function()
    task.spawn(function() fbDel("/presence/"..myKey..".json") end)
    Tween:Create(Main, TweenInfo.new(0.22,Enum.EasingStyle.Back,Enum.EasingDirection.In),
        {Size=UDim2.new(0,0,0,0)}):Play()
    Bubble.Visible = false
    task.delay(0.25, function() SG:Destroy() end)
end)

-- ══════════════════════════════════════════════════════════
-- AGE GATE — tela de idade antes do chat abrir
-- ══════════════════════════════════════════════════════════
local function openMainChat()
    Main.Visible = true
    Main.Size = UDim2.new(0,0,0,0)
    task.delay(0.06, function()
        Tween:Create(Main, TweenInfo.new(0.42,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
            {Size=UDim2.new(0,WIN_W,0,WIN_H)}):Play()
    end)
    switchTab("local")
end

do
    -- Frame de fundo escurecido
    local overlay = Instance.new("Frame", SG)
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
    overlay.BackgroundTransparency = 0.35
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 50

    -- Card central
    local card = Instance.new("Frame", SG)
    card.AnchorPoint = Vector2.new(0.5,0.5)
    card.Position = UDim2.new(0.5,0,0.5,0)
    card.Size = UDim2.new(0,0,0,0)
    card.BackgroundColor3 = Color3.fromRGB(9,7,22)
    card.BorderSizePixel = 0
    card.ZIndex = 51
    card.ClipsDescendants = true
    Instance.new("UICorner", card).CornerRadius = UDim.new(0,16)
    local cSt = Instance.new("UIStroke", card)
    cSt.Color = Color3.fromRGB(88,52,205); cSt.Thickness = 1.8
    local cGrad = Instance.new("UIGradient", card)
    cGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(16,11,38)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8,6,20))
    }); cGrad.Rotation = 135

    local CARD_W = mob and math.min(math.floor(vp.X*0.86), 360) or 360
    local CARD_H = mob and 310 or 290

    -- Animação de entrada do card
    task.delay(0.1, function()
        Tween:Create(card, TweenInfo.new(0.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),
            {Size=UDim2.new(0,CARD_W,0,CARD_H)}):Play()
    end)

    -- Ícone 🔞
    local ico = Instance.new("TextLabel", card)
    ico.Size = UDim2.new(1,0,0, mob and 52 or 46)
    ico.Position = UDim2.new(0,0,0, mob and 18 or 14)
    ico.BackgroundTransparency = 1
    ico.Text = "🔞"; ico.TextSize = mob and 36 or 30
    ico.Font = Enum.Font.GothamBold; ico.ZIndex = 52

    -- Título
    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1,-24,0, mob and 28 or 24)
    title.Position = UDim2.new(0,12,0, mob and 68 or 58)
    title.BackgroundTransparency = 1
    title.Text = "Qual é a sua idade?"
    title.TextColor3 = Color3.fromRGB(228,218,255)
    title.TextSize = mob and 18 or 16
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 52

    -- Subtítulo
    local sub = Instance.new("TextLabel", card)
    sub.Size = UDim2.new(1,-28,0,0)
    sub.AutomaticSize = Enum.AutomaticSize.Y
    sub.Position = UDim2.new(0,14,0, mob and 100 or 88)
    sub.BackgroundTransparency = 1
    sub.Text = "ℹ️  Isso não afetará seu chat.\nVocê poderá conversar com quem quiser."
    sub.TextColor3 = Color3.fromRGB(120,108,185)
    sub.TextSize = mob and 12 or 11
    sub.Font = Enum.Font.Gotham
    sub.TextWrapped = true
    sub.TextXAlignment = Enum.TextXAlignment.Center
    sub.ZIndex = 52

    -- Faixas etárias
    local ages = {
        {lbl="Menos de 13", ico="🧒", col=Color3.fromRGB(55,110,200)},
        {lbl="13 – 17 anos", ico="🧑", col=Color3.fromRGB(72,48,185)},
        {lbl="18 anos ou +", ico="🧑‍💼", col=Color3.fromRGB(50,130,80)},
    }

    local btnY = mob and 158 or 142
    local btnH = mob and 42 or 38
    local btnGap = mob and 8 or 7
    local btnW = CARD_W - 32

    for i, age in ipairs(ages) do
        local btn = Instance.new("TextButton", card)
        btn.Size = UDim2.new(0,btnW,0,btnH)
        btn.Position = UDim2.new(0,16,0, btnY + (i-1)*(btnH+btnGap))
        btn.BackgroundColor3 = age.col
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Text = age.ico .. "  " .. age.lbl
        btn.TextSize = mob and 14 or 13
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.ZIndex = 53
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,10)

        -- Stroke sutil
        local bSt2 = Instance.new("UIStroke", btn)
        bSt2.Color = Color3.new(1,1,1); bSt2.Transparency = 0.82; bSt2.Thickness = 1

        btn.MouseEnter:Connect(function()
            Tween:Create(btn,TweenInfo.new(0.12),{BackgroundTransparency=0.22}):Play()
        end)
        btn.MouseLeave:Connect(function()
            Tween:Create(btn,TweenInfo.new(0.12),{BackgroundTransparency=0}):Play()
        end)

        btn.MouseButton1Click:Connect(function()
            -- Salva faixa escolhida (opcional: usar em tags, presença, etc.)
            _G.GCH_AgeGroup = age.lbl

            -- Anima saída do card
            Tween:Create(card, TweenInfo.new(0.28,Enum.EasingStyle.Quart,Enum.EasingDirection.In),
                {Size=UDim2.new(0,0,0,0)}):Play()
            Tween:Create(overlay, TweenInfo.new(0.28),{BackgroundTransparency=1}):Play()
            task.delay(0.3, function()
                card:Destroy(); overlay:Destroy()
                openMainChat()
            end)
        end)
    end
end

-- ══════════════════════════════════════════════════════════
-- INÍCIO
-- ══════════════════════════════════════════════════════════
print("[GlobalChatHub v4] ✅ | "..MYNAME.." | HTTP: "..httpName)
