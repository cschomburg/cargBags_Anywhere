--[[doc
h1. API: Anywhere-Handler

*Description:*
	Provides item and container information for cargBags from an internal database

*Inherits from:*
	Standard-Handler

*Callback functions:*
*	:PostSetPlayer(realm, player, database): called when the selected player changes

*Handler functions:*
*	:GetPlayer(realm, player, database): Returns the currently set player
doc]]

local Anywhere = CreateFrame"Frame"
local handler = {}
local atBank
local db
local this
local curr, realm, player
local C2I, I2C = cargBags.C2I, cargBags.I2C

local function shortLink(link)
	return link and link:match('item:(%-?%d+):0:0:0:0:0:0:0') or link and link:match('item:(%-?%d+)') or link
end

function Anywhere:VARIABLES_LOADED()
	local thisPlayer = UnitName("player")
	local thisRealm = GetRealmName()

	cB_Anywhere = cB_Anywhere or {}
	db = cB_Anywhere

	db[thisRealm] = db[thisRealm] or {}
	db[thisRealm][thisPlayer] = db[thisRealm][thisPlayer] or {}

	this = db[thisRealm][thisPlayer]
	wThis = this
	this['money'] = GetMoney()
	curr = realm and player and db[realm] and db[realm][player] or this
	if(cargBags:GetHandler() == handler) then cargBags:UpdateBags() end
end

function Anywhere:PLAYER_MONEY()
	this['money'] = GetMoney()
end

function Anywhere:SaveBag(id)
	if(not this or (id == BANK_CONTAINER and not atBank)) then return end

	if(id > 0) then
		local slotID = C2I(id)
		this[slotID..'-link'] = shortLink(GetInventoryItemLink("player", slotID))
		this[slotID..'-texture'] = GetInventoryItemTexture("player", slotID)
	end
	local free, bagType = GetContainerNumFreeSlots(id)
	local slots = (id == KEYRING_CONTAINER and GetKeyRingSize()) or GetContainerNumSlots(id)

	this[id..'-free'] = free
	this[id..'-bagType'] = bagType
	this[id..'-slots'] = slots

	for i=1, slots do
		local texture, count = GetContainerItemInfo(id, i)
		if(texture) then
			this[id..'-'..i] = shortLink(GetContainerItemLink(id, i))..(count > 1 and ","..count or "")
		else
			this[id..'-'..i] = nil
		end
	end
end

function Anywhere:BAG_UPDATE(event, bag)
	if(event == "PLAYERBANKSLOTS_CHANGED") then
		if(bag <= NUM_BANKGENERIC_SLOTS) then
			bag = -1
		else
			bag = bag-NUM_BANKGENERIC_SLOTS
		end
	end
	if(bag and (not(bag == BANK_CONTAINER or bag > NUM_BAG_SLOTS) or atBank)) then
		self:SaveBag(bag)
	else
		for i = -1, NUM_BAG_SLOTS+(atBank and GetNumBankSlots() or 0) do
			self:SaveBag(i)
		end
	end
end
Anywhere.PLAYER_LOGIN = Anywhere.BAG_UPDATE
Anywhere.PLAYERBANKSLOTS_CHANGED = Anywhere.BAG_UPDATE

function Anywhere:BANKFRAME_OPENED()
	atBank = true
	self:SaveBag(BANK_CONTAINER)
	this['bankslots'] = GetNumBankSlots()
	for i = 1, this['bankslots'] do
		self:SaveBag(i + 4)
	end
end

function Anywhere:BANKFRAME_CLOSED() atBank = nil cargBags:UpdateBags() end

local function getData(bagID, slotID)
	local info = curr[bagID.."-"..slotID]
	local link, count
	if(info) then
		link, count = info:match("(.*),(.*)")
	end
	return link or info, count
end


