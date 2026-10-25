local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local nguoiDung = Players.LocalPlayer
local playerGui = nguoiDung:WaitForChild("PlayerGui")
local EggHitRequest = ReplicatedStorage:WaitForChild("EggHitRequest")

local kienEnabled = true
local kienIsProcessing = false
local kienCurrentMultiplier = 4
local basePositions = { Base1 = nil, Base2 = nil }
local isAutoWalking = false
local moveConnection = nil
local isPoppedOut = false
local isLocked = false
local espEnabled = false
local instantPromptEnabled = false
local activeEspTags = {}

local isFlyingToPlayer = false
local targetFlyPlayer = nil
local flyConnection = nil

-- BIẾN CHO TÍNH NĂNG RADAR QUÉT FULL TRỨNG & LỰA CHỌN
local autoFarmEggEnabled = false
local selectedEggName = "Tất cả (Tự động gần nhất)"
local eggBlacklist = {}
local currentTargetEgg = nil
local eggFarmConnection = nil
local eggEspBillboard = nil
local eggTimer = 0

pcall(function()
    local cu = playerGui:FindFirstChild("KienMenuM1")
    if cu then cu:Destroy() end
    local cuPop = playerGui:FindFirstChild("PopoutFrameKien")
    if cuPop then cuPop:Destroy() end
end)

local Mau = {
    Nen = Color3.fromRGB(10, 10, 14),
    Panel = Color3.fromRGB(17, 17, 23),
    The = Color3.fromRGB(24, 24, 32),
    Do = Color3.fromRGB(255, 48, 75),
    DoDam = Color3.fromRGB(120, 20, 40),
    Trang = Color3.fromRGB(245, 245, 250),
    Mo = Color3.fromRGB(145, 145, 160),
    XanhNhe = Color3.fromRGB(70, 230, 155),
    Tim = Color3.fromRGB(180, 80, 255),
}

local function tao(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local function boGoc(parent, radius)
    tao("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function vien(parent, color, thickness, transparency)
    return tao("UIStroke", { Color = color or Mau.Do, Thickness = thickness or 1, Transparency = transparency or 0 }, parent)
end

local function hieuDung(obj, duration, props)
    local t = TweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if isLocked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    guiObject.InputChanged:Connect(function(input)
        if isLocked then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isLocked then return end
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local parentGui = playerGui
pcall(function()
    if gethui then
        parentGui = gethui()
    elseif syn and syn.protect_gui then
        parentGui = Instance.new("Folder")
        syn.protect_gui(parentGui)
        parentGui.Parent = CoreGui
    end
end)

local screenGui = tao("ScreenGui", {
    Name = "KienMenuM1",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, parentGui)

local function autoBoostFPS()
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        settings().Rendering.QualityLevel = 1
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj:Destroy()
            end
        end
    end)
end
autoBoostFPS()
local thongBaoLabel = tao("TextLabel", {
    Name = "ThongBaoNoi",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 12),
    Size = UDim2.fromOffset(280, 36),
    BackgroundColor3 = Mau.The,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Text = "",
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    Visible = false,
    ZIndex = 100,
}, screenGui)
boGoc(thongBaoLabel, 10)
vien(thongBaoLabel, Mau.Do, 1.5)

local cauVongConnection
local function hienThongBao(noiDung)
    thongBaoLabel.Text = noiDung
    thongBaoLabel.Visible = true
    thongBaoLabel.TextTransparency = 1
    thongBaoLabel.BackgroundTransparency = 1
    hieuDung(thongBaoLabel, 0.2, {TextTransparency = 0, BackgroundTransparency = 0.15})
    
    if cauVongConnection then cauVongConnection:Disconnect() end
    cauVongConnection = RunService.RenderStepped:Connect(function()
        if thongBaoLabel.Visible then
            thongBaoLabel.TextColor3 = Color3.fromHSV(tick() % 5 / 5, 1, 1)
        end
    end)

    task.delay(1.5, function()
        if cauVongConnection then cauVongConnection:Disconnect() cauVongConnection = nil end
        hieuDung(thongBaoLabel, 0.2, {TextTransparency = 1, BackgroundTransparency = 1})
        task.wait(0.22)
        thongBaoLabel.Visible = false
    end)
end

local nutMoMenu = tao("TextButton", {
    Name = "NutMoMenu",
    Size = UDim2.fromOffset(54, 54),
    Position = UDim2.new(0, 18, 0.5, -27),
    BackgroundColor3 = Mau.Nen,
    Text = "K",
    TextColor3 = Mau.Do,
    TextSize = 25,
    Font = Enum.Font.GothamBlack,
    AutoButtonColor = false,
}, screenGui)
boGoc(nutMoMenu, 16)
vien(nutMoMenu, Mau.Do, 2)
makeDraggable(nutMoMenu)

local menuChinh = tao("Frame", {
    Name = "MenuChinh",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(680, 440),
    BackgroundColor3 = Mau.Nen,
    BorderSizePixel = 0,
    Visible = false,
    ClipsDescendants = true,
}, screenGui)
boGoc(menuChinh, 16)
vien(menuChinh, Mau.Do, 1.5)
makeDraggable(menuChinh)

local tyLeGiaoDien = tao("UIScale", { Scale = 1 }, menuChinh)
local function capNhatTyLe()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    tyLeGiaoDien.Scale = math.min(viewport.X / 720, viewport.Y / 480, 1)
end
capNhatTyLe()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(capNhatTyLe)
end

local thanhTieuDe = tao("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = Mau.Panel,
    BorderSizePixel = 0,
}, menuChinh)

tao("Frame", {
    Position = UDim2.new(0, 0, 1, -2),
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = Mau.Do,
    BorderSizePixel = 0,
}, thanhTieuDe)

local logo = tao("Frame", {
    Position = UDim2.new(0, 12, 0.5, -17),
    Size = UDim2.fromOffset(34, 34),
    BackgroundColor3 = Mau.DoDam,
}, thanhTieuDe)
boGoc(logo, 10)
vien(logo, Mau.Do, 1)

tao("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "K",
    TextColor3 = Mau.Trang,
    Font = Enum.Font.GothamBlack,
    TextSize = 20,
}, logo)

tao("TextLabel", {
    Position = UDim2.new(0, 56, 0, 8),
    Size = UDim2.new(0, 240, 0, 20),
    BackgroundTransparency = 1,
    Text = "KIÊN  |  MENU M1 PRO",
    TextColor3 = Mau.Trang,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBlack,
    TextSize = 16,
}, thanhTieuDe)

tao("TextLabel", {
    Position = UDim2.new(0, 57, 0, 28),
    Size = UDim2.new(0, 260, 0, 16),
    BackgroundTransparency = 1,
    Text = "BLACK NEBULA  •  √12kientomato",
    TextColor3 = Mau.Do,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamMedium,
    TextSize = 9,
}, thanhTieuDe)

local fpsLabel = tao("TextLabel", {
    Position = UDim2.new(1, -165, 0, 15),
    Size = UDim2.fromOffset(70, 24),
    BackgroundColor3 = Mau.The,
    TextColor3 = Mau.XanhNhe,
    Text = "FPS: 60",
    TextSize = 11,
    Font = Enum.Font.GothamBold,
}, thanhTieuDe)
boGoc(fpsLabel, 6)

local lastTick = tick()
local frameCount = 0
RunService.RenderStepped:Connect(function()
    frameCount += 1
    local currentTick = tick()
    if currentTick - lastTick >= 1 then
        fpsLabel.Text = "FPS: " .. math.floor(frameCount / (currentTick - lastTick))
        frameCount = 0
        lastTick = currentTick
    end
end)

local nutKhoa = tao("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -85, 0, 13),
    BackgroundColor3 = Mau.The,
    Text = "🔓",
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
}, thanhTieuDe)
boGoc(nutKhoa, 8)

nutKhoa.MouseButton1Click:Connect(function()
    isLocked = not isLocked
    if isLocked then
        nutKhoa.Text = "🔒"
        hienThongBao("Đã khóa vị trí Menu!")
    else
        nutKhoa.Text = "🔓"
        hienThongBao("Đã mở khóa Menu!")
    end
end)

local nutDong = tao("TextButton", {
    Position = UDim2.new(1, -45, 0, 13),
    Size = UDim2.fromOffset(28, 28),
    BackgroundColor3 = Mau.The,
    Text = "×",
    TextColor3 = Mau.Do,
    TextSize = 21,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
}, thanhTieuDe)
boGoc(nutDong, 8)

-- THANH TAB CHUYỂN TRANG NẰM NGANG Ở PHÍA DƯỚI TIÊU ĐỀ
local thanhTabNgang = tao("Frame", {
    Position = UDim2.new(0, 12, 0, 58),
    Size = UDim2.new(1, -24, 0, 36),
    BackgroundTransparency = 1,
}, menuChinh)

tao("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 6),
}, thanhTabNgang)

local khungNoiDung = tao("Frame", {
    Position = UDim2.new(0, 12, 0, 102),
    Size = UDim2.new(1, -24, 1, -112),
    BackgroundTransparency = 1,
}, menuChinh)

local tieuDeTrang = tao("TextLabel", {
    Position = UDim2.new(0, 8, 0, 4),
    Size = UDim2.new(1, -16, 0, 24),
    BackgroundTransparency = 1,
    Text = "TRANG CHỦ / TỔNG QUAN",
    TextColor3 = Mau.Trang,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
}, khungNoiDung)

local moTaTrang = tao("TextLabel", {
    Position = UDim2.new(0, 8, 0, 26),
    Size = UDim2.new(1, -16, 0, 16),
    BackgroundTransparency = 1,
    Text = "Không gian của bạn. Phong cách của bạn.",
    TextColor3 = Mau.Mo,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Gotham,
    TextSize = 10,
}, khungNoiDung)

local khungCuon = tao("ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, 48),
    Size = UDim2.new(1, 0, 1, -50),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Mau.Do,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, khungNoiDung)

tao("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, khungCuon)

local PopoutFrame = tao("Frame", {
    Name = "PopoutFrameKien",
    Size = UDim2.fromOffset(200, 140),
    Position = UDim2.new(0.65, 0, 0.35, 0),
    BackgroundColor3 = Color3.fromRGB(12, 12, 16),
    BorderSizePixel = 0,
    Visible = false,
    ClipsDescendants = true,
}, screenGui)
boGoc(PopoutFrame, 12)
vien(PopoutFrame, Mau.Do, 1.2, 0.2)
makeDraggable(PopoutFrame)

local PopoutTopBar = tao("Frame", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Mau.Panel,
    BorderSizePixel = 0,
}, PopoutFrame)
boGoc(PopoutTopBar, 12)

tao("TextLabel", {
    Position = UDim2.new(0, 10, 0, 0),
    Size = UDim2.new(1, -10, 1, 0),
    BackgroundTransparency = 1,
    Text = "⚡ ĐIỀU KHIỂN NHANH",
    TextColor3 = Mau.Trang,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
}, PopoutTopBar)

local PopoutContent = tao("Frame", {
    Position = UDim2.new(0, 10, 0, 34),
    Size = UDim2.new(1, -20, 1, -40),
    BackgroundTransparency = 1,
}, PopoutFrame)

tao("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, PopoutContent)
local function taoControlNhanh(parent)
    local btn1 = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Mau.Panel,
        Text = "🚀 Chạy Về Base 1",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false,
    }, parent)
    boGoc(btn1, 6)
    vien(btn1, Mau.Do, 1, 0.4)

    local btn2 = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Mau.Panel,
        Text = "🚀 Chạy Về Base 2",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false,
    }, parent)
    boGoc(btn2, 6)
    vien(btn2, Mau.Do, 1, 0.4)

    local btn3 = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(180, 40, 40),
        Text = "🛑 Dừng Lại Ngay",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false,
    }, parent)
    boGoc(btn3, 6)
    vien(btn3, Mau.Trang, 1, 0.3)

    return btn1, btn2, btn3
end

local g1, g2, g3 = taoControlNhanh(PopoutContent)

local function stopWalking()
    isAutoWalking = false
    isFlyingToPlayer = false
    autoFarmEggEnabled = false
    currentTargetEgg = nil
    if eggEspBillboard then eggEspBillboard:Destroy() eggEspBillboard = nil end
    if moveConnection then moveConnection:Disconnect() moveConnection = nil end
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if eggFarmConnection then eggFarmConnection:Disconnect() eggFarmConnection = nil end
    local char = nguoiDung.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid:Move(Vector3.new(0, 0, 0), false) end
end

local function startMoveTo(targetPos, tenBase)
    if moveConnection then moveConnection:Disconnect() end
    isAutoWalking = true
    hienThongBao("Đang tự chạy về " .. tenBase .. "...")

    moveConnection = RunService.RenderStepped:Connect(function()
        if not isAutoWalking then stopWalking() return end
        local char = nguoiDung.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not targetPos or not humanoid or not hrp or humanoid.Health <= 0 then
            stopWalking()
            hienThongBao("Đã dừng: Mất tọa độ hoặc nhân vật chết!")
            return
        end

        local currentPos = hrp.Position
        local dirVector = Vector3.new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)
        if dirVector.Magnitude < 4 then
            stopWalking()
            hienThongBao("Đã đến " .. tenBase .. " thành công!")
            return
        end
        humanoid:Move(dirVector.Unit, false)
    end)
end

g1.MouseButton1Click:Connect(function()
    if not basePositions.Base1 then hienThongBao("Chưa lưu tọa độ Base 1!") return end
    startMoveTo(basePositions.Base1, "Base 1")
end)

g2.MouseButton1Click:Connect(function()
    if not basePositions.Base2 then hienThongBao("Chưa lưu tọa độ Base 2!") return end
    startMoveTo(basePositions.Base2, "Base 2")
end)

g3.MouseButton1Click:Connect(function()
    stopWalking()
    hienThongBao("🛑 Đã dừng lại ngay lập tức!")
end)

local function batNhatVatPhamNhanh()
    instantPromptEnabled = true
    game.DescendantAdded:Connect(function(obj)
        if instantPromptEnabled and obj:IsA("ProximityPrompt") then obj.HoldDuration = 0 end
    end)
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then obj.HoldDuration = 0 end
    end
end
batNhatVatPhamNhanh()

-- HỆ THỐNG QUÉT FULL TRỨNG, ESP TRỨNG ĐƯỢC CHỌN VÀ TỰ ĐỘNG ĐỔI SAU 5 GIÂY
local function capNhatEspTrung(trung)
    if eggEspBillboard then eggEspBillboard:Destroy() eggEspBillboard = nil end
    if not trung then return end
    local part = trung.PrimaryPart or trung:FindFirstChildWhichIsA("BasePart")
    if part then
        eggEspBillboard = tao("BillboardGui", {
            Name = "EggEspTag",
            Size = UDim2.fromOffset(160, 40),
            StudsOffset = Vector3.new(0, 3, 0),
            AlwaysOnTop = true,
        }, part)
        tao("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "🎯 ĐANG ĐẬP: " .. trung.Name,
            TextColor3 = Mau.XanhNhe,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
        }, eggEspBillboard)
    end
end

local function layDanhSachTrung()
    local ds = {"Tất cả (Tự động gần nhất)"}
    local daCo = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (string.find(obj.Name, "Egg") or string.find(obj.Name, "Nebula") or string.find(obj.Name, "Plasma") or string.find(obj.Name, "Supernova")) then
            if not daCo[obj.Name] then
                daCo[obj.Name] = true
                table.insert(ds, obj.Name)
            end
        end
    end
    return ds
end

local function timTrungTheoLuaChon()
    local khoangCachNhat = math.huge
    local trungChon = nil
    local myChar = nguoiDung.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (string.find(obj.Name, "Egg") or string.find(obj.Name, "Nebula") or string.find(obj.Name, "Plasma") or string.find(obj.Name, "Supernova")) then
            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if part and not eggBlacklist[obj] then
                if selectedEggName == "Tất cả (Tự động gần nhất)" or obj.Name == selectedEggName then
                    local dist = (part.Position - myHrp.Position).Magnitude
                    if dist < khoangCachNhat then
                        khoangCachNhat = dist
                        trungChon = obj
                    end
                end
            end
        end
    end
    return trungChon
end

local function toggleAutoFarmEgg(state)
    autoFarmEggEnabled = state
    if autoFarmEggEnabled then
        hienThongBao("Radar Trứng: Đã Bật tự động quét & đập!")
        eggTimer = tick()
        if eggFarmConnection then eggFarmConnection:Disconnect() end
        eggFarmConnection = RunService.RenderStepped:Connect(function()
            if not autoFarmEggEnabled then return end
            local char = nguoiDung.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not humanoid or not hrp then return end

            -- Tự động đổi quả trứng sau mỗi 5 giây hoặc khi quả cũ mất
            if not currentTargetEgg or not currentTargetEgg.Parent or (tick() - eggTimer >= 5) then
                if currentTargetEgg then eggBlacklist[currentTargetEgg] = true end
                currentTargetEgg = timTrungTheoLuaChon()
                eggTimer = tick()
                capNhatEspTrung(currentTargetEgg)
                if not currentTargetEgg then
                    hienThongBao("Không tìm thấy trứng phù hợp! Đang quét lại...")
                    task.wait(1)
                    return
                end
            end

            local eggPart = currentTargetEgg.PrimaryPart or currentTargetEgg:FindFirstChildWhichIsA("BasePart")
            if eggPart then
                local dir = Vector3.new(eggPart.Position.X - hrp.Position.X, 0, eggPart.Position.Z - hrp.Position.Z)
                if dir.Magnitude > 4 then
                    humanoid:Move(dir.Unit, false)
                else
                    humanoid:Move(Vector3.new(0,0,0), false)
                    pcall(function()
                        if EggHitRequest then EggHitRequest:FireServer(currentTargetEgg) end
                    end)
                end
            else
                eggBlacklist[currentTargetEgg] = true
                currentTargetEgg = nil
            end
        end)
    else
        if eggFarmConnection then eggFarmConnection:Disconnect() eggFarmConnection = nil end
        if eggEspBillboard then eggEspBillboard:Destroy() eggEspBillboard = nil end
        currentTargetEgg = nil
        hienThongBao("Radar Trứng: Đã Tắt!")
    end
	end
local function taoEspChoPlayer(player)
    if player == nguoiDung then return end
    local function onCharacterAdded(char)
        local head = char:WaitForChild("Head", 5)
        if head and not head:FindFirstChild("KienEspTag") then
            local billboard = tao("BillboardGui", {
                Name = "KienEspTag",
                Size = UDim2.fromOffset(180, 45),
                StudsOffset = Vector3.new(0, 2.8, 0),
                AlwaysOnTop = true,
            }, head)

            local txt = tao("TextLabel", {
                Name = "EspText",
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = player.Name,
                TextColor3 = Mau.Tim,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
            }, billboard)

            local conn
            conn = RunService.RenderStepped:Connect(function()
                if not billboard.Parent or not nguoiDung.Character or not nguoiDung.Character:FindFirstChild("HumanoidRootPart") then
                    if conn then conn:Disconnect() end
                    return
                end
                local myHrp = nguoiDung.Character.HumanoidRootPart
                local targetHrp = char:FindFirstChild("HumanoidRootPart")
                if targetHrp then
                    local distance = math.floor((targetHrp.Position - myHrp.Position).Magnitude)
                    txt.Text = player.Name .. " [" .. distance .. "m]"
                end
            end)
            table.insert(activeEspTags, billboard)
        end
    end
    if player.Character then onCharacterAdded(player.Character) end
    player.CharacterAdded:Connect(onCharacterAdded)
end

local function toggleEsp(state)
    espEnabled = state
    if espEnabled then
        for _, p in ipairs(Players:GetPlayers()) do taoEspChoPlayer(p) end
        Players.PlayerAdded:Connect(taoEspChoPlayer)
        hienThongBao("Đã bật định vị player & khoảng cách!")
    else
        for _, tag in ipairs(activeEspTags) do tag:Destroy() end
        activeEspTags = {}
        hienThongBao("Đã tắt định vị người chơi!")
    end
end

local function bayToiPlayer(targetPlayer)
    if flyConnection then flyConnection:Disconnect() end
    targetFlyPlayer = targetPlayer
    isFlyingToPlayer = true
    hienThongBao("Đang bay tốc độ 150 đến " .. targetPlayer.Name .. "...")

    flyConnection = RunService.RenderStepped:Connect(function(dt)
        if not isFlyingToPlayer or not targetFlyPlayer or not targetFlyPlayer.Character then
            if flyConnection then flyConnection:Disconnect() flyConnection = nil end
            return
        end

        local myChar = nguoiDung.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local targetChar = targetFlyPlayer.Character
        local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

        if myHrp and targetHrp then
            local direction = (targetHrp.Position - myHrp.Position)
            local distance = direction.Magnitude
            if distance < 6 then
                isFlyingToPlayer = false
                if flyConnection then flyConnection:Disconnect() flyConnection = nil end
                hienThongBao("Đã đến cạnh " .. targetFlyPlayer.Name .. "!")
                return
            end
            myHrp.CFrame = myHrp.CFrame + (direction.Unit * 150 * dt)
            myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end)
end

local function hopServer()
    hienThongBao("Đang tìm server ít người...")
    local placeId = game.PlaceId
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if success and result and result.data then
        for _, s in ipairs(result.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(placeId, s.id, nguoiDung)
                return
            end
        end
    end
    hienThongBao("Không tìm thấy server phù hợp!")
end

local function rejoinGame()
    hienThongBao("Đang kết nối lại server...")
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, nguoiDung)
end

local function moBangChonPlayer(parent)
    local frameChon = tao("Frame", {
        Size = UDim2.new(1, 0, 0, 240),
        BackgroundColor3 = Mau.Panel,
        BorderSizePixel = 0,
    }, parent)
    boGoc(frameChon, 10)
    vien(frameChon, Mau.Do, 1, 0.4)

    local searchBox = tao("TextBox", {
        Position = UDim2.new(0, 10, 0, 10),
        Size = UDim2.new(1, -20, 0, 30),
        BackgroundColor3 = Mau.The,
        TextColor3 = Mau.Trang,
        PlaceholderText = "🔍 Nhập tên người chơi để tìm...",
        PlaceholderColor3 = Mau.Mo,
        Text = "",
        TextSize = 11,
        Font = Enum.Font.Gotham,
    }, frameChon)
    boGoc(searchBox, 6)
    vien(searchBox, Mau.Do, 1, 0.5)

    local scrollPlayers = tao("ScrollingFrame", {
        Position = UDim2.new(0, 10, 0, 50),
        Size = UDim2.new(1, -20, 1, -60),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Mau.Do,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, frameChon)
    tao("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, scrollPlayers)

    local function taiDanhSach(filterText)
        for _, child in ipairs(scrollPlayers:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= nguoiDung then
                if filterText == "" or string.find(string.lower(p.Name), string.lower(filterText)) then
                    local pBtn = tao("TextButton", {
                        Size = UDim2.new(1, 0, 0, 32),
                        BackgroundColor3 = Mau.The,
                        Text = "👤 " .. p.Name,
                        TextColor3 = Mau.Trang,
                        Font = Enum.Font.GothamBold,
                        TextSize = 11,
                        AutoButtonColor = false,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }, scrollPlayers)
                    boGoc(pBtn, 6)
                    vien(pBtn, Mau.Tim, 1, 0.5)

                    pBtn.MouseButton1Click:Connect(function() bayToiPlayer(p) end)
                end
            end
        end
    end
    taiDanhSach("")
    searchBox:GetPropertyChangedSignal("Text"):Connect(function() taiDanhSach(searchBox.Text) end)
end

local function xayDungTabTools(parent)
    local espBtn = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Mau.Panel,
        Text = "👁️ Định Vị Player (Tên + Khoảng Cách): OFF",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false,
    }, parent)
    boGoc(espBtn, 8)
    vien(espBtn, Mau.Do, 1, 0.4)

    local radarEggBtn = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Mau.Panel,
        Text = "🥚 Radar Trứng: OFF",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false,
    }, parent)
    boGoc(radarEggBtn, 8)
    vien(radarEggBtn, Mau.Do, 1, 0.4)

    -- KHUNG LỰA CHỌN QUẢ TRỨNG QUÉT FULL TRÊN MAP
    local eggDropdownLabel = tao("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = "🎯 Chọn Loại Trứng Đập (Đang chọn: Tất cả):",
        TextColor3 = Mau.Mo,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)

    local scrollEggs = tao("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 110),
        BackgroundColor3 = Mau.Panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Mau.Do,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, parent)
    boGoc(scrollEggs, 8)
    vien(scrollEggs, Mau.Do, 1, 0.4)
    tao("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, scrollEggs)

    local function taiDanhSachTrangTrung()
        for _, child in ipairs(scrollEggs:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, tenTrung in ipairs(layDanhSachTrung()) do
            local eBtn = tao("TextButton", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = (selectedEggName == tenTrung) and Mau.DoDam or Mau.The,
                Text = "🥚 " .. tenTrung,
                TextColor3 = Mau.Trang,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                AutoButtonColor = false,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, scrollEggs)
            boGoc(eBtn, 6)
            eBtn.MouseButton1Click:Connect(function()
                selectedEggName = tenTrung
                eggDropdownLabel.Text = "🎯 Chọn Loại Trứng Đập (Đang chọn: " .. tenTrung .. "):"
                hienThongBao("Đã chọn loại trứng: " .. tenTrung)
                taiDanhSachTrangTrung()
            end)
        end
    end
    taiDanhSachTrangTrung()

    local refreshEggBtn = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(80, 80, 120),
        Text = "🔄 Quét Lại Danh Sách Trứng Trên Map",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false,
    }, parent)
    boGoc(refreshEggBtn, 6)
    refreshEggBtn.MouseButton1Click:Connect(function()
        taiDanhSachTrangTrung()
        hienThongBao("Đã quét lại danh sách trứng!")
    end)

    local hopBtn = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(100, 50, 180),
        Text = "🌐 Hop Server Ít Người",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false,
    }, parent)
    boGoc(hopBtn, 8)
    vien(hopBtn, Mau.Do, 1, 0.4)

    local rejoinBtn = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(40, 140, 80),
        Text = "🔄 Vào Lại Server (Rejoin)",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false,
    }, parent)
    boGoc(rejoinBtn, 8)
    vien(rejoinBtn, Mau.Trang, 1, 0.3)

    espBtn.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        if espEnabled then
            espBtn.Text = "👁️ Định Vị Player (Tên + Khoảng Cách): ON"
            espBtn.BackgroundColor3 = Mau.DoDam
        else
            espBtn.Text = "👁️ Định Vị Player (Tên + Khoảng Cách): OFF"
            espBtn.BackgroundColor3 = Mau.Panel
        end
        toggleEsp(espEnabled)
    end)

    radarEggBtn.MouseButton1Click:Connect(function()
        autoFarmEggEnabled = not autoFarmEggEnabled
        if autoFarmEggEnabled then
            radarEggBtn.Text = "🥚 Radar Trứng: ON"
            radarEggBtn.BackgroundColor3 = Mau.DoDam
        else
            radarEggBtn.Text = "🥚 Radar Trứng: OFF"
            radarEggBtn.BackgroundColor3 = Mau.Panel
        end
        toggleAutoFarmEgg(autoFarmEggEnabled)
    end)

    hopBtn.MouseButton1Click:Connect(hopServer)
    rejoinBtn.MouseButton1Click:Connect(rejoinGame)
end

local function xayDungTabTeleport(parent)
    tao("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = "🎯 CHỌN NGƯỜI CHƠI ĐỂ BAY (TỐC ĐỘ 150):",
        TextColor3 = Mau.Mo,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
    moBangChonPlayer(parent)
    local stopFlyBtn = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(180, 40, 40),
        Text = "🛑 DỪNG KHẨN CẤP BAY / RADAR",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
    }, parent)
    boGoc(stopFlyBtn, 8)
    vien(stopFlyBtn, Mau.Trang, 1, 0.3)
    stopFlyBtn.MouseButton1Click:Connect(function()
        stopWalking()
        hienThongBao("🛑 Đã dừng khẩn cấp toàn bộ tự động!")
    end)
end

local function xayDungTabAuto(parent)
    local save1 = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Mau.Panel,
        Text = "📍 Lưu Tọa Độ Vị Trí 1",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
    }, parent)
    boGoc(save1, 8)
    vien(save1, Mau.Do, 1, 0.4)

    local save2 = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Mau.Panel,
        Text = "📍 Lưu Tọa Độ Vị Trí 2",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
    }, parent)
    boGoc(save2, 8)
    vien(save2, Mau.Do, 1, 0.4)

    local tachBtn = tao("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(100, 50, 150),
        Text = "📌 Tách Bảng Điều Khiển Nhanh Ra Ngoài",
        TextColor3 = Mau.Trang,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
    }, parent)
    boGoc(tachBtn, 8)
    vien(tachBtn, Mau.Do, 1, 0.4)

    local lbl = tao("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "Base 1: Chưa lưu | Base 2: Chưa lưu",
        TextColor3 = Mau.Mo,
        TextXAlignment = Enum.TextXAlignment.Center,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
    }, parent)

    save1.MouseButton1Click:Connect(function()
        local char = nguoiDung.Character or nguoiDung.CharacterAdded:Wait()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            basePositions.Base1 = hrp.Position
            save1.Text = "📍 Vị Trí 1: Đã lưu"
            lbl.Text = "Base 1: Đã lưu | Base 2: " .. (basePositions.Base2 and "Đã lưu" or "Chưa")
            hienThongBao("Đã lưu Base 1 thành công!")
        end
    end)

    save2.MouseButton1Click:Connect(function()
        local char = nguoiDung.Character or nguoiDung.CharacterAdded:Wait()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            basePositions.Base2 = hrp.Position
            save2.Text = "📍 Vị Trí 2: Đã lưu"
            lbl.Text = "Base 1: " .. (basePositions.Base1 and "Đã lưu" or "Chưa") .. " | Base 2: Đã lưu"
            hienThongBao("Đã lưu Base 2 thành công!")
        end
    end)

    tachBtn.MouseButton1Click:Connect(function()
        isPoppedOut = not isPoppedOut
        if isPoppedOut then
            PopoutFrame.Visible = true
            tachBtn.Text = "📌 Đã Tách Bảng Ra Ngoài"
            hienThongBao("Đã tách bảng thành công!")
        else
            PopoutFrame.Visible = false
            tachBtn.Text = "📌 Tách Bảng Điều Khiển Nhanh Ra Ngoài"
            hienThongBao("Đã thu hồi bảng về Menu!")
        end
    end)
end

local danhSachTrang = {
    TRANG_CHU = {
        TieuDe = "TRANG CHỦ / TỔNG QUAN",
        MoTa = "Chào mừng bạn đến với Kiên Script",
        Muc = {
            {Loai = "banner", TieuDe = "BLACK NEBULA M1", MoTa = "Giao diện đỏ đen độc quyền — by ? Tiktok"},
            {Loai = "info", TieuDe = "TRẠNG THÁI", MoTa = "Radar Quét Full Trứng, Tăng FPS, Nhặt đồ nhanh sẵn sàng."},
        },
    },
    NHAN_DOI = {
        TieuDe = "NHÂN ĐÔI ĐAM / CÀI ĐẶT",
        MoTa = "Chọn hệ số nhân sát thương khi mở trứng",
        Muc = {
            {Loai = "mult", TieuDe = "Hệ số nhân sát thương (1x - 5x)", MoTa = "Tăng tốc độ và tối ưu số lượng đòn đánh mở trứng."},
        },
    },
    AUTO_BASE = {
        TieuDe = "TỰ ĐỘNG CHẠY VỊ TRÍ",
        MoTa = "Lưu tọa độ vị trí và bật bảng chạy nhanh",
        Muc = {
            {Loai = "autobase"},
        },
    },
    TELEPORT = {
        TieuDe = "BAY TỚI NGƯỜI CHƠI",
        MoTa = "Chọn player, tìm kiếm tên và bay tốc độ 150",
        Muc = {
            {Loai = "teleport"},
        },
    },
    TOOLS = {
        TieuDe = "TIỆN ÍCH & RADAR TRỨNG",
        MoTa = "Quét full trứng map, Định vị player & Hop server",
        Muc = {
            {Loai = "tools"},
        },
    },
    THONG_TIN = {
        TieuDe = "THÔNG TIN / TÁC GIẢ",
        MoTa = "Chi tiết dự án cá nhân",
        Muc = {
            {Loai = "info", TieuDe = "CHỦ SỞ HỮU", MoTa = "KIÊN (√12kientomato)"},
            {Loai = "info", TieuDe = "CHỮ KÝ", MoTa = "by ? Tiktok"},
        },
    },
}

local function xoaNoiDungCu()
    for _, child in ipairs(khungCuon:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "UIListLayout" then child:Destroy() end
    end
end

local function taoThe(tieuDeText, moTaText, chieuCao)
    local the = tao("Frame", {
        Size = UDim2.new(1, -4, 0, chieuCao or 68),
        BackgroundColor3 = Mau.The,
        BorderSizePixel = 0,
    }, khungCuon)
    boGoc(the, 12)
    vien(the, Mau.DoDam, 1, 0.35)

    tao("TextLabel", {
        Position = UDim2.new(0, 14, 0, 11),
        Size = UDim2.new(1, -28, 0, 20),
        BackgroundTransparency = 1,
        Text = tieuDeText,
        TextColor3 = Mau.Trang,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
    }, the)

    tao("TextLabel", {
        Position = UDim2.new(0, 14, 0, 34),
        Size = UDim2.new(1, -28, 0, 22),
        BackgroundTransparency = 1,
        Text = moTaText,
        TextColor3 = Mau.Mo,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextWrapped = true,
    }, the)
    return the
end

local function hienThiTrang(tenTrang)
    local duLieu = danhSachTrang[tenTrang]
    if not duLieu then return end

    tieuDeTrang.Text = duLieu.TieuDe
    moTaTrang.Text = duLieu.MoTa
    xoaNoiDungCu()

    for _, item in ipairs(duLieu.Muc) do
        if item.Loai == "banner" then
            local the = taoThe(item.TieuDe, item.MoTa, 90)
            tao("Frame", {
                Position = UDim2.new(0, 14, 1, -5),
                Size = UDim2.new(0.45, 0, 0, 2),
                BackgroundColor3 = Mau.Do,
                BorderSizePixel = 0,
            }, the)
        elseif item.Loai == "mult" then
            local the = taoThe(item.TieuDe, item.MoTa, 85)
            local nutChua = tao("Frame", {
                Position = UDim2.new(0, 14, 0, 52),
                Size = UDim2.new(1, -28, 0, 28),
                BackgroundTransparency = 1,
            }, the)

            tao("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, nutChua)

            local heSo = {1, 2, 3, 4, 5}
            local danhSachNut = {}

            for _, val in ipairs(heSo) do
                local nutM = tao("TextButton", {
                    Size = UDim2.new(0, 42, 0, 26),
                    BackgroundColor3 = (val == kienCurrentMultiplier) and Mau.DoDam or Mau.Panel,
                    Text = val .. "x",
                    TextColor3 = Mau.Trang,
                    Font = Enum.Font.GothamBold,
                    TextSize = 12,
                    AutoButtonColor = false,
                }, nutChua)
                boGoc(nutM, 6)
                vien(nutM, Mau.Do, 1, 0.5)
                danhSachNut[val] = nutM

                nutM.Activated:Connect(function()
                    kienCurrentM	
