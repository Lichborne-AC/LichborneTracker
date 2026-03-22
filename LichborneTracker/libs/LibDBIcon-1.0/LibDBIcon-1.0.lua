-- LibDBIcon-1.0
-- Provides circular minimap buttons for LibDataBroker data objects
assert(LibStub, "LibDBIcon-1.0 requires LibStub")

local DBICON10, DBICON10_MINOR = "LibDBIcon-1.0", 46
local lib = LibStub:NewLibrary(DBICON10, DBICON10_MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbackregistered = lib.callbackregistered or nil
lib.notregistered = lib.notregistered or {}
lib.radius = lib.radius or 80
lib.tooltip = lib.tooltip or nil

local function getAngle(obj)
	return (obj.db and obj.db.minimapPos) or obj.minimapPos or 220
end

local function updatePosition(button, angle)
	local x = math.cos(math.rad(angle)) * lib.radius
	local y = math.sin(math.rad(angle)) * lib.radius
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function onDragStart(self)
	self:SetScript("OnUpdate", function()
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local s = UIParent:GetScale()
		local angle = math.deg(math.atan2(py/s - my, px/s - mx))
		if self.db then
			self.db.minimapPos = angle
		else
			self.minimapPos = angle
		end
		updatePosition(self, angle)
	end)
end

local function onDragStop(self)
	self:SetScript("OnUpdate", nil)
end

local function createButton(name, object, db)
	local button = CreateFrame("Button", "LibDBIcon10_"..name, MinimapCluster)
	button:SetSize(31, 31)
	button:SetFrameStrata("HIGH")
	button:SetFrameLevel(9)

	-- Icon
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexture(object.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	button.icon:SetSize(17, 17)
	button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)

	-- Border ring
	button.border = button:CreateTexture(nil, "OVERLAY")
	button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	button.border:SetSize(56, 56)
	button.border:SetPoint("TOPLEFT", button, "TOPLEFT", -12, 12)

	-- Highlight
	button.hl = button:CreateTexture(nil, "HIGHLIGHT")
	button.hl:SetTexture("Interface\\Minimap\\MiniMap-TrackingButton-Highlight")
	button.hl:SetSize(31, 31)
	button.hl:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.hl:SetBlendMode("ADD")

	button.db = db
	button.dataObject = object
	button.minimapPos = (db and db.minimapPos) or 220

	button:RegisterForDrag("LeftButton")
	button:SetScript("OnDragStart", onDragStart)
	button:SetScript("OnDragStop", onDragStop)

	button:SetScript("OnEnter", function(self)
		if object.OnTooltipShow then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			object.OnTooltipShow(GameTooltip)
			GameTooltip:Show()
		elseif object.tooltiptext then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetText(object.tooltiptext)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnClick", function(self, btn)
		if object.OnClick then object.OnClick(self, btn) end
	end)

	updatePosition(button, getAngle(button))
	button:Show()
	return button
end

function lib:Register(name, object, db)
	if not object.type then error("Cannot register LDB objects without a type.") end
	if self.objects[name] then return end
	local button = createButton(name, object, db)
	self.objects[name] = button
	if db and db.hide then button:Hide() end
	return button
end

function lib:Unregister(name)
	if not self.objects[name] then return end
	self.objects[name]:Hide()
	self.objects[name] = nil
end

function lib:Show(name)
	if self.objects[name] then self.objects[name]:Show() end
end

function lib:Hide(name)
	if self.objects[name] then self.objects[name]:Hide() end
end

function lib:IsRegistered(name)
	return self.objects[name] and true or false
end

function lib:Refresh(name, db)
	local button = self.objects[name]
	if not button then return end
	if db then button.db = db end
	local angle = (button.db and button.db.minimapPos) or button.minimapPos or 220
	local x = math.cos(math.rad(angle)) * lib.radius
	local y = math.sin(math.rad(angle)) * lib.radius
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
