local handler = cargBags.Handler.Anywhere
local thisPlayer = GetRealmName()..", "..UnitName("player")
local values, dropdown

local function onClick(self)
	UIDropDownMenu_SetSelectedValue(dropdown, self.value)
	local realm, player = self.value:match("(.+), (.+)")
	handler:SetPlayer(realm, player)
end

local function update()
	local info = {}
	if(not values) then
		values = {}
		for realm, db in pairs (cB_Anywhere) do
			for player, _ in pairs(db) do
				values[#values+1] = realm..", "..player
			end
		end
		table.sort(values, function(a,b) return a<b end)
	end

	for i, value in ipairs(values) do
		local selectedValue = UIDropDownMenu_GetSelectedValue(dropdown)
		info.text = value
		info.value = value
		info.func =  onClick

		if(value == thisPlayer) then
			info.colorCode = "|cff00ff00"
		else
			info.colorCode = nil
		end

		if(i == selectedValue) then
			info.checked = true
		else
			info.checked = nil
		end
		UIDropDownMenu_AddButton(info)
	end
end

local function CreateDropDown()
	dropdown = CreateFrame("Frame", "cargBagsAnywhereSelect", UIParent, "UIDropDownMenuTemplate")
	dropdown:SetID(1)
	UIDropDownMenu_Initialize(dropdown, update, "MENU")
	UIDropDownMenu_SetSelectedValue(dropdown, thisPlayer)
	UIDropDownMenu_SetWidth(dropdown, 90)
	return dropdown
end

local function showDropdown(self)
	local y = self:GetBottom() >= GetScreenHeight()/2 and "TOP" or "BOTTOM"
	local x = self:GetRight() >= GetScreenWidth()/2 and "LEFT" or "RIGHT"
	ToggleDropDownMenu(1, nil, dropdown or CreateDropDown(), self, 0, 0)
end

cargBags:RegisterPlugin("Anywhere", function(self, frame)
	local plugin
	if(frame) then
		plugin = frame
	else
		plugin = CreateFrame("Button", nil, self)
		plugin:SetWidth(24)
		plugin:SetHeight(24)
		plugin:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]])
		plugin:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down]])
		plugin:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
	end
	plugin.Object = self
	plugin:SetScript("OnClick", showDropdown)
	return plugin
end)