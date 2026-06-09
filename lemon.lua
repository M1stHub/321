local repo=("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/")
local Library=loadstring(game:HttpGet(repo.."Library.lua"))()
local ThemeManager=loadstring(game:HttpGet(repo.."addons/ThemeManager.lua"))()
local SaveManager=loadstring(game:HttpGet(repo.."addons/SaveManager.lua"))()
local Options=Library.Options
local Toggles=Library.Toggles
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local lp=Players.LocalPlayer
local Window=Library:CreateWindow({Title="Lemon Hub",Footer="v2.0",Center=true,AutoShow=true,ShowCustomCursor=true,NotifySide="Right"})
local Tabs={
    Main=Window:AddTab("Main","zap"),
    Stands=Window:AddTab("Stands","store"),
    Tuning=Window:AddTab("Tuning","sliders"),
    ["UI Settings"]=Window:AddTab("UI Settings","settings"),
}
local Options=Library.Options
local Toggles=Library.Toggles
local autoBuy,lemonFarm,cashFarm,autoStand=false,false,false,false
local STAND_LIST={
    {display="Lemon Stand",    key="LemonStand",    pname="Lemon Stand"},
    {display="Lemon Dash",     key="LemonDash",     pname="LemonDash"},
    {display="Lemon Depot",    key="LemonDepot",    pname="Lemon Depot"},
    {display="Lemon Trading",  key="LemonTrading",  pname="Lemon Trading"},
    {display="Lemon Labs",     key="LemonLabs",     pname="Lemon Labs"},
    {display="Lemon Robotics", key="LemonRobotics", pname="Lemon Robotics"},
    {display="Lemon Republic", key="LemonRepublic", pname="Lemon Republic"},
    {display="LemonX",         key="LemonX",        pname="LemonX"},
}
local function findTycoon()
    for _,o in ipairs(workspace:GetChildren()) do
        if o.Name:find("Tycoon") then
            local ow=o:FindFirstChild("Owner")
            if ow then
                local ok,v=pcall(function()return tostring(ow.Value)end)
                if ok and v and v:find(lp.Name) then return o end
            end
        end
    end
end
local function isBuyable(btn)
    if not btn then return true end
    local ok,c=pcall(function()return btn.BackgroundColor3 end)
    if not ok or not c then return true end
    local r,g,b=math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)
    return not(math.abs(r-125)<30 and math.abs(g-125)<30 and math.abs(b-125)<30)
end
local function getManageBtn(key)
    local pg=lp:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    local ok,b=pcall(function()return pg.Manage.ManageMenu.Body.Frame.Manage[key].Upgrade end)
    return ok and b or nil
end
local function fireUpgrade(folder,amount)
    local n=folder.Name
    local fired=pcall(function()
        local r=folder[n][n]:FindFirstChild("Upgrade")
        if r and r:IsA("RemoteFunction") then r:InvokeServer(amount)
        elseif r and r:IsA("RemoteEvent") then r:FireServer(amount) end
    end)
    if not fired then
        for _,d in ipairs(folder:GetDescendants()) do
            if d.Name=="Upgrade" and(d:IsA("RemoteFunction") or d:IsA("RemoteEvent")) then
                pcall(function()
                    if d:IsA("RemoteFunction") then d:InvokeServer(amount) else d:FireServer(amount) end
                end)
                return
            end
        end
    end
end
local function wakeIncome(ty,key)
    pcall(function()
        local r=ty.Remotes:FindFirstChild("WakeIncomeStream")
        if r then r:InvokeServer(key) end
    end)
end
local function getLemonTrees()
    local t={}
    for _,o in ipairs(workspace:GetChildren()) do
        if o.Name:find("Tycoon") then
            local c=o:FindFirstChild("Constant")
            if c then
                local tf=c:FindFirstChild("Trees")
                if tf then for _,tr in ipairs(tf:GetChildren()) do t[#t+1]=tr end end
            end
        end
    end
    local rt=workspace:FindFirstChild("LemonTree")
    if rt then t[#t+1]=rt end
    return t
end
-- loops
task.spawn(function()
    while true do
        if autoBuy then
            local ty=findTycoon()
            if ty then
                local p=ty:FindFirstChild("Purchases")
                if p then
                    for _,f in ipairs(p:GetChildren()) do
                        if not autoBuy then break end
                        fireUpgrade(f,1)
                        task.wait((Options.AutoBuyDelay and Options.AutoBuyDelay.Value or 150)/1000)
                    end
                end
            end
            task.wait(0.5)
        else task.wait(0.1) end
    end
end)
task.spawn(function()
    while true do
        if autoStand then
            local ty=findTycoon()
            local p=ty and ty:FindFirstChild("Purchases")
            if p then
                local sel=Options.StandSelection and Options.StandSelection.Value or {}
                local amt=Options.StandUpgradeAmount and Options.StandUpgradeAmount.Value or 25
                local dly=(Options.StandDelay and Options.StandDelay.Value or 200)/1000
                for _,s in ipairs(STAND_LIST) do
                    if not autoStand then break end
                    local picked=false
                    for k,v in pairs(sel) do
                        if(k==s.display or v==s.display)and v~=false then picked=true break end
                    end
                    if picked then
                        local btn=getManageBtn(s.key)
                        if isBuyable(btn) then
                            local f=p:FindFirstChild(s.pname)
                            if f then
                                fireUpgrade(f,amt)
                                if Options.WakeIncome and Options.WakeIncome.Value then
                                    wakeIncome(ty,s.key)
                                end
                                task.wait(dly)
                            end
                        end
                    end
                    task.wait(0.05)
                end
            end
            task.wait(0.3)
        else task.wait(0.1) end
    end
end)
task.spawn(function()
    while true do
        if lemonFarm then
            local char=lp.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _,tree in ipairs(getLemonTrees()) do
                    if not lemonFarm then break end
                    if not tree or not tree.Parent then continue end
                    local pos
                    pcall(function()pos=tree:GetPivot().Position end)
                    if not pos then pcall(function()pos=tree.PrimaryPart.Position end) end
                    if pos then
                        hrp.CFrame=CFrame.new(pos.X,pos.Y+5,pos.Z)
                        task.wait((Options.LemonTPSettle and Options.LemonTPSettle.Value or 50)/1000)
                    end
                    local maxY=Options.LemonMaxY and Options.LemonMaxY.Value or 14
                    local fd=(Options.LemonFruitDelay and Options.LemonFruitDelay.Value or 50)/1000
                    for _,fruit in ipairs(tree:GetChildren()) do
                        if not lemonFarm then break end
                        if fruit.Name~="Fruit" then continue end
                        local cp=fruit:FindFirstChild("ClickPart")
                        if cp and cp:IsA("BasePart") and cp.Position.Y<=maxY then
                            pcall(function()fireallclickdetectors(cp)end)
                            task.wait(fd)
                        end
                    end
                end
            end
            task.wait(0.1)
        else task.wait(0.1) end
    end
end)
task.spawn(function()
    while true do
        if cashFarm then
            local char=lp.Character
            local head=char and char:FindFirstChild("Head")
            if head then
                local f=workspace:FindFirstChild("CashDrops")
                if f then
                    local hp=head.Position
                    for _,v in ipairs(f:GetDescendants()) do
                        if v.Name=="TouchInterest" and v.Parent then
                            pcall(function()v.Parent.Position=hp end)
                        end
                    end
                end
            end
            task.wait((Options.CashFarmDelay and Options.CashFarmDelay.Value or 300)/1000)
        else task.wait(0.1) end
    end
end)
-- UI: build all elements first, wire callbacks after
local LM=Tabs.Main:AddLeftGroupbox("Automation","zap")
local RM=Tabs.Main:AddRightGroupbox("Controls","gamepad-2")
LM:AddToggle("AutoBuy",{Text="Auto Buy",Default=false,Tooltip="Fires Upgrade remotes on all Purchases folders"})
LM:AddLabel("AutoBuyBind",{Text="Auto Buy Bind"}):AddKeyPicker("AutoBuyKey",{Default="One",Mode="Toggle",SyncToggleState=true,Text="Auto Buy",NoUI=false})
LM:AddDivider()
LM:AddToggle("LemonFarm",{Text="Lemon Farm",Default=false,Tooltip="TPs to trees, fires all ClickDetectors on fruits"})
LM:AddLabel("LemonFarmBind",{Text="Lemon Farm Bind"}):AddKeyPicker("LemonFarmKey",{Default="Two",Mode="Toggle",SyncToggleState=true,Text="Lemon Farm",NoUI=false})
LM:AddDivider()
LM:AddToggle("CashFarm",{Text="Cash Farm",Default=false,Tooltip="Moves CashDrops to your head"})
LM:AddLabel("CashFarmBind",{Text="Cash Farm Bind"}):AddKeyPicker("CashFarmKey",{Default="Three",Mode="Toggle",SyncToggleState=true,Text="Cash Farm",NoUI=false})
LM:AddDivider()
LM:AddToggle("AutoStand",{Text="Auto Stand",Default=false,Tooltip="Checks ManageMenu color, fires Upgrade remote if buyable"})
LM:AddLabel("AutoStandBind",{Text="Auto Stand Bind"}):AddKeyPicker("AutoStandKey",{Default="Four",Mode="Toggle",SyncToggleState=true,Text="Auto Stand",NoUI=false})
RM:AddButton({Text="Stop All [0]",Risky=true,Tooltip="Stops everything",Func=function()
    autoBuy,lemonFarm,cashFarm,autoStand=false,false,false,false
    Toggles.AutoBuy:SetValue(false)
    Toggles.LemonFarm:SetValue(false)
    Toggles.CashFarm:SetValue(false)
    Toggles.AutoStand:SetValue(false)
    Library:Notify({Title="Lemon Hub",Description="All stopped!",Time=2})
end})
-- stands tab
local LS=Tabs.Stands:AddLeftGroupbox("Stand Selection","list")
local RS=Tabs.Stands:AddRightGroupbox("Upgrade Settings","settings-2")
local sNames={}
for _,s in ipairs(STAND_LIST) do sNames[#sNames+1]=s.display end
LS:AddDropdown("StandSelection",{Text="Stands to Upgrade",Values=sNames,Default=sNames,Multi=true})
LS:AddLabel("Open the Manage menu once so color checks work.",true)
RS:AddSlider("StandUpgradeAmount",{Text="Upgrade Amount",Default=25,Min=1,Max=100,Rounding=0,Tooltip="Levels per invoke"})
RS:AddSlider("StandDelay",{Text="Delay Between Stands",Default=200,Min=50,Max=2000,Rounding=0,Suffix=" ms"})
RS:AddToggle("WakeIncome",{Text="Fire WakeIncomeStream",Default=true})
-- tuning tab
local LT=Tabs.Tuning:AddLeftGroupbox("Lemon Farm","leaf")
local RT=Tabs.Tuning:AddRightGroupbox("Other","wrench")
LT:AddSlider("LemonTPSettle",{Text="TP Settle",Default=50,Min=0,Max=500,Rounding=0,Suffix=" ms"})
LT:AddSlider("LemonFruitDelay",{Text="Fruit Delay",Default=50,Min=0,Max=500,Rounding=0,Suffix=" ms"})
LT:AddSlider("LemonMaxY",{Text="Max Fruit Y",Default=14,Min=1,Max=100,Rounding=0,Suffix=" studs"})
RT:AddSlider("AutoBuyDelay",{Text="Auto Buy Delay",Default=150,Min=50,Max=2000,Rounding=0,Suffix=" ms"})
RT:AddSlider("CashFarmDelay",{Text="Cash Farm Delay",Default=300,Min=50,Max=2000,Rounding=0,Suffix=" ms"})
-- settings tab
local MG=Tabs["UI Settings"]:AddLeftGroupbox("Menu","wrench")
MG:AddToggle("KeybindMenuOpen",{Default=Library.KeybindFrame and Library.KeybindFrame.Visible or false,Text="Open Keybind Menu",Callback=function(v)if Library.KeybindFrame then Library.KeybindFrame.Visible=v end end})
MG:AddToggle("ShowCustomCursor",{Text="Custom Cursor",Default=true,Callback=function(v)Library.ShowCustomCursor=v end})
MG:AddDivider()
MG:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind",{Default="F4",NoUI=true,Text="Toggle GUI"})
MG:AddButton("Unload",function()Library:Unload()end)
Library.ToggleKeybind=Options.MenuKeybind
-- wire OnChanged AFTER all elements exist
Toggles.AutoBuy:OnChanged(function(v)autoBuy=v end)
Toggles.LemonFarm:OnChanged(function(v)lemonFarm=v end)
Toggles.CashFarm:OnChanged(function(v)cashFarm=v end)
Toggles.AutoStand:OnChanged(function(v)autoStand=v end)
Options.AutoBuyKey:OnClick(function()Toggles.AutoBuy:SetValue(not Toggles.AutoBuy.Value)end)
Options.LemonFarmKey:OnClick(function()Toggles.LemonFarm:SetValue(not Toggles.LemonFarm.Value)end)
Options.CashFarmKey:OnClick(function()Toggles.CashFarm:SetValue(not Toggles.CashFarm.Value)end)
Options.AutoStandKey:OnClick(function()Toggles.AutoStand:SetValue(not Toggles.AutoStand.Value)end)
UIS.InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode==Enum.KeyCode.Zero then
        autoBuy,lemonFarm,cashFarm,autoStand=false,false,false,false
        Toggles.AutoBuy:SetValue(false)
        Toggles.LemonFarm:SetValue(false)
        Toggles.CashFarm:SetValue(false)
        Toggles.AutoStand:SetValue(false)
        Library:Notify({Title="Lemon Hub",Description="All stopped!",Time=2})
    end
end)
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("LemonHub")
SaveManager:SetFolder("LemonHub/lemon-tycoon")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()
Library:Notify({Title="Lemon Hub",Description="Loaded! F4 to toggle.",Time=4})