--[[########################
	HANDLER
##########################]]
local standard = cargBags.Handler.Standard
local function useStandard(bagID)
	return standard and curr == this and (bagID and bagID ~= -1 and bagID < 5 or atBank)
end

function handler.GetContainerNumFreeSlots(id)
	if(useStandard(id)) then return standard.GetContainerNumFreeSlots(id) end
	return curr[id..'-free'] or 0, curr[id..'-bagType']
end

function handler.GetContainerNumSlots(id)
	if(useStandard(id)) then return standard.GetContainerNumSlots(id) end
	return curr[id..'-slots'] or 0
end

function handler.GetInventoryItemLink(unit, id)
	if(useStandard(I2C(id))) then return standard.GetInventoryItemLink(unit, id) end
	return curr[id.."-link"]
end
function handler.GetInventoryItemTexture(unit, id)
	if(useStandard(I2C(id))) then return standard.GetInventoryItemTexture(unit, id) end
	return curr[id.."-texture"]
end
function handler.GetNumBankSlots()
	if(useStandard(0)) then return standard.GetNumBankSlots() end
	return curr["bankslots"] or 0, true
end
function handler.GetMoney()
	if(useStandard(0)) then return standard.GetMoney() end
	return curr["money"] or 0
end

function handler.PickupBagFromSlot(id)
	if(useStandard(I2C(id))) then return standard.PickupBagFromSlot(id) end
end

function handler.PutItemInBag(id)
	if(useStandard(I2C(id))) then return standard.PutItemInBag(id) end
end

function handler.GetContainerItemLink(bagID, slotID)
	if(useStandard(bagID)) then return standard.GetContainerItemLink(bagID, slotID) end
	local link = getData(bagID, slotID)
	return link and select(2, GetItemInfo(getData(bagID, slotID)))
end

function handler.GetContainerItemInfo(bagID, slotID)
	if(useStandard(bagID)) then return standard.GetContainerItemInfo(bagID, slotID) end
	local link, count = getData(bagID, slotID)
	local _, link, quality, _, _, _, _, _, _, texture = GetItemInfo(link)
	return texture, tonumber(count) or 1, quality
end

function handler:SetPlayer(arg1, arg2, noUpdate)
	local prev = curr
	local new_realm, new_player
	if(arg1 and not arg2) then
		new_realm = GetRealmName()
		new_player = arg1
	elseif(arg1 and arg2) then
		new_realm = arg1
		new_player = arg2
	else
		new_realm = GetRealmName()
		new_player = UnitName("player")
	end
	curr = db and db[new_realm] and db[new_realm][new_player] or curr
	if(not curr or curr ~= prev) then
		realm, player = new_realm, new_player
		if(not noUpdate) then cargBags:UpdateBags() end
		if(handler.PostSetPlayer) then handler:PostSetPlayer(realm, player, curr) end
	end
end

function handler:GetPlayer()
	return realm, player, curr
end

function handler:Enable(arg1, arg2)
	self:SetPlayer(arg1, arg2, true)
	if(standard) then standard:Enable() end
end
function handler:Disable() if(standard) then standard:Disable() end end

function handler:GetButtonTemplateName(bagID, slotID)
	if(useStandard(bagID, slotID)) then
		return standard:GetButtonTemplateName(bagID, slotID)
	end
	return "LinkItemButton"
end

function buttonEnter(self)
	local info = self.id and curr[self.id.."-link"] or self.slotID and curr[self.bagID.."-"..self.slotID]
	local link = info and info:match("(.*),(.*)") or info
	if(not link) then return end

	local real = select(2, GetItemInfo(link))
	local x
	x = self:GetRight();
	if ( x >= ( GetScreenWidth() / 2 ) ) then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT");
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	end
	GameTooltip:SetHyperlink(real)
	GameTooltip:Show()
end
function buttonClick(self)
	local link = getData(self.bagID, self.slotID)
	if(link) then
		local real = select(2, GetItemInfo(link))
		HandleModifiedItemClick(real)
	end
end
function buttonLeave(self) GameTooltip:Hide() end

function handler.BagSlotButton_OnEnter(self)
	if(useStandard(self.bagID)) then
		standard.BagSlotButton_OnEnter(self)
	else
		buttonEnter(self)
	end
end

function handler:CreateButton(template, name)
	if(template ~= "LinkItemButton") then return standard:CreateButton(template, name) end
	local button = CreateFrame("Button", name, nil, "ItemButtonTemplate")
	button.Count = _G[name.."Count"]
	button.Icon = _G[name.."IconTexture"]
	button.Cooldown = _G[name.."Cooldown"]
	button.NormalTexture = _G[name.."NormalTexture"]
	button:SetHeight(37)
	button:SetWidth(37)
	button:SetScript("OnEnter", buttonEnter)
	button:SetScript("OnClick", buttonClick)
	button:SetScript("OnLeave", buttonLeave)
	return button
end

function handler:LoadItemInfo(i)
	if(useStandard(i.bagID)) then
		return standard:LoadItemInfo(i)
	end

	local link, count = getData(i.bagID, i.slotID)
	i.clink = link
	i.count = count and tonumber(count) or (link and 1)
	i.cdStart, i.cdFinish, i.cdEnable = 0,0,0
end

cargBags:RegisterHandler("Anywhere", handler)

Anywhere:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)
Anywhere:RegisterEvent"PLAYER_LOGIN"
Anywhere:RegisterEvent"VARIABLES_LOADED"
Anywhere:RegisterEvent"BANKFRAME_OPENED"
Anywhere:RegisterEvent"BANKFRAME_CLOSED"
Anywhere:RegisterEvent"PLAYER_MONEY"
Anywhere:RegisterEvent"BAG_UPDATE"
Anywhere:RegisterEvent"PLAYERBANKSLOTS_CHANGED"