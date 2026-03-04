-- ╔══════════════════════════════════════════════════════╗
-- ║      GLOBAL CHAT HUB v4  •  Delta Executor  💜       ║
-- ╚══════════════════════════════════════════════════════╝
local FIREBASE_URL = "https://scriptroblox-adede-default-rtdb.firebaseio.com"
local POLL_INT     = 3
local MAX_MSGS     = 50
local PRES_EXPIRE  = 45

local Players  = game:GetService("Players")
local UIS      = game:GetService("UserInputService")
local Tween    = game:GetService("TweenService")
local Http     = game:GetService("HttpService")

local ME     = Players.LocalPlayer
local MYNAME = ME.Name
local MYUID  = ME.UserId
local MYGAME = game.Name

local MY_AGE  = 0  -- set by age prompt

-- ── HTTP ─────────────────────────────────────────────────
local httpFn, httpName, useHttp = nil,"none",false
for _,c in ipairs({
    {n="request",        f=function() if typeof(request)=="function" then return request end end},
    {n="syn.request",    f=function() if syn and syn.request then return syn.request end end},
    {n="http.request",   f=function() if http and http.request then return http.request end end},
    {n="fluxus.request", f=function() if fluxus and fluxus.request then return fluxus.request end end},
    {n="http_request",   f=function() if typeof(http_request)=="function" then return http_request end end},
}) do local ok,r=pcall(c.f); if ok and r then httpFn=r; httpName=c.n; break end end
if not httpFn then
    if pcall(function() Http:GetAsync(FIREBASE_URL.."/.json") end) then useHttp=true; httpName="HttpService" end
end

local function doReq(opts)
    if useHttp then
        local ok,r=pcall(function()
            return opts.Method=="GET" and Http:GetAsync(opts.Url)
                or Http:PostAsync(opts.Url,opts.Body or "",Enum.HttpContentType.ApplicationJson)
        end)
        return ok and {Success=true,StatusCode=200,Body=r} or nil
    end
    if not httpFn then return nil end
    local ok,r=pcall(httpFn,opts); return ok and r or nil
end

local function fbRaw(m,path,d)
    local opts={Url=FIREBASE_URL..path,Method=m,Headers={["Content-Type"]="application/json"}}
    if d then opts.Body=Http:JSONEncode(d) end
    local res=doReq(opts); if not res then return nil,"no_response" end
    local body=tostring(res.Body or res.body or "")
    local code=tostring(res.StatusCode or res.status_code or 0)
    if body=="" or body=="null" then return {},nil end
    if code=="200" or res.Success then
        local ok,j=pcall(Http.JSONDecode,Http,body)
        return ok and j or nil, ok and nil or "json_err"
    end
    return nil,"http_"..code..": "..body:sub(1,50)
end
local function fbGet(p)    return fbRaw("GET",p) end
local function fbPost(p,d) return fbRaw("POST",p,d) end
local function fbPut(p,d)  return fbRaw("PUT",p,d) end
local function fbDel(p)    return fbRaw("DELETE",p) end
local function fbList(ch)  return fbRaw("GET","/"..ch..'.json?orderBy="$key"&limitToLast='..MAX_MSGS) end

local function sfen(s) return (tostring(s):gsub("[^%w%-_]","_")) end
local function mkCode()
    local c="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; local r=""
    for i=1,6 do r=r..c:sub(math.random(1,#c),math.random(1,#c)) end
    return r
end

-- ── Avatar cache ──────────────────────────────────────────
local avCache={}
local function fetchAv(uid,lbl)
    if not uid or uid==0 or not lbl then return end
    if avCache[uid] then pcall(function() lbl.Image=avCache[uid] end); return end
    task.spawn(function()
        local ok,url=pcall(Players.GetUserThumbnailAsync,Players,uid,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48)
        if ok and url then avCache[uid]=url; pcall(function() if lbl and lbl.Parent then lbl.Image=url end end) end
    end)
end

-- ── Age helpers ───────────────────────────────────────────
local ageCache={}  -- uid -> age
local function isMinor(age) return age>0 and age<18 end
local function isAdult(age) return age>=18 end

-- presence store: uid -> {n, age, ts}
local knownPres={}
local reportedUsers={} -- keys already reported

-- ══════════════════════════════════════════════════════════
-- SCREEN GUI
-- ══════════════════════════════════════════════════════════
pcall(function()
    local cg=game:GetService("CoreGui"); local o=cg:FindFirstChild("GlobalChatHub"); if o then o:Destroy() end
end)
pcall(function()
    local pg=ME:FindFirstChild("PlayerGui"); if pg then local o=pg:FindFirstChild("GlobalChatHub"); if o then o:Destroy() end end
end)

local SG=Instance.new("ScreenGui")
SG.Name="GlobalChatHub"; SG.ResetOnSpawn=false; SG.IgnoreGuiInset=true
SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; SG.DisplayOrder=999
pcall(function() if syn and syn.protect_gui then syn.protect_gui(SG) end end)
if not pcall(function() SG.Parent=game:GetService("CoreGui") end) then
    SG.Parent=ME:WaitForChild("PlayerGui")
end

local mob=UIS.TouchEnabled and not UIS.KeyboardEnabled

-- Fixed pixel sizes that work on all screens
local WIN_W  = mob and math.floor(workspace.CurrentCamera.ViewportSize.X*0.96) or 550
local WIN_H  = mob and math.floor(workspace.CurrentCamera.ViewportSize.Y*0.87) or 490
local TH     = mob and 62 or 52
local TABH   = mob and 44 or 36
local INH    = mob and 50 or 38
local FSZ    = mob and 14 or 12
local BFSZ   = mob and 11 or 10
local BTN_W  = mob and 85 or 76
local BTN_H  = mob and 30 or 26
local AV     = mob and 30 or 26   -- message avatar size
local HDR    = TH + TABH + 1     -- header height

-- ── HELPERS ───────────────────────────────────────────────
local function mkCorner(p,r) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 10); return c end
local function mkStroke(p,col,t) local s=Instance.new("UIStroke",p); s.Color=col; s.Thickness=t or 1; return s end
local function mkGrad(p,c0,c1,rot)
    local g=Instance.new("UIGradient",p)
    g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,c0),ColorSequenceKeypoint.new(1,c1)})
    if rot then g.Rotation=rot end
    return g
end

-- ══════════════════════════════════════════════════════════
-- MAIN WINDOW
-- ══════════════════════════════════════════════════════════
local Main=Instance.new("Frame",SG)
Main.Name="Main"; Main.AnchorPoint=Vector2.new(0.5,0.5)
Main.Position=UDim2.new(0.5,0,0.5,0)
Main.Size=UDim2.new(0,WIN_W,0,WIN_H)
Main.BackgroundColor3=Color3.fromRGB(8,6,20); Main.BorderSizePixel=0
Main.ClipsDescendants=true
mkCorner(Main,14)
mkStroke(Main,Color3.fromRGB(75,44,188),1.5)
mkGrad(Main,Color3.fromRGB(14,11,32),Color3.fromRGB(7,5,17))

-- ── TITLE BAR ─────────────────────────────────────────────
local TBar=Instance.new("Frame",Main)
TBar.Size=UDim2.new(1,0,0,TH); TBar.Position=UDim2.new(0,0,0,0)
TBar.BackgroundColor3=Color3.fromRGB(12,8,30); TBar.BorderSizePixel=0
mkCorner(TBar,14)
-- fix bottom radius
local tfix=Instance.new("Frame",TBar); tfix.Size=UDim2.new(1,0,0.5,0); tfix.Position=UDim2.new(0,0,0.5,0)
tfix.BackgroundColor3=Color3.fromRGB(12,8,30); tfix.BorderSizePixel=0
mkGrad(TBar,Color3.fromRGB(68,40,178),Color3.fromRGB(12,8,30))

-- Avatar in title
local avSz=TH-16
local avOuter=Instance.new("Frame",TBar)
avOuter.Size=UDim2.new(0,avSz,0,avSz); avOuter.Position=UDim2.new(0,9,0.5,-(avSz/2))
avOuter.BackgroundColor3=Color3.fromRGB(40,26,85); avOuter.BorderSizePixel=0
mkCorner(avOuter,avSz); mkStroke(avOuter,Color3.fromRGB(112,72,212),2)
local avImg=Instance.new("ImageLabel",avOuter)
avImg.Size=UDim2.new(1,0,1,0); avImg.BackgroundTransparency=1; avImg.ScaleType=Enum.ScaleType.Fit
mkCorner(avImg,avSz)
fetchAv(MYUID,avImg)

local ax=avSz+20
local nLbl=Instance.new("TextLabel",TBar)
nLbl.Text=MYNAME; nLbl.Position=UDim2.new(0,ax,0,8); nLbl.Size=UDim2.new(1,-(ax+90),0,20)
nLbl.BackgroundTransparency=1; nLbl.TextColor3=Color3.fromRGB(230,220,255)
nLbl.TextSize=mob and 16 or 14; nLbl.Font=Enum.Font.GothamBold; nLbl.TextXAlignment=Enum.TextXAlignment.Left

local ageLbl=Instance.new("TextLabel",TBar)
ageLbl.Text="🎮 "..MYGAME; ageLbl.Position=UDim2.new(0,ax,0,TH/2+2); ageLbl.Size=UDim2.new(1,-(ax+90),0,16)
ageLbl.BackgroundTransparency=1; ageLbl.TextColor3=Color3.fromRGB(100,85,165)
ageLbl.TextSize=mob and 11 or 10; ageLbl.Font=Enum.Font.Gotham; ageLbl.TextXAlignment=Enum.TextXAlignment.Left

-- Globe icon
local gico=Instance.new("TextLabel",TBar); gico.Text="🌐"; gico.Size=UDim2.new(0,22,0,22)
gico.Position=UDim2.new(1,-(BTN_H*2+42),0.5,-11); gico.BackgroundTransparency=1; gico.TextSize=14; gico.Font=Enum.Font.GothamBold
task.spawn(function()
    while Main.Parent do
        Tween:Create(gico,TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{TextTransparency=0.7}):Play(); task.wait(1)
        Tween:Create(gico,TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{TextTransparency=0}):Play(); task.wait(1)
    end
end)

-- Min/Close buttons
local function mkTBtn(txt,bg,xOff)
    local b=Instance.new("TextButton",TBar)
    b.Text=txt; b.Size=UDim2.new(0,BTN_H,0,BTN_H); b.Position=UDim2.new(1,xOff,0.5,-BTN_H/2)
    b.BackgroundColor3=bg; b.TextColor3=Color3.fromRGB(255,255,255)
    b.TextSize=mob and 18 or 14; b.Font=Enum.Font.GothamBold; b.BorderSizePixel=0; mkCorner(b,7); return b
end
local MinBtn   = mkTBtn("−",Color3.fromRGB(220,160,0),  -(BTN_H*2+12))
local CloseBtn = mkTBtn("✕",Color3.fromRGB(210,42,42),  -(BTN_H+6))

-- ── TAB BAR ───────────────────────────────────────────────
local TabBg=Instance.new("Frame",Main)
TabBg.Size=UDim2.new(1,0,0,TABH); TabBg.Position=UDim2.new(0,0,0,TH)
TabBg.BackgroundColor3=Color3.fromRGB(10,7,22); TabBg.BorderSizePixel=0

local TabSF=Instance.new("ScrollingFrame",TabBg)
TabSF.Size=UDim2.new(1,0,1,0); TabSF.BackgroundTransparency=1
TabSF.ScrollBarThickness=0; TabSF.AutomaticCanvasSize=Enum.AutomaticSize.X
TabSF.ScrollingDirection=Enum.ScrollingDirection.X
local tbl=Instance.new("UIListLayout",TabSF)
tbl.FillDirection=Enum.FillDirection.Horizontal; tbl.VerticalAlignment=Enum.VerticalAlignment.Center; tbl.Padding=UDim.new(0,5)
local tbp=Instance.new("UIPadding",TabSF); tbp.PaddingLeft=UDim.new(0,8); tbp.PaddingTop=UDim.new(0,5); tbp.PaddingBottom=UDim.new(0,5)

local divLine=Instance.new("Frame",Main)
divLine.Size=UDim2.new(1,0,0,1); divLine.Position=UDim2.new(0,0,0,TH+TABH)
divLine.BackgroundColor3=Color3.fromRGB(52,36,128); divLine.BorderSizePixel=0

-- ── CONTENT AREA (absolute pixel position & size) ─────────
local ContentH = WIN_H - HDR
local CFrame=Instance.new("Frame",Main)
CFrame.Name="Content"; CFrame.Size=UDim2.new(0,WIN_W,0,ContentH)
CFrame.Position=UDim2.new(0,0,0,HDR)
CFrame.BackgroundTransparency=1; CFrame.ClipsDescendants=true

-- ══════════════════════════════════════════════════════════
-- PANEL SYSTEM
-- ══════════════════════════════════════════════════════════
local TABS={
    {key="local",   lbl="💬 Local",   fb=nil,      sys="Chat do servidor"},
    {key="global",  lbl="🌍 Global",  fb="global", sys="Canal global"},
    {key="brasil",  lbl="🇧🇷 Brasil",  fb="brasil", sys="Sala Brasil"},
    {key="usa",     lbl="🇺🇸 USA",     fb="usa",    sys="Sala USA"},
    {key="privado", lbl="🔒 Privado", fb=nil,      sys="Sala privada"},
    {key="debug",   lbl="🔧 Debug",   fb=nil,      sys="Diagnóstico"},
}
local tabBtns={}; local panels={}; local msgCount={}; local activeKey=nil
local C_ON=Color3.fromRGB(88,50,212); local C_OFF=Color3.fromRGB(20,15,42)

local function buildPanel(key,noInput)
    msgCount[key]=0
    local pW=WIN_W; local pHContent=ContentH
    local iH=noInput and 0 or (INH+10)

    local fr=Instance.new("Frame",CFrame)
    fr.Name=key; fr.Size=UDim2.new(0,pW,0,pHContent)
    fr.Position=UDim2.new(0,0,0,0)
    fr.BackgroundTransparency=1; fr.Visible=false; fr.ClipsDescendants=true

    local scH=pHContent-(iH+10)
    local scroll=Instance.new("ScrollingFrame",fr)
    scroll.Name="Scroll"; scroll.Size=UDim2.new(0,pW-12,0,scH)
    scroll.Position=UDim2.new(0,6,0,4)
    scroll.BackgroundColor3=Color3.fromRGB(9,7,20); scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=3; scroll.ScrollBarImageColor3=Color3.fromRGB(80,48,200)
    scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    mkCorner(scroll,10)
    local ll=Instance.new("UIListLayout",scroll); ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Padding=UDim.new(0,2)
    local sp=Instance.new("UIPadding",scroll)
    sp.PaddingLeft=UDim.new(0,6); sp.PaddingRight=UDim.new(0,6); sp.PaddingTop=UDim.new(0,5); sp.PaddingBottom=UDim.new(0,5)

    local inputBox,sendBtn
    if not noInput then
        local iF=Instance.new("Frame",fr)
        iF.Size=UDim2.new(0,pW-12,0,INH); iF.Position=UDim2.new(0,6,0,scH+6)
        iF.BackgroundColor3=Color3.fromRGB(13,10,32); iF.BorderSizePixel=0; mkCorner(iF,10); mkStroke(iF,Color3.fromRGB(58,38,148))

        inputBox=Instance.new("TextBox",iF)
        inputBox.PlaceholderText="Escreva aqui..."; inputBox.Text=""
        inputBox.Size=UDim2.new(1,-90,1,0); inputBox.Position=UDim2.new(0,10,0,0)
        inputBox.BackgroundTransparency=1; inputBox.TextColor3=Color3.fromRGB(215,205,255)
        inputBox.PlaceholderColor3=Color3.fromRGB(65,55,115); inputBox.TextSize=FSZ
        inputBox.Font=Enum.Font.Gotham; inputBox.TextXAlignment=Enum.TextXAlignment.Left
        inputBox.ClearTextOnFocus=false; inputBox.MultiLine=false

        sendBtn=Instance.new("TextButton",iF)
        sendBtn.Text="Enviar"; sendBtn.Size=UDim2.new(0,72,0,INH-12)
        sendBtn.Position=UDim2.new(1,-78,0.5,-(INH-12)/2)
        sendBtn.BackgroundColor3=Color3.fromRGB(85,50,200); sendBtn.TextColor3=Color3.fromRGB(255,255,255)
        sendBtn.TextSize=mob and 12 or 11; sendBtn.Font=Enum.Font.GothamBold; sendBtn.BorderSizePixel=0; mkCorner(sendBtn,8)
        sendBtn.MouseEnter:Connect(function() Tween:Create(sendBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(108,70,228)}):Play() end)
        sendBtn.MouseLeave:Connect(function() Tween:Create(sendBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(85,50,200)}):Play() end)
    end

    panels[key]={fr=fr,scroll=scroll,input=inputBox,send=sendBtn}
    return panels[key]
end

-- ── Add message ───────────────────────────────────────────
local function addMsg(key,user,text,uid,senderAge,isSys)
    local p=panels[key]; if not p or not p.scroll then return end
    msgCount[key]=(msgCount[key] or 0)+1
    if msgCount[key]>MAX_MSGS then
        local old=p.scroll:FindFirstChildWhichIsA("Frame"); if old then old:Destroy(); msgCount[key]=msgCount[key]-1 end
    end
    local row=Instance.new("Frame",p.scroll)
    row.Name="msg"; row.LayoutOrder=msgCount[key]; row.BorderSizePixel=0

    if isSys then
        row.Size=UDim2.new(1,0,0,0); row.AutomaticSize=Enum.AutomaticSize.Y; row.BackgroundTransparency=1
        local lbl=Instance.new("TextLabel",row)
        lbl.Size=UDim2.new(1,-6,0,0); lbl.AutomaticSize=Enum.AutomaticSize.Y; lbl.Position=UDim2.new(0,3,0,2)
        lbl.BackgroundTransparency=1; lbl.TextColor3=Color3.fromRGB(118,108,182)
        lbl.TextSize=FSZ-1; lbl.Font=Enum.Font.GothamItalic; lbl.TextWrapped=true
        lbl.TextXAlignment=Enum.TextXAlignment.Center; lbl.Text=tostring(text)
    else
        -- check age warning
        local showAgeWarn = false
        local myIsMinor   = isMinor(MY_AGE)
        local myIsAdult   = isAdult(MY_AGE)
        local sndrMinor   = isMinor(senderAge or 0)
        local sndrAdult   = isAdult(senderAge or 0)
        if user~=MYNAME and MY_AGE>0 and (senderAge or 0)>0 then
            if myIsMinor and sndrAdult then showAgeWarn=true end
            if myIsAdult and sndrMinor then showAgeWarn=true end
        end

        row.Size=UDim2.new(1,0,0,0); row.AutomaticSize=Enum.AutomaticSize.Y
        row.BackgroundColor3=Color3.fromRGB(24,18,50); row.BackgroundTransparency=0.6
        mkCorner(row,8)

        -- age warning banner
        if showAgeWarn then
            local wb=Instance.new("Frame",row)
            wb.Size=UDim2.new(1,-10,0,0); wb.AutomaticSize=Enum.AutomaticSize.Y; wb.Position=UDim2.new(0,5,0,4)
            wb.BackgroundColor3=Color3.fromRGB(180,80,20); wb.BackgroundTransparency=0.3; wb.BorderSizePixel=0; mkCorner(wb,6)
            local wt=Instance.new("TextLabel",wb)
            wt.Size=UDim2.new(1,-8,0,0); wt.AutomaticSize=Enum.AutomaticSize.Y; wt.Position=UDim2.new(0,4,0,3)
            wt.BackgroundTransparency=1; wt.TextColor3=Color3.fromRGB(255,220,100)
            wt.TextSize=FSZ-1; wt.Font=Enum.Font.GothamBold; wt.TextWrapped=true; wt.TextXAlignment=Enum.TextXAlignment.Left
            if myIsMinor then
                wt.Text="⚠️ Este usuário é adulto ("..tostring(senderAge).." anos). Tome cuidado!"
            else
                wt.Text="⚠️ Este usuário é menor de idade ("..tostring(senderAge).." anos)."
            end
            local spacer=Instance.new("Frame",wb); spacer.Size=UDim2.new(1,0,0,4); spacer.Position=UDim2.new(0,0,1,0); spacer.BackgroundTransparency=1
        end

        -- message body
        local body=Instance.new("Frame",row)
        local yOff=showAgeWarn and (20+(FSZ*2)) or 0
        body.Size=UDim2.new(1,0,0,0); body.AutomaticSize=Enum.AutomaticSize.Y
        body.Position=UDim2.new(0,0,0,yOff); body.BackgroundTransparency=1

        local avF=Instance.new("Frame",body); avF.Size=UDim2.new(0,AV,0,AV); avF.Position=UDim2.new(0,6,0,6)
        avF.BackgroundColor3=Color3.fromRGB(36,24,72); avF.BorderSizePixel=0; mkCorner(avF,AV)
        local avI=Instance.new("ImageLabel",avF); avI.Size=UDim2.new(1,0,1,0); avI.BackgroundTransparency=1; avI.ScaleType=Enum.ScaleType.Fit; mkCorner(avI,AV)
        if uid and uid~=0 then fetchAv(uid,avI) end

        local lx=AV+15
        local txF=Instance.new("Frame",body); txF.Size=UDim2.new(1,-lx-8,0,0); txF.AutomaticSize=Enum.AutomaticSize.Y
        txF.Position=UDim2.new(0,lx,0,5); txF.BackgroundTransparency=1

        local nc=(user==MYNAME) and "#FFD700" or "#B09FFF"
        local ageStr=(senderAge and senderAge>0) and (" <font color='#888'>("..(senderAge)..")</font>") or ""
        local nl=Instance.new("TextLabel",txF); nl.Size=UDim2.new(1,0,0,14); nl.BackgroundTransparency=1
        nl.TextColor3=Color3.fromRGB(188,178,238); nl.TextSize=FSZ-1; nl.Font=Enum.Font.GothamBold
        nl.TextXAlignment=Enum.TextXAlignment.Left; nl.RichText=true
        nl.Text=('<font color="%s">%s</font>%s'):format(nc,tostring(user),ageStr)

        local ml=Instance.new("TextLabel",txF); ml.Size=UDim2.new(1,0,0,0); ml.AutomaticSize=Enum.AutomaticSize.Y
        ml.Position=UDim2.new(0,0,0,15); ml.BackgroundTransparency=1
        ml.TextColor3=Color3.fromRGB(205,195,245); ml.TextSize=FSZ; ml.Font=Enum.Font.Gotham
        ml.TextWrapped=true; ml.TextXAlignment=Enum.TextXAlignment.Left; ml.Text=tostring(text)

        -- Report button (show if warning, or always on hover for safety)
        if showAgeWarn or (user~=MYNAME) then
            local rBtn=Instance.new("TextButton",txF)
            rBtn.Text="🚨 Reportar"; rBtn.Size=UDim2.new(0,80,0,18)
            rBtn.Position=UDim2.new(0,0,1,4)
            rBtn.BackgroundColor3=Color3.fromRGB(160,30,30); rBtn.TextColor3=Color3.fromRGB(255,210,210)
            rBtn.TextSize=FSZ-2; rBtn.Font=Enum.Font.GothamBold; rBtn.BorderSizePixel=0; mkCorner(rBtn,5)
            if not showAgeWarn then rBtn.BackgroundTransparency=0.7; rBtn.TextTransparency=0.5 end
            rBtn.MouseButton1Click:Connect(function()
                if reportedUsers[user] then rBtn.Text="✔ Reportado"; return end
                reportedUsers[user]=true; rBtn.Text="✔ Reportado"
                rBtn.BackgroundColor3=Color3.fromRGB(40,120,40)
                task.spawn(function()
                    fbPost("/reports.json",{reporter=MYNAME,reported=user,ts=os.time(),g=MYGAME,uid=uid or 0})
                end)
            end)
            -- spacer for report button
            local rsp=Instance.new("Frame",txF); rsp.Size=UDim2.new(1,0,0,26); rsp.Position=UDim2.new(0,0,1,0); rsp.BackgroundTransparency=1
        end

        -- bottom pad
        local bp=Instance.new("Frame",body); bp.Size=UDim2.new(1,0,0,8); bp.Position=UDim2.new(0,0,1,0); bp.BackgroundTransparency=1
    end
    task.defer(function() pcall(function() p.scroll.CanvasPosition=Vector2.new(0,99999) end) end)
end

local function sysMsg(key,txt) addMsg(key,"",txt,0,0,true) end

-- ── Build tabs ────────────────────────────────────────────
for _,tab in ipairs(TABS) do
    local noIn=(tab.key=="local" or tab.key=="debug" or tab.key=="privado")
    buildPanel(tab.key,noIn)
    local btn=Instance.new("TextButton",TabSF)
    btn.Text=tab.lbl; btn.Size=UDim2.new(0,BTN_W,0,BTN_H)
    btn.BackgroundColor3=C_OFF; btn.TextColor3=Color3.fromRGB(112,102,162)
    btn.TextSize=BFSZ; btn.Font=Enum.Font.Gotham; btn.BorderSizePixel=0; mkCorner(btn,7)
    tabBtns[tab.key]=btn
end

-- ── Switch tab ────────────────────────────────────────────
local function switchTab(key)
    if activeKey==key then return end; activeKey=key
    for k,btn in pairs(tabBtns) do
        local on=(k==key)
        Tween:Create(btn,TweenInfo.new(0.18),{BackgroundColor3=on and C_ON or C_OFF,TextColor3=on and Color3.fromRGB(238,232,255) or Color3.fromRGB(112,102,162)}):Play()
    end
    for k,p in pairs(panels) do p.fr.Visible=(k==key) end
end
for key,btn in pairs(tabBtns) do btn.MouseButton1Click:Connect(function() switchTab(key) end) end

-- ══════════════════════════════════════════════════════════
-- AGE PROMPT MODAL
-- ══════════════════════════════════════════════════════════
local ageConfirmed = false
local ageDone = Instance.new("BindableEvent")

local ageModal=Instance.new("Frame",SG)
ageModal.Size=UDim2.new(0,WIN_W,0,WIN_H); ageModal.Position=Main.Position
ageModal.AnchorPoint=Vector2.new(0.5,0.5)
ageModal.BackgroundColor3=Color3.fromRGB(6,4,16); ageModal.BorderSizePixel=0; ageModal.ZIndex=50
mkCorner(ageModal,14); mkStroke(ageModal,Color3.fromRGB(75,44,188),1.5)

local amBox=Instance.new("Frame",ageModal)
amBox.Size=UDim2.new(0,mob and WIN_W-40 or 340,0,mob and 260 or 230)
amBox.AnchorPoint=Vector2.new(0.5,0.5); amBox.Position=UDim2.new(0.5,0,0.45,0)
amBox.BackgroundColor3=Color3.fromRGB(14,10,34); amBox.BorderSizePixel=0; mkCorner(amBox,14); mkStroke(amBox,Color3.fromRGB(88,50,212))

local amTitle=Instance.new("TextLabel",amBox)
amTitle.Text="🔞 Qual é a sua idade?"; amTitle.Size=UDim2.new(1,-20,0,32)
amTitle.Position=UDim2.new(0,10,0,12)
amTitle.BackgroundTransparency=1; amTitle.TextColor3=Color3.fromRGB(220,210,255)
amTitle.TextSize=mob and 18 or 16; amTitle.Font=Enum.Font.GothamBold; amTitle.TextXAlignment=Enum.TextXAlignment.Center

local amNote=Instance.new("TextLabel",amBox)
amNote.Text="ℹ️ Isso não afetará seu chat.\nVocê poderá conversar com quem quiser."
amNote.Size=UDim2.new(1,-20,0,0); amNote.AutomaticSize=Enum.AutomaticSize.Y
amNote.Position=UDim2.new(0,10,0,48)
amNote.BackgroundTransparency=1; amNote.TextColor3=Color3.fromRGB(130,118,190)
amNote.TextSize=mob and 13 or 11; amNote.Font=Enum.Font.GothamItalic
amNote.TextWrapped=true; amNote.TextXAlignment=Enum.TextXAlignment.Center

local amInput=Instance.new("TextBox",amBox)
amInput.PlaceholderText="Sua idade (ex: 16)"; amInput.Text=""
amInput.Size=UDim2.new(1,-20,0,INH); amInput.Position=UDim2.new(0,10,0,120)
amInput.BackgroundColor3=Color3.fromRGB(20,16,42); amInput.BorderSizePixel=0; mkCorner(amInput,9); mkStroke(amInput,Color3.fromRGB(70,48,155))
amInput.TextColor3=Color3.fromRGB(220,210,255); amInput.PlaceholderColor3=Color3.fromRGB(90,78,148)
amInput.TextSize=mob and 18 or 16; amInput.Font=Enum.Font.GothamBold; amInput.TextXAlignment=Enum.TextXAlignment.Center
amInput.ClearTextOnFocus=false

local amBtn=Instance.new("TextButton",amBox)
amBtn.Text="✅ Confirmar"; amBtn.Size=UDim2.new(1,-20,0,INH)
amBtn.Position=UDim2.new(0,10,0,174)
amBtn.BackgroundColor3=Color3.fromRGB(85,50,200); amBtn.TextColor3=Color3.fromRGB(255,255,255)
amBtn.TextSize=mob and 15 or 13; amBtn.Font=Enum.Font.GothamBold; amBtn.BorderSizePixel=0; mkCorner(amBtn,10)

local function confirmAge()
    local v=tonumber(amInput.Text)
    if not v or v<5 or v>100 then
        amInput.PlaceholderText="⚠️ Número inválido!"
        amInput.Text=""
        Tween:Create(amBox,TweenInfo.new(0.06),{Position=UDim2.new(0.5,-5,0.45,0)}):Play()
        task.wait(0.06)
        Tween:Create(amBox,TweenInfo.new(0.06),{Position=UDim2.new(0.5,5,0.45,0)}):Play()
        task.wait(0.06)
        Tween:Create(amBox,TweenInfo.new(0.06),{Position=UDim2.new(0.5,0,0.45,0)}):Play()
        return
    end
    MY_AGE = v
    ageLbl.Text=(isMinor(v) and "👤 " or "🔞 ")..MYGAME.." | "..v.."anos"
    Tween:Create(ageModal,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play()
    for _,c in ipairs(ageModal:GetDescendants()) do
        if c:IsA("TextLabel") or c:IsA("TextButton") then
            pcall(function() Tween:Create(c,TweenInfo.new(0.3),{TextTransparency=1}):Play() end)
        end
        if c:IsA("Frame") then pcall(function() Tween:Create(c,TweenInfo.new(0.3),{BackgroundTransparency=1}):Play() end) end
    end
    task.delay(0.35,function() ageModal:Destroy() end)
    ageConfirmed=true
    ageDone:Fire()
end
amBtn.MouseButton1Click:Connect(confirmAge)
amInput.FocusLost:Connect(function(e) if e then confirmAge() end end)

-- ══════════════════════════════════════════════════════════
-- LOCAL CHAT
-- ══════════════════════════════════════════════════════════
sysMsg("local","✅ Chat local conectado!")
local function hookLocal()
    local ok=pcall(function()
        if game:GetService("TextChatService").ChatVersion~=Enum.ChatVersion.TextChatService then error() end
        game:GetService("TextChatService").MessageReceived:Connect(function(msg)
            local nm=(msg.TextSource and msg.TextSource.Name) or "?"
            local uid2=0; pcall(function() local pp=Players:FindFirstChild(nm); if pp then uid2=pp.UserId end end)
            addMsg("local",nm,msg.Text,uid2,0,false)
        end)
    end)
    if ok then return end
    local function hk(pl) pl.Chatted:Connect(function(m) addMsg("local",pl.Name,m,pl.UserId,0,false) end) end
    for _,pl in ipairs(Players:GetPlayers()) do hk(pl) end
    Players.PlayerAdded:Connect(hk)
end
task.spawn(hookLocal)

-- ══════════════════════════════════════════════════════════
-- GLOBAL CHANNELS
-- ══════════════════════════════════════════════════════════
local function setupChannel(key,fb)
    local p=panels[key]; if not p then return end
    sysMsg(key,"🔗 Canal: "..fb.." | Conectando...")

    local function enviar(txt)
        txt=txt and txt:match("^%s*(.-)%s*$") or ""; if txt=="" then return end
        task.spawn(function()
            fbPost("/"..fb..".json",{u=MYNAME,uid=MYUID,t=txt,ts=os.time(),g=MYGAME,age=MY_AGE})
        end)
        if p.input then p.input.Text="" end
    end
    if p.send then p.send.MouseButton1Click:Connect(function() enviar(p.input and p.input.Text or "") end) end
    if p.input then p.input.FocusLost:Connect(function(e) if e then enviar(p.input.Text) end end) end

    task.spawn(function()
        local known={}; local first=true
        while Main.Parent do
            task.wait(first and 0.7 or POLL_INT)
            local data,err=fbList(fb)
            if data and type(data)=="table" then
                local list={}
                for k,v in pairs(data) do
                    if type(v)=="table" and not known[k] then
                        known[k]=true; table.insert(list,{ts=v.ts or 0,u=v.u or "?",t=v.t or "",uid=v.uid or 0,age=v.age or 0})
                    end
                end
                table.sort(list,function(a,b) return a.ts<b.ts end)
                if first then first=false; if #list==0 then sysMsg(key,"📭 Seja o primeiro a enviar!") end end
                for _,m in ipairs(list) do
                    if m.uid and m.uid~=0 then ageCache[m.uid]=m.age end
                    addMsg(key,m.u,m.t,m.uid,m.age,false)
                end
            else
                if first then first=false; sysMsg(key,"⚠️ Erro: "..(err or "?").." → vá em 🔧 Debug") end
            end
        end
    end)
end
setupChannel("global","global"); setupChannel("brasil","brasil"); setupChannel("usa","usa")

-- ══════════════════════════════════════════════════════════
-- PRESENÇA
-- ══════════════════════════════════════════════════════════
local myKey=sfen(MYNAME)
local function pushPresence()
    task.spawn(function() fbPut("/presence/"..myKey..".json",{n=MYNAME,uid=MYUID,ts=os.time(),g=MYGAME,age=MY_AGE}) end)
end
local function pollPresence()
    task.spawn(function()
        local data=fbGet("/presence.json")
        if not data or type(data)~="table" then return end
        local now=os.time()
        for sk,info in pairs(data) do
            if sk~=myKey and type(info)=="table" then
                local fresh=(now-(info.ts or 0))<PRES_EXPIRE
                if knownPres[sk] and knownPres[sk].alive and not fresh then
                    knownPres[sk].alive=false
                    local nm=info.n or sk
                    for _,ch in ipairs({"global","brasil","usa"}) do sysMsg(ch,"👋 "..nm.." saiu do jogo") end
                    task.delay(30,function() fbDel("/presence/"..sk..".json") end)
                elseif not knownPres[sk] and fresh then
                    knownPres[sk]={n=info.n or sk,alive=true}
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
-- PRIVATE ROOM
-- ══════════════════════════════════════════════════════════
local privCode=nil; local privKnown={}

local function startPrivRoom(code,isCreator)
    privCode=code; privKnown={}
    local p=panels["privado"]; if not p then return end
    -- rebuild scroll
    for _,c in ipairs(p.fr:GetChildren()) do if not c:IsA("UICorner") then c:Destroy() end end
    local scH2=ContentH-(INH+34)
    local scroll2=Instance.new("ScrollingFrame",p.fr)
    scroll2.Size=UDim2.new(0,WIN_W-12,0,scH2); scroll2.Position=UDim2.new(0,6,0,28)
    scroll2.BackgroundColor3=Color3.fromRGB(9,7,20); scroll2.BorderSizePixel=0
    scroll2.ScrollBarThickness=3; scroll2.ScrollBarImageColor3=Color3.fromRGB(140,42,212)
    scroll2.CanvasSize=UDim2.new(0,0,0,0); scroll2.AutomaticCanvasSize=Enum.AutomaticSize.Y
    mkCorner(scroll2,10)
    local ll2=Instance.new("UIListLayout",scroll2); ll2.SortOrder=Enum.SortOrder.LayoutOrder; ll2.Padding=UDim.new(0,2)
    local sp2=Instance.new("UIPadding",scroll2)
    sp2.PaddingLeft=UDim.new(0,6); sp2.PaddingRight=UDim.new(0,6); sp2.PaddingTop=UDim.new(0,5); sp2.PaddingBottom=UDim.new(0,5)
    p.scroll=scroll2; msgCount["privado"]=0

    local codeLbl=Instance.new("TextLabel",p.fr)
    codeLbl.Size=UDim2.new(0,WIN_W-12,0,22); codeLbl.Position=UDim2.new(0,6,0,3)
    codeLbl.BackgroundTransparency=1; codeLbl.TextXAlignment=Enum.TextXAlignment.Left
    codeLbl.TextColor3=Color3.fromRGB(175,155,235); codeLbl.TextSize=FSZ-1; codeLbl.Font=Enum.Font.Gotham; codeLbl.RichText=true
    codeLbl.Text='🔒 Código: <font color="#FFD700"><b>'..code.."</b></font>"..(isCreator and " (criada)" or " (entrou)")

    local iF2=Instance.new("Frame",p.fr)
    iF2.Size=UDim2.new(0,WIN_W-12,0,INH); iF2.Position=UDim2.new(0,6,0,scH2+34)
    iF2.BackgroundColor3=Color3.fromRGB(13,9,32); iF2.BorderSizePixel=0; mkCorner(iF2,10); mkStroke(iF2,Color3.fromRGB(112,36,172))

    local inBox=Instance.new("TextBox",iF2)
    inBox.PlaceholderText="Mensagem privada..."; inBox.Text=""
    inBox.Size=UDim2.new(1,-90,1,0); inBox.Position=UDim2.new(0,10,0,0)
    inBox.BackgroundTransparency=1; inBox.TextColor3=Color3.fromRGB(215,205,255)
    inBox.PlaceholderColor3=Color3.fromRGB(80,60,130); inBox.TextSize=FSZ; inBox.Font=Enum.Font.Gotham
    inBox.TextXAlignment=Enum.TextXAlignment.Left; inBox.ClearTextOnFocus=false

    local sBtn2=Instance.new("TextButton",iF2)
    sBtn2.Text="Enviar"; sBtn2.Size=UDim2.new(0,72,0,INH-12); sBtn2.Position=UDim2.new(1,-78,0.5,-(INH-12)/2)
    sBtn2.BackgroundColor3=Color3.fromRGB(138,36,200); sBtn2.TextColor3=Color3.fromRGB(255,255,255)
    sBtn2.TextSize=mob and 12 or 11; sBtn2.Font=Enum.Font.GothamBold; sBtn2.BorderSizePixel=0; mkCorner(sBtn2,8)
    p.input=inBox; p.send=sBtn2

    local function sendPriv(txt)
        txt=txt and txt:match("^%s*(.-)%s*$") or ""; if txt=="" then return end
        task.spawn(function()
            fbPost("/rooms/"..code.."/msgs.json",{u=MYNAME,uid=MYUID,t=txt,ts=os.time(),age=MY_AGE})
        end)
        inBox.Text=""
    end
    sBtn2.MouseButton1Click:Connect(function() sendPriv(inBox.Text) end)
    inBox.FocusLost:Connect(function(e) if e then sendPriv(inBox.Text) end end)
    sysMsg("privado","🔒 Sala: "..code..(isCreator and " — aguardando amigo..." or " — conectado!"))

    task.spawn(function()
        local first=true
        while Main.Parent and privCode==code do
            task.wait(first and 0.7 or POLL_INT)
            local d2,e2=fbList("rooms/"..code.."/msgs")
            if d2 and type(d2)=="table" then
                local list2={}
                for k,v in pairs(d2) do
                    if type(v)=="table" and not privKnown[k] then
                        privKnown[k]=true; table.insert(list2,{ts=v.ts or 0,u=v.u or "?",t=v.t or "",uid=v.uid or 0,age=v.age or 0})
                    end
                end
                table.sort(list2,function(a,b) return a.ts<b.ts end)
                if first then first=false; if #list2==0 then sysMsg("privado","📭 Aguardando amigo...") end end
                for _,m in ipairs(list2) do addMsg("privado",m.u,m.t,m.uid,m.age,false) end
            else
                if first then first=false; sysMsg("privado","⚠️ Erro ao carregar sala.") end
            end
        end
    end)
    switchTab("privado")
end

-- Private room UI
task.defer(function()
    task.wait(0.5)
    local p=panels["privado"]; if not p then return end
    sysMsg("privado","🔒 Crie ou entre em uma sala privada.")

    local ctrlF=Instance.new("Frame",p.fr)
    ctrlF.Name="PrivCtrl"; ctrlF.Size=UDim2.new(0,WIN_W-12,0,INH*2+20)
    ctrlF.Position=UDim2.new(0,6,0.5,-(INH+10)); ctrlF.BackgroundTransparency=1
    local cll=Instance.new("UIListLayout",ctrlF)
    cll.FillDirection=Enum.FillDirection.Vertical; cll.Padding=UDim.new(0,10); cll.HorizontalAlignment=Enum.HorizontalAlignment.Center

    local cBtn=Instance.new("TextButton",ctrlF)
    cBtn.Text="✨ Criar Sala Privada"; cBtn.Size=UDim2.new(1,0,0,INH)
    cBtn.BackgroundColor3=Color3.fromRGB(88,36,185); cBtn.TextColor3=Color3.fromRGB(255,255,255)
    cBtn.TextSize=mob and 14 or 12; cBtn.Font=Enum.Font.GothamBold; cBtn.BorderSizePixel=0; mkCorner(cBtn,10)

    local jRow=Instance.new("Frame",ctrlF)
    jRow.Size=UDim2.new(1,0,0,INH); jRow.BackgroundColor3=Color3.fromRGB(13,10,32); jRow.BorderSizePixel=0; mkCorner(jRow,10); mkStroke(jRow,Color3.fromRGB(78,46,162))

    local cBox=Instance.new("TextBox",jRow)
    cBox.PlaceholderText="Código (ex: AB3X7K)"; cBox.Text=""
    cBox.Size=UDim2.new(1,-98,1,0); cBox.Position=UDim2.new(0,10,0,0)
    cBox.BackgroundTransparency=1; cBox.TextColor3=Color3.fromRGB(220,210,255)
    cBox.PlaceholderColor3=Color3.fromRGB(78,65,128); cBox.TextSize=FSZ; cBox.Font=Enum.Font.Gotham
    cBox.TextXAlignment=Enum.TextXAlignment.Left; cBox.ClearTextOnFocus=false

    local jBtn=Instance.new("TextButton",jRow)
    jBtn.Text="Entrar"; jBtn.Size=UDim2.new(0,80,0,INH-10); jBtn.Position=UDim2.new(1,-86,0.5,-(INH-10)/2)
    jBtn.BackgroundColor3=Color3.fromRGB(28,115,52); jBtn.TextColor3=Color3.fromRGB(255,255,255)
    jBtn.TextSize=mob and 13 or 11; jBtn.Font=Enum.Font.GothamBold; jBtn.BorderSizePixel=0; mkCorner(jBtn,8)

    cBtn.MouseButton1Click:Connect(function()
        cBtn.Text="⏳ Criando..."; cBtn.BackgroundColor3=Color3.fromRGB(55,22,118)
        task.spawn(function()
            local code=mkCode()
            fbPut("/rooms/"..code.."/info.json",{c=MYNAME,uid=MYUID,ts=os.time()})
            ctrlF:Destroy(); startPrivRoom(code,true)
        end)
    end)
    local function doJoin()
        local code=cBox.Text:upper():gsub("%s",""); if #code<4 then sysMsg("privado","⚠️ Código inválido."); return end
        jBtn.Text="⏳"; jBtn.BackgroundColor3=Color3.fromRGB(18,76,34)
        task.spawn(function()
            local info=fbGet("/rooms/"..code.."/info.json")
            if info and type(info)=="table" and info.c then
                ctrlF:Destroy(); startPrivRoom(code,false)
            else
                jBtn.Text="Entrar"; jBtn.BackgroundColor3=Color3.fromRGB(28,115,52)
                sysMsg("privado","❌ Sala não encontrada!")
            end
        end)
    end
    jBtn.MouseButton1Click:Connect(doJoin)
    cBox.FocusLost:Connect(function(e) if e then doJoin() end end)
end)

-- ══════════════════════════════════════════════════════════
-- DEBUG
-- ══════════════════════════════════════════════════════════
local function runDiag()
    sysMsg("debug","🔍 Diagnóstico...")
    task.wait(0.1)
    addMsg("debug","HTTP","Função: "..httpName,0,0,false)
    if not httpFn and not useHttp then sysMsg("debug","❌ Nenhuma função HTTP!"); return end
    sysMsg("debug","📡 Testando Firebase..."); task.wait(0.1)
    local res=doReq({Url=FIREBASE_URL.."/ping.json",Method="GET"})
    if not res then sysMsg("debug","❌ Sem resposta! Verifique internet."); return end
    local code=tostring(res.StatusCode or res.status_code or "?")
    local body=tostring(res.Body or res.body or "")
    addMsg("debug","Status","HTTP "..code,0,0,false)
    if body:find("Permission denied") or code=="401" then
        sysMsg("debug","❌ Firebase bloqueado! Vá em Regras → read/write: true"); return
    end
    if code=="200" or res.Success then sysMsg("debug","✅ Tudo OK!") else addMsg("debug","Resp",body:sub(1,55),0,0,false) end
end
task.defer(function()
    task.wait(0.5)
    sysMsg("debug","Pressione o botão para testar.")
    addMsg("debug","Info","HTTP: "..httpName,0,0,false)
    local p=panels["debug"]; if not p then return end
    local db=Instance.new("TextButton",p.fr)
    db.Text="🔍 Testar Conexão"; db.Size=UDim2.new(0,WIN_W-12,0,40); db.Position=UDim2.new(0,6,0,ContentH-46)
    db.BackgroundColor3=Color3.fromRGB(30,118,50); db.TextColor3=Color3.fromRGB(255,255,255)
    db.TextSize=mob and 14 or 12; db.Font=Enum.Font.GothamBold; db.BorderSizePixel=0; mkCorner(db,10)
    db.MouseButton1Click:Connect(function()
        db.Text="Testando..."; db.BackgroundColor3=Color3.fromRGB(18,78,32)
        task.spawn(function() runDiag(); task.wait(2); db.Text="🔍 Testar Conexão"; db.BackgroundColor3=Color3.fromRGB(30,118,50) end)
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
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-ds; Main.Position=UDim2.new(dp.X.Scale,dp.X.Offset+d.X,dp.Y.Scale,dp.Y.Offset+d.Y)
        end
    end)
end

-- ══════════════════════════════════════════════════════════
-- MIN / CLOSE
-- ══════════════════════════════════════════════════════════
local minimized=false
MinBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    Tween:Create(Main,TweenInfo.new(0.28,Enum.EasingStyle.Quart),{Size=minimized and UDim2.new(0,WIN_W,0,TH) or UDim2.new(0,WIN_W,0,WIN_H)}):Play()
    MinBtn.Text=minimized and "□" or "−"
end)
CloseBtn.MouseButton1Click:Connect(function()
    task.spawn(function() fbDel("/presence/"..myKey..".json") end)
    Tween:Create(Main,TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.new(0,WIN_W,0,0)}):Play()
    task.delay(0.25,function() SG:Destroy() end)
end)

-- ══════════════════════════════════════════════════════════
-- START
-- ══════════════════════════════════════════════════════════
switchTab("local")
amInput:CaptureFocus()
print("[GlobalChatHub v4] OK | User:"..MYNAME.." | HTTP:"..httpName)
