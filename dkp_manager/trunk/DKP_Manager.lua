-----------------------------------------------------------------------------------------------
-- Client Lua Script for DKP_Manager
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
require "string"

-----------------------------------------------------------------------------------------------
-- DKP_Manager Module Definition
-----------------------------------------------------------------------------------------------
local DKP_Manager = {} 
local isWinTime = false

itemWeBetFor = "<TESTITEM>"
local dkpUserSettings = {
"itemBetTime",
"isAllowWhisper",
"isTwinkMode",
"engTime",
"DKPChatChannelSay",
"DKPChatChannelInstance",
"DKPChatChannelGroup",
"DKPChatChannelGuild",
"BnWChatChannelSay",
"BnWChatChannelInstance",
"BnWChatChannelGroup",
"dkpKtId",
"dkpItemPoolID",
"BnWChatChannelGuild"
}



 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressedFlyby")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")
 
   
-- Initialization
-----------------------------------------------------------------------------------------------
function DKP_Manager:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.tItems = {} -- keep track of all the list items
	o.tItemsLoot = {} -- keep track of all the loot list items
	o.wndSelectedListItem = nil -- keep track of which list item is currently selected
	o.dkpItems = {}
	o.betItem = {}
	o.reasonItem = {}
	o.tDKPKt = {}
	o.tDKPEvent = {}
	o.tDKPPlayers = {}

    return o
end

function DKP_Manager:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}

    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- DKP_Manager OnLoad
-----------------------------------------------------------------------------------------------
function DKP_Manager:OnLoad()
	Apollo.RegisterEventHandler("GuildRoster", "OnGuildRoster", self)
	Apollo.RegisterEventHandler("ChatMessage", "WhisperCommand", self)
	Apollo.RegisterEventHandler("Group_Join", "OnGroupJoin", self)
	Apollo.RegisterEventHandler("LootAssigned", "OnLootAssigned", self)
	
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("DKP_Manager.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
	self:DefaultSettings()
	self:GetTwinkString()	
end

-----------------------------------------------------------------------------------------------
-- DKP_Manager OnDocLoaded
-----------------------------------------------------------------------------------------------
function DKP_Manager:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "DKP_ManagerForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		self.wndItems = Apollo.LoadForm(self.xmlDoc, "DKP_ListItems", nil, self)
		if self.wndItems == nil then
			Apollo.AddAddonErrorText(self, "Could not load the List window for some reason.")
			return
		end
		self.wndBetAndWin = Apollo.LoadForm(self.xmlDoc, "DKP_BetAndWin",nil, self)
		if self.wndBetAndWin == nil then
			Apollo.AddAddonErrorText(self, "Could not load the BetAndWin Window for some reason.")
			return
		end
		self.wndImport = Apollo.LoadForm(self.xmlDoc, "DKP_Import",nil,self)

		
		
		self.wndSettings = Apollo.LoadForm(self.xmlDoc, "DKP_Settings",nil,self)
		self.wndSettingsList = Apollo.LoadForm(self.xmlDoc,"DKP_SettingsList", self.wndSettings:FindChild("SettingsList"),self)
		
		self.BnWAssigned = Apollo.LoadForm(self.xmlDoc,"DKP_BnW_Assigned", nil, self)
		
		-- item list
		self.wndItemList = self.wndMain:FindChild("ItemList")
		self.wndDKPItemList = self.wndItems:FindChild("ItemList")
		self.wndBetAndWinList = self.wndBetAndWin:FindChild("ItemList")
		self.wndBetAndWinItemList = self.wndBetAndWin:FindChild("ItemListBnW")
		self.wndReasonItemList = self.wndItems:FindChild("ReasonList")
		
		
		
	    self.wndMain:Show(false, true)
		self.wndItems:Show(false,true)
		self.wndBetAndWin:Show(false,true)
		self.wndSettings:Show(false,true)
		self.wndImport:Show(false,true)
		self.BnWAssigned:Show(false, true)
		--self.wndDKPKtList:Show(false,true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("dkp", "OnDKP_ManagerOn", self)
		Apollo.RegisterSlashCommand("dkpw", "OnDKP_BnWInit", self)
		Apollo.RegisterSlashCommand("dkpm", "OnDKP_RemoveDKP",self)
		Apollo.RegisterTimerHandler("OnSecTimer", "OnTimer", self)
		Apollo.RegisterEventHandler("MasterLootUpdate",	"OnMasterLootUpdate", self)
		
		
		self:GetTwinkString()
		



		-- Do additional Addon initialization here
		Event_FireGenericEvent("MasterLootUpdate")
	end
end


isFirstCalling = true
local betTime
function DKP_Manager:OnTimer()
if itemWeBetFor=="<TESTITEM>" then return end
if isFirstCalling == true then
	ChatSystemLib.Command(self:GetDKPChat("BnW") .. " You startet a Auction on ".. itemWeBetFor:GetChatLinkString() .. "! Please bet in the next ".. tostring(betTime) .. " Seconds!")
	betTime = betTime - 1.0
	isFirstCalling=false
elseif betTime >= 0 then
	if betTime == 45 or betTime == 30 or betTime == 10 or betTime == 5 or betTime == 3 or betTime == 2 or betTime == 1 then
		ChatSystemLib.Command(self:GetDKPChat("BnW") .. " Auction will End in ".. tostring(betTime) .. " Seconds!")
	elseif betTime == 0 then
		ChatSystemLib.Command(self:GetDKPChat("BnW") .. " Auction ended for ".. itemWeBetFor:GetChatLinkString() .. "!")
		isWinTime = false
	end
	betTime = betTime - 1.0
end
end

function DKP_Manager:GetDKPChat(sType)
if sType == "BnW" then
	if self.BnWChatChannelInstance then return "/i" end
	if self.BnWChatChannelGuild then return "/g" end 
	if self.BnWChatChannelSay then return "/s" end
	if self.BnWChatChannelGroup then return "/p" end 
elseif sType == "DKP" then
	if self.DKPChatChannelInstance then return "/i" end
	if self.DKPChatChannelGuild then return "/g" end 
	if self.DKPChatChannelSay then return "/s" end
	if self.DKPChatChannelGroup then return "/p" end 
end

end


function DKP_Manager:OnDKP_RemoveDKP()
ChatSystemLib.Command("/w EQDKP ok")
self.BnWAssigned:Invoke()

end


function DKP_Manager:OnConfig()
self:RefreshSettings()	
self.wndSettings:Invoke()
end

function DKP_Manager:GetTimeStringFromUnix(myTime, engTime)
strTime = os.date("*t", myTime)
if string.len(strTime.month) == 1 then strTime.month = ("0" .. strTime.month) end
if string.len(strTime.day) == 1 then strTime.day = ("0" .. strTime.day) end
if string.len(strTime.hour) == 1 then strTime.hour = ("0" .. strTime.hour) end
if string.len(strTime.min) == 1 then strTime.min = ("0" .. strTime.min) end

	if engTime == false then
		strNewTime = strTime.day .. "." .. strTime.month .. "." .. strTime.year .. " " .. strTime.hour .. ":" .. strTime.min
		return strNewTime
	else
		strNewTime = strTime.year .. "-" .. strTime.month .. "-" .. strTime.day .. ""
			if strTime.hour > 12 and strTime.hour < 23 then
				strHour = strTime.hour - 12
				if string.len(strHour) == 1 then strHour = ("0" .. strHour) end
				strNewTime = strNewTime .. " " .. strHour .. ":" .. strTime.min .. "pm"
			else
				if string.len(strTime.hour) == 1 then strTime.hour = ("0" .. strTime.hour) end
				strNewTime = strNewTime .. " " .. strTime.hour .. ":" .. strTime.min .. "am"
			end
	return strNewTime
	end
end


-- Save User Settings
function DKP_Manager:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end

	local tSave = {}
	for idx,property in ipairs(dkpUserSettings) do tSave[property] = self[property] end
	tSave["eqdkp"] = eqdkp
	tSave["game"] = game
	tSave["info"] = info
	tSave["players"] = players
	tSave["multidkp_pools"] = multidkp_pools
	tSave["itempools"] = itempools
	tSave["dkpr"] = dkpr
	--tSave["DKP_ITEMS"] = DKP_ITEMS
	return tSave
	
end


-- Restore Saved User Settings
function DKP_Manager:OnRestore(eType, t)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	
	for idx,property in ipairs(dkpUserSettings) do
		if t[property] ~= nil then self[property] = t[property] end
	end
	eqdkp = t["eqdkp"]
	game = t["game"]
	info = t["info"]
	players = t["players"]
	multidkp_pools = t["multidkp_pools"]
	itempools = t["itempools"]
	dkpr = t["dkpr"]
	self:GetTwinkString()
end

function DKP_Manager:DefaultSettings()
	self.itemBetTime = 10;
	self.dkpKtId = 1;
	self.isTwinkMode = false;
	self.DKPChatChannelSay = true;
	self.DKPChatChannelInstance = false;
	self.DKPChatChannelGroup = false;
	self.DKPChatChannelGuild = false;
	self.BnWChatChannelSay = true;
	self.BnWChatChannelInstance = false;
	self.BnWChatChannelGroup = false;
	self.BnWChatChannelGuild = false;
	self.isAllowWhisper = true;
	self.engTime = true;
	self.dkpItemPoolID = 1;
	tMasterLoot = {}
	tMasterLootItemList = {}
	tLooterItemList = {}
	eqdkp = {}
	game = {}
	info = {}
	players = {}
	multidkp_pools = {}
	itempools = {}
	dkpr = {}
	self:GetTwinkString()
	--tSave["DKP_ITEMS"] = DKP_ITEMS
end

function DKP_Manager:RefreshSettings()
	if self.DKPChatChannelSay ~= nil then
	self:GetTwinkString()
	self.wndSettings:FindChild("btn_DKPSettings_ChatSay"):SetCheck(self.DKPChatChannelSay)
	self.wndSettings:FindChild("btn_DKPSettings_EnableTwinkMode"):SetCheck(self.isTwinkMode)
	self.wndSettings:FindChild("btn_DKPSettings_ChatInstance"):SetCheck(self.DKPChatChannelInstance)
	self.wndSettings:FindChild("btn_DKPSettings_ChatGroup"):SetCheck(self.DKPChatChannelGroup)
	self.wndSettings:FindChild("btn_DKPSettings_ChatGuild"):SetCheck(self.DKPChatChannelGuild)
	self.wndSettings:FindChild("btn_DKPSettings_EnableWhisper"):SetCheck(self.isAllowWhisper)
	self.wndSettings:FindChild("Slider_DrawTimer"):SetValue(self.itemBetTime)
	self.wndSettings:FindChild("Label_DrawTimerDisplay"):SetText(tostring(self.itemBetTime) .. "s")
	self.wndSettings:FindChild("btn_BnWSettings_ChatSay"):SetCheck(self.BnWChatChannelSay)
	self.wndSettings:FindChild("btn_BnWSettings_ChatInstance"):SetCheck(self.BnWChatChannelInstance)
	self.wndSettings:FindChild("btn_BnWSettings_ChatGroup"):SetCheck(self.BnWChatChannelGroup)
	self.wndSettings:FindChild("btn_BnWSettings_ChatGuild"):SetCheck(self.BnWChatChannelGuild)
	if multidkp_pools ~= nil then
	self.wndSettings:FindChild("Label_KtDropDown_Name"):SetText(multidkp_pools[tonumber(self.dkpKtId)].desc)
	end
	self.wndSettings:FindChild("btn_DKPSettings_EnableEngTime"):SetCheck(self.engTime)
	end
	
end


function DKP_Manager:GetTwinkString()
	if self.isTwinkMode == true then
		adjustmentModeString = "points_adjustment_with_twink"
		pointsCurrentModeString = "points_current_with_twink"
		pointsEarnedModeString = "points_earned_with_twink"
		pointsSpendModeString = "points_spent_with_twink"
	else
		adjustmentModeString = "points_adjustment"
		pointsCurrentModeString = "points_current"
		pointsEarnedModeString = "points_earned"
		pointsSpendModeString = "points_spent"
	end
end


-----------------------------------------------------------------------------------------------
-- DKP_Manager Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/dkp"
function DKP_Manager:OnDKP_ManagerOn()
	self.wndMain:Show(true)-- show the window
	self:RefreshSettings()
	
	-- populate the item list
	self:PopulateItemList()
end

function DKP_Manager:OnDKP_BnWInit()
self.wndBetAndWin:Invoke()
end

function DKP_Manager:WhisperCommand(channelCurrent, tMessage)--bSelf, strSender, strRealmName, nPresenceState, arMessageSegments, unitSource, bShowChatBubble, bCrossFaction)
if GameLib.GetPlayerUnit() == nil then return end
if tMessage.bSelf then return end
if tMessage.strSender == nil then return end
if tMessage.strRealmName == nil then
	strCompleteName = tMessage.strSender
else
	strCompleteName = tMessage.strSender .. "@" .. tMessage.strRealmName
end
	local eChannel = channelCurrent:GetType()
	if not (eChannel == ChatSystemLib.ChatChannel_Whisper or eChannel == ChatSystemLib.ChatChannel_AccountWhisper) then return end
	if #tMessage.arMessageSegments == 0 or #tMessage.arMessageSegments > 1 then return end
	local strMessage = tMessage.arMessageSegments[1].strText:lower()

if strMessage == "\dkp" then
if self.isAllowWhisper == false then return end
	if not self:IsInGroup(tMessage.strSender) then 
		ChatSystemLib.Command("/w " .. strCompleteName .. " You are not in a Group or Raid with the DKP Manager!")
		return
	end
	local playerID = self:GetPlayerID(tMessage.strSender)
	if (players[playerID] == nil) then
		ChatSystemLib.Command("/w " .. strCompleteName .. " You are not registered in the current DKP Table!")
	elseif(players[playerID] ~= nil) then
		ChatSystemLib.Command("/w " .. strCompleteName .. " You have: " .. players[playerID]["points"][tonumber(self.dkpKtId)][pointsCurrentModeString] .. " DKPs")
			--SendChatMessage(WHISPER_PREFIX..TEXT_DKPInfo..gdkp.players[Username][gdkp_Konto.."_current"].." "..gdkp_Konto.." "..dkpstring, "WHISPER", this.language,arg2);
	else
		gdkp_Alias_found = "You are not in this Raid";
	end
elseif tonumber(strMessage) then
-- for debugging only.. after this we need to add self:isInGroup(tMessage.strSender) check
	if isWinTime then
		--if gdkp.players[tMessage.strSender] ~= nil then need to add after debuggsession
		strSender = tMessage.strSender
			self:AddListBidder(strSender, strMessage)
			self.wndBetAndWinList:ArrangeChildrenVert()
		--end
	
	ChatSystemLib.Command("/w " .. strCompleteName .. " You bet " ..strMessage.. " on " ..itemWeBetFor:GetChatLinkString().. "! ")
	end
end
end

function DKP_Manager:ReportDKP()
if (players == nil) then return end
for key,val in pairs(players) do
		--self:AddItem(key,gdkp.players[key].class,gdkp.players[key].dkp_current)
		ChatSystemLib.Command(self:GetDKPChat("DKP") .. " " .. players[key].name .. " " .. players[key].class_name .. " " .. players[key]["points"][tonumber(self.dkpKtId)][pointsCurrentModeString] .. " ")
	end;

--ChatSystemLib.PostOnChannel(DKPChatChannel,"yeah!")
end



function DKP_Manager:IsInGroup(strSender)
	for idx = 1, GroupLib.GetMemberCount() do
		local tMemberInfo = GroupLib.GetGroupMember(idx)
		if tMemberInfo ~= nil then
			if string.lower(tMemberInfo.strCharacterName) == string.lower(strSender) then 
				return true 
			end
		end
	end
	return false
end


-----------------------------------------------------------------------------------------------
-- DKP_ManagerForm Functions
-----------------------------------------------------------------------------------------------




function DKP_Manager:SearchDKPPlayers( wndHandler, wndControl, eMouseButton)

	local wndMain = Apollo.FindWindowByName("DKP_ManagerForm")
	local searchtext = wndMain:FindChild("txtSearch")
	--if string.find( strMessage,"\dkp" ) then
-- make sure the item list is empty to start with
	self:DestroyItemList()
	if (players == nil) then return end 
		for key,val in pairs(players) do
		
			strPlayerKey = key
			
				if string.find(string.lower(strPlayerKey), string.lower(searchtext:GetText())) then--strSearchText) then
					self:AddItem(players[key].name,players[key].class_name,players[key].self.pointsCurrentModeString)
				else
				--print("shut the fuck up!")
				end
			
		end
-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
	self.wndItemList:ArrangeChildrenVert()
--Print(searchtext:GetText())
--ChatSystemLib.PostOnChannel(6,searchtext,"Whiskeey")
end


function DKP_Manager:GetPlayerID(wichPlayer)
		for key,val in pairs(players) do
			if (players[key]["name"] == wichPlayer) then
			return key
			end
		end
end


function DKP_Manager:searchChanged( wndHandler, wndControl, strText )
	self:DestroyItemList()
	if (players == nil) then return end 

		for key,val in pairs(players) do
				strPlayerKey = players[key].name
			
				if string.find(string.lower(strPlayerKey), string.lower(strText)) then
					self:AddItem(strPlayerKey,players[key].class_name,players[key]["points"][tonumber(self.dkpKtId)][pointsCurrentModeString])
				
			end;
		end
	self.wndItemList:ArrangeChildrenVert()
end

function DKP_Manager:GetItemPool(itpID, ktID)

--multidkp_pools[1].mdkp_itempools
for key,val in pairs(multidkp_pools[ktID]["mdkp_itempools"]) do
	if multidkp_pools[ktID].mdkp_itempools[key] == itpID then
	return true
	end
end
end

-----------------------------------------------------------------------------------------------
-- ItemList Functions
-----------------------------------------------------------------------------------------------
-- populate item list
function DKP_Manager:PopulateItemList()
	-- make sure the item list is empty to start with
		self:DestroyItemList()
		if (players == nil) then
			return
		else 
		for key,val in pairs(players) do
			self:AddItem(players[key].name,players[key].class_name,players[key]["points"][tonumber(self.dkpKtId)][pointsCurrentModeString])
		end
	end;
	-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
	self.wndItemList:ArrangeChildrenVert()
end

function DKP_Manager:PopulateDKPKtList()
	-- make sure the item list is empty to start with
		self:DestroyDKPKtList()
		if (multidkp_pools == nil) then
			return
		else 
		for key,val in pairs(multidkp_pools) do
			self:AddDKPKtItem(key,multidkp_pools[key].desc)
		end
	end;
	-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
	self.wndDKPKtItemList:ArrangeChildrenVert()
end

function DKP_Manager:PopulateDKPPlayerList()
	-- make sure the item list is empty to start with
	
		self:DestroyDKPPlayerList()
		if (players== nil) then
			return
		else 
		
		for key,val in pairs(players) do
			self:AddDKPPlayerItem(players[key].name)
		end
	end;
	-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
	self.wndDKPPlayerItemList:ArrangeChildrenVert()
end

function DKP_Manager:PopulateDKPEventList()
	-- make sure the item list is empty to start with
		self:DestroyDKPEventList()
		if (multidkp_pools[self.dkpKtId].events == nil) then
			return
		else 
		for key,val in pairs(multidkp_pools[self.dkpKtId].events) do
			self:AddDKPEventItem(multidkp_pools[self.dkpKtId]["events"][key].id,multidkp_pools[self.dkpKtId]["events"][key].name)
		end
	end;
	-- now all the item are added, call ArrangeChildrenVert to list out the list items vertically
	self.wndDKPEventItemList:ArrangeChildrenVert()
end


-- clear the item list
function DKP_Manager:DestroyItemList()
	for key,val in pairs(self.tItems) do
		self.tItems[key]:Destroy()
	end

	-- clear the list item array
	self.tItems = {}
	self.wndSelectedListItem = nil
end

function DKP_Manager:DestroyDKPKtList()
	for key,val in pairs(self.tDKPKt) do
		self.tDKPKt[key]:Destroy()
	end

	-- clear the list item array
	self.tDKPKt = {}
	self.wndSelectedListItem = nil
end

function DKP_Manager:DestroyDKPPlayerList()
	for key,val in pairs(self.tDKPPlayers) do
		self.tDKPPlayers[key]:Destroy()
	end

	-- clear the list item array
	self.tDKPPlayers = {}
	self.wndSelectedListItem = nil
end

function DKP_Manager:DestroyDKPEventList()
	for key,val in pairs(self.tDKPKt) do
		self.tDKPEvent[key]:Destroy()
	end

	-- clear the list item array
	self.tDKPEvent = {}
	self.wndSelectedListItem = nil
end

function DKP_Manager:DestroyBetList(PlayerName)

	-- destroy all the wnd inside the list
	--wnd:Destroy()
	
	if PlayerName == "" then
		for key,val in pairs(self.betItem) do
			self.betItem[key]:Destroy()
		end
	else
		for key,val in pairs(self.betItem) do
			if key == PlayerName then
			self.betItem[key]:Destroy()
			end
		end
	end
	
	-- clear the list item array
	self.tItems = {}
	self.wndSelectedListItem = nil
end

-- clear the item list
function DKP_Manager:DestroyDKPItemList()
	-- destroy all the wnd inside the list
	--wnd:Destroy()
	
	for key,val in pairs(self.dkpItems) do
	--ChatSystemLib.PostOnChannel(6,val,"Whiskeey")
		self.dkpItems[key]:Destroy()
	end
	self.wndDKPItemList:ArrangeChildrenVert()

	-- clear the list item array
	self.dkpItems= {}
	end
	
function DKP_Manager:DestroyReasonList()
	for key,val in pairs(self.reasonItem) do
		self.reasonItem[key]:Destroy()
	--self.reasonItem[PlayerName] = wnd
	end
end
	




-- add an item into the item list
function DKP_Manager:AddItem(PlayerName,PlayerClass,PlayerDKP)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "ListItem", self.wndItemList, self)
	
	
	-- keep track of the window item created
	self.tItems[PlayerName] = wnd

	-- give it a piece of data to refer to 
	local wndPlayerText = wnd:FindChild("PlayerName")
	local wndClassText = wnd:FindChild("PlayerClass")
	local wndDKPText = wnd:FindChild("PlayerDKP")
	wndPlayerText:SetText(PlayerName) -- set the item wnd's text to "item i"
	wndClassText:SetText(PlayerClass)
	wndDKPText:SetText(PlayerDKP)
	wnd:SetData(PlayerName)
end

function DKP_Manager:AddDKPKtItem(ktID,ktDesc)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "DKP_Konten_ListItem", self.wndDKPKtItemList, self)
	
	
	-- keep track of the window item created
	self.tDKPKt[ktID] = wnd

	-- give it a piece of data to refer to 
	local id = wnd:FindChild("lbl_id")
	local desc = wnd:FindChild("lbl_desc")
	id:SetText(ktID)
	desc:SetText(ktDesc)
end

function DKP_Manager:AddDKPPlayerItem(playerName)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "DKP_PlayersItems", self.wndDKPPlayerItemList, self)
	
	
	-- keep track of the window item created
	self.tDKPPlayers[playerName] = wnd

	-- give it a piece of data to refer to 
	local playern = wnd:FindChild("lbl_player")
	--local desc = wnd:FindChild("lbl_desc")
	--id:SetText(ktID)
	--desc:SetText(ktDesc)
	playern:SetText(playerName)
	
	end

function DKP_Manager:AddDKPEventItem(EventID,EventDesc)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "DKP_EventItems", self.wndDKPEventItemList, self)
	
	
	-- keep track of the window item created
	self.tDKPEvent[EventID] = wnd

	-- give it a piece of data to refer to 
	local id = wnd:FindChild("lbl_id")
	local desc = wnd:FindChild("lbl_event")
	id:SetText(EventID)
	desc:SetText(EventDesc)
end

-- add an item into the item list
function DKP_Manager:AddDKPItem(PlayerName,ItemName,DKPName, ItemID)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "ListDKPItem", self.wndDKPItemList, self)
	
	
	-- keep track of the window item created
	self.dkpItems[ItemName] = wnd

	-- give it a piece of data to refer to 
	local wndPlayerText = wnd:FindChild("PlayerName")
	local wndItemText = wnd:FindChild("ItemName")
	local wndDKPText = wnd:FindChild("DKPName")
	local wndItemID = wnd:FindChild("ItemID")
	wndPlayerText:SetText(PlayerName) -- set the item wnd's text to "item i"
	wndItemText:SetText(ItemName)
	wndDKPText:SetText(DKPName)
	wndItemID:SetText(ItemID)
	wnd:SetData(ItemName)
end

function DKP_Manager:AddReasonItem(PlayerName,ReasonName,DKPName, DKPTime)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "ReasonItem", self.wndReasonItemList, self)
	strTime = DKP_Manager:GetTimeStringFromUnix(tonumber(DKPTime), self.engTime)
	
	-- keep track of the window item created
	indexfor = "" .. PlayerName .. ReasonName .. DKPName .. ""
	self.reasonItem[indexfor] = wnd
	-- give it a piece of data to refer to 
	local wndPlayerText = wnd:FindChild("PlayerName")
	local wndItemText = wnd:FindChild("ReasonName")
	local wndDKPText = wnd:FindChild("DKPName")
	local wndDKPTime = wnd:FindChild("DKPTime")
	wndPlayerText:SetText(PlayerName) -- set the item wnd's text to "item i"
	wndItemText:SetText(ReasonName)
	wnd:SetData(PlayerName)
	wndDKPTime:SetText(strTime)
	wndDKPText:SetText(DKPName)
end

function DKP_Manager:AddListBidder(PlayerName,DKPName)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "ListBnWList", self.wndBetAndWinList, self)
	
	
	-- keep track of the window item created
	if self.betItem[PlayerName] == nil then
		self.betItem[PlayerName] = wnd
	else
		self:DestroyBetList(PlayerName)
		self.betItem[PlayerName] = wnd
	end

	-- give it a piece of data to refer to 
	local wndPlayerText = wnd:FindChild("PlayerName")
	local wndDKPText = wnd:FindChild("DKPName")
	local wndItemText = wnd:FindChild("ItemName")
	wndPlayerText:SetText(PlayerName) -- set the item wnd's text to "item i"
	wndDKPText:SetText(DKPName)
	wndItemText:SetText(itemWeBetFor:GetName())
	wnd:SetData(PlayerName)
end



-- when a list item is selected
function DKP_Manager:OnListItemCharacterSelected(wndHandler, wndControl)
    -- make sure the wndControl is valid
    if wndHandler ~= wndControl then
        return
    end
    
    -- change the old item's text color back to normal color
    local wndItemText
    if self.wndSelectedListItem ~= nil then
        wndItemText = self.wndSelectedListItem:FindChild("PlayerName")
      --  wndItemText:SetTextColor(kcrNormalText)
    end
    
	-- wndControl is the item selected - change its color to selected
	self.wndSelectedListItem = wndControl
	wndItemText = self.wndSelectedListItem:FindChild("PlayerName")
   -- wndItemText:SetTextColor(kcrSelectedText)
    
		self:SearchForItems(self.wndSelectedListItem:GetData())
		self.wndItems:Invoke()
end


function DKP_Manager:SearchForItems(strPlayerName)
local playerID = DKP_Manager:GetPlayerID(strPlayerName)
if (players[tonumber(playerID)] ~= nil) then
        local iMaxItems = 0
        local iMaxDKP = 0
        self:DestroyDKPItemList()
                if (players[playerID].items ~= nil) then
                        for key,val in pairs(players[playerID].items) do
							if DKP_Manager:GetItemPool(players[playerID].items[key].itempool_id, tonumber(self.dkpKtId)) then
                                        self:AddDKPItem(strPlayerName,players[playerID].items[key].name,players[playerID].items[key].value,players[playerID].items[key].game_id)
                                        iMaxItems = iMaxItems+1
                                        iMaxDKP = iMaxDKP+tonumber(players[playerID].items[key].value)
							end
                        end;
                end;
        local wndItems = Apollo.FindWindowByName("DKP_ListItems")
        local maxDKP = wndItems:FindChild("txtGesamtDKP")
        local maxItems = wndItems:FindChild("txtGesamtItems")
        local ktName = wndItems:FindChild("lbl_dkp_kt_display")
        local ktPlayerName = wndItems:FindChild("lbl_dkp_player_display")
        local ktCurDKP = wndItems:FindChild("lbl_dkp_current_display")
        ktName:SetText(multidkp_pools[tonumber(self.dkpKtId)].desc)
        ktPlayerName:SetText(strPlayerName)
        ktCurDKP:SetText(players[playerID]["points"][tonumber(self.dkpKtId)][pointsCurrentModeString])
        maxDKP:SetText("DKP spend: " .. tostring(iMaxDKP))
        maxItems:SetText("Items earned: " .. tostring(iMaxItems))
        self.wndDKPItemList:ArrangeChildrenVert()
self:SearchForReasons(strPlayerName)
end
end

function DKP_Manager:SearchForReasons(strPlayerName)
playerID = DKP_Manager:GetPlayerID(strPlayerName)
if (players[playerID] ~= nil) then
              self:DestroyReasonList()
                if (players[playerID] ~= nil) then
                        for key,val in pairs(players[playerID].adjustments) do
                                        self:AddReasonItem(strPlayerName,players[playerID]["adjustments"][key].reason,players[playerID]["adjustments"][key].value,players[playerID]["adjustments"][key].timestamp)
                        end;
                end
self.wndReasonItemList:ArrangeChildrenVert()
        end
end


function DKP_Manager:OnMasterLootUpdate()

	local tMasterLoot = GameLib.GetMasterLoot()
	local tMasterLootItemList = {}
	local tLooterItemList = {}
	
	wndControlOld = nil
		
	for idx, tLootItem in ipairs(tMasterLoot) do
			if tLootItem.bIsMaster then
				table.insert(tMasterLootItemList, tLootItem)
				self:OnDKP_BnWInit()
			else
				table.insert(tLooterItemList, tLootItem)
			end
	end
	
	self:DestroyLootItemList()
	self:AddLootItem(tMasterLootItemList)
	self:PopulateLootItemList()
end

function DKP_Manager:AddLootItem(tLootItems)

local i = 1
for idx, tItem in ipairs (tLootItems) do
			local wnd = Apollo.LoadForm(self.xmlDoc, "ListItemLoot", self.wndBetAndWinItemList, self)
			local wndItemIcon = wnd:FindChild("iconLoot")
			wndItemHighlight = wnd:FindChild("itemHighlight")
			i = i + 1
			if wndItemIcon then -- make sure the wnd exist
				wndItemIcon:SetSprite(tItem.itemDrop:GetIcon())
				wndItemIcon:SetData(Item.GetDataFromId(itemId))
				Tooltip.GetItemTooltipForm(self, wndItemIcon, tItem.itemDrop, {bPrimary = true, bSelling = false})
				wndItemIcon:FindChild("holderID"):SetText(tItem.itemDrop:GetItemId())
				wndItemHighlight:Show(false)
			end
			self.tItemsLoot[tostring(i)] = wnd
			wnd:SetData(i)			
end
end


function DKP_Manager:PopulateLootItemList()
	self.wndBetAndWinItemList:ArrangeChildrenVert()
end

function DKP_Manager:DestroyLootItemList()
	for key,val in pairs(self.tItemsLoot) do
	self.tItemsLoot[key]:Destroy()
	end
	self.tItemsLoot = {}
	
end

function DKP_Manager:onClick(wndHandler, wndControl)

	--ChatSystemLib.Command('/w' .. ' Hayato ' .. wndControl:FindChild("holderID"):GetText())
	
	itemWeBetFor = Item.GetDataFromId(wndControl:FindChild("holderID"):GetText())
	
	if wndControlOld then
		if wndControlOld == wndControl then return end
			wndControlOld:GetParent():FindChild("itemHighlight"):Show(false)
			wndControl:GetParent():FindChild("itemHighlight"):Show(true)
			wndControlOld = wndControl

	else
		wndControlOld = wndControl
		wndControl:GetParent():FindChild("itemHighlight"):Show(true)
	end
	
end

function DKP_Manager:OnImportData()



	ImportData = self.wndImport:FindChild("BGImport"):FindChild("ImportData"):GetText()
	if ImportData == "" then
	return
	else
	
	--JSON:decode(ImportData)
	load_table = loadstring(ImportData)
	if load_table == nil then
		ImportData = self.wndImport:FindChild("BGImport"):FindChild("ImportData"):SetText("ERROR")
	else
		load_table()
		self:DestroyItemList()
		self:PopulateItemList()
		ImportData = self.wndImport:FindChild("BGImport"):FindChild("ImportData"):SetText("SUCCSESS")
			if info.with_twink == "1" then
				self.isTwinkMode = true
			else
				self.isTwinkMode = false
			end
	end
	end

end

function DKP_Manager:OnDKPAdd(wndHandler, wndControl)
			amount = self.wndItems:FindChild("fld_add_amount"):GetText()

	if tonumber(amount) then

		dkpKt = self.dkpKtId
		eventID = self.dkpEventId
		playerName = self.wndItems:FindChild("lbl_dkp_player_display"):GetText()
		reason = self.wndItems:FindChild("fld_add_reason"):GetText()
		itemPool = self.dkpItemPoolID
		isMainPlayer = nil
		mainID = nil
		

		if self.dkpItemPoolID == nil then return end
		if self.dkpKtId == nil then return end
		if self.isTwinkMode == nil then return end
		if playerName == "PLAYERNAME" or playerName == "" or playerName == nil then return end
		if self.wndItems:FindChild("Label_EventDropDown_Name"):GetText() == "NO EVENT" then 
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "You need a Event for DKP Adjustment!")
		return
		end 
	
		playerID = DKP_Manager:GetPlayerID(playerName)
		if players[playerID].points == nil then return end
		if playerID == nil then return end
	
			if self.isTwinkMode then

				for keyp,valp in pairs(players) do
				
					if players[keyp].main_id == tostring(playerID) then
					
					for key,val in pairs(players[keyp].points) do

						if players[keyp]["points"][key].multidkp_id == tostring(dkpKt) then
								--ChatSystemLib.Command("/w EQDKP Step")
						players[keyp]["points"][key][pointsCurrentModeString] = players[keyp]["points"][key][pointsCurrentModeString]+tonumber(amount)
						players[keyp]["points"][key][adjustmentModeString] = players[keyp]["points"][key][adjustmentModeString]+tonumber(amount)
						
						players[keyp].adjustments[#players[keyp].adjustments + 1] = {event_id = tostring(self.dkpEventId), reason = reason, timestamp = os.time(), value = amount}

					end
					end

					end
				end
			else
			
				
				for key,val in pairs(players[playerID].points) do
				
				--for key,val in pairs(players[playerID].points) do
					if players[playerID]["points"][key].multidkp_id == tostring(dkpKt) then
								
						players[playerID]["points"][key][pointsCurrentModeString] = players[playerID]["points"][key][pointsCurrentModeString]+tonumber(amount)
						players[playerID]["points"][key][adjustmentModeString] = players[playerID]["points"][key][adjustmentModeString]+tonumber(amount)
						
						players[playerID].adjustments[#players[playerID].adjustments + 1] = {event_id = tostring(self.dkpEventId), reason = reason, timestamp = os.time(), value = amount}

					end
				end

			end
	end

		self:DestroyItemList()
		self:PopulateItemList()
		self:SearchForItems(playerName)
		self.wndItems:FindChild("fld_add_amount"):SetText("")
		self.wndItems:FindChild("fld_add_reason"):SetText("")

		--end
	--end
end

function DKP_Manager:OnDKPRemove(wndHandler, wndControl)
amount = self.wndItems:FindChild("fld_remove_amount"):GetText()

	if tonumber(amount) then

		dkpKt = self.dkpKtId
		eventID = self.dkpEventId
		playerName = self.wndItems:FindChild("lbl_dkp_player_display"):GetText()
		reason = self.wndItems:FindChild("fld_remove_reason"):GetText()
		itemPool = self.dkpItemPoolID
		isMainPlayer = nil
		mainID = nil
		

		if self.dkpItemPoolID == nil then return end
		if self.dkpKtId == nil then return end
		if self.isTwinkMode == nil then return end
		if playerName == "PLAYERNAME" or playerName == "" or playerName == nil then return end
		if self.wndItems:FindChild("Label_EventDropDown_Name"):GetText() == "NO EVENT" then 
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "You need a Event for DKP Adjustment!")
		return
		end 
	
		playerID = DKP_Manager:GetPlayerID(playerName)
		if players[playerID].points == nil then return end
		if playerID == nil then return end
	
			if self.isTwinkMode then

				for keyp,valp in pairs(players) do
				
					if players[keyp].main_id == tostring(playerID) then
					
					for key,val in pairs(players[keyp].points) do

						if players[keyp]["points"][key].multidkp_id == tostring(dkpKt) then
								--ChatSystemLib.Command("/w EQDKP Step")
						players[keyp]["points"][key][pointsCurrentModeString] = players[keyp]["points"][key][pointsCurrentModeString]-tonumber(amount)
						players[keyp]["points"][key][adjustmentModeString] = players[keyp]["points"][key][adjustmentModeString]-tonumber(amount)
						
						players[keyp].adjustments[#players[keyp].adjustments + 1] = {event_id = tostring(self.dkpEventId), reason = reason, timestamp = os.time(), value = amount}

					end
					end

					end
				end
			else
			
				
				for key,val in pairs(players[playerID].points) do
				
				--for key,val in pairs(players[playerID].points) do
					if players[playerID]["points"][key].multidkp_id == tostring(dkpKt) then
								
						players[playerID]["points"][key][pointsCurrentModeString] = players[playerID]["points"][key][pointsCurrentModeString]-tonumber(amount)
						players[playerID]["points"][key][adjustmentModeString] = players[playerID]["points"][key][adjustmentModeString]-tonumber(amount)
						
						players[playerID].adjustments[#players[playerID].adjustments + 1] = {event_id = tostring(self.dkpEventId), reason = reason, timestamp = os.time(), value = amount}

					end
				end

			end
	end

		self:DestroyItemList()
		self:PopulateItemList()
		self:SearchForItems(playerName)
		self.wndItems:FindChild("fld_remove_amount"):SetText("")
		self.wndItems:FindChild("fld_remove_reason"):SetText("")

end
---------------------------------------------------------------------------------------------------
-- DKP_SettingsList Functions
---------------------------------------------------------------------------------------------------



function DKP_Manager:OnCancelConfig( wndHandler, wndControl, eMouseButton )
self.wndSettings:Close()
end
-- when the Cancel button is clicked
function DKP_Manager:OnCancel()
	self.wndMain:Close() -- hide the window
end
function DKP_Manager:OnCancelList()
	self.wndItems:Close() -- hide the window
end
function DKP_Manager:OnCancelBnW()
	self.wndBetAndWin:Close() -- hide the window
end
function DKP_Manager:OnCancelImport()
	self.wndImport:Close()
end



function DKP_Manager:Button_EnableDKPSay( wndHandler, wndControl)
self.DKPChatChannelSay = wndControl:IsChecked()
if wndControl:IsChecked()==true then
self.DKPChatChannelGuild = false
self.DKPChatChannelInstance = false
self.DKPChatChannelGroup = false
end
end

function DKP_Manager:Button_EnableDKPInstance( wndHandler, wndControl)
self.DKPChatChannelInstance = wndControl:IsChecked()
if wndControl:IsChecked()==true then
self.DKPChatChannelGuild = false
self.DKPChatChannelSay = false
self.DKPChatChannelGroup = false
end
end

function DKP_Manager:Button_EnableDKPRaid( wndHandler, wndControl)
self.DKPChatChannelGroup = wndControl:IsChecked()
if wndControl:IsChecked()==true then
self.DKPChatChannelGuild = false
self.DKPChatChannelInstance = false
self.DKPChatChannelSay = false
end
end

function DKP_Manager:Button_EnableDKPGuild( wndHandler, wndControl)
self.DKPChatChannelGuild = wndControl:IsChecked()
if wndControl:IsChecked()==true then
self.DKPChatChannelSay = false
self.DKPChatChannelInstance = false
self.DKPChatChannelGroup = false
end
end

function DKP_Manager:Button_EnableBnWSay( wndHandler, wndControl)
self.BnWChatChannelSay = wndControl:IsChecked()
if wndControl:IsChecked()==true then
self.BnWChatChannelGuild = false
self.BnWChatChannelInstance = false
self.BnWChatChannelGroup = false
end
end


function DKP_Manager:Button_EnableBnWInstance( wndHandler, wndControl)
self.BnWChatChannelInstance = wndControl:IsChecked()
if wndControl:IsChecked()==true then
self.BnWChatChannelGuild = false
self.BnWChatChannelSay = false
self.BnWChatChannelGroup = false
end
end

function DKP_Manager:Button_EnableBnWGroup( wndHandler, wndControl)
self.BnWChatChannelGroup = wndControl:IsChecked()
if wndControl:IsChecked()==true then
self.BnWChatChannelGuild = false
self.BnWChatChannelInstance = false
self.BnWChatChannelSay = false
end
end

function DKP_Manager:Button_EnableBnWGuild( wndHandler, wndControl)
self.BnWChatChannelGuild = wndControl:IsChecked()
if wndControl:IsChecked()==true then
self.BnWChatChannelSay = false
self.BnWChatChannelInstance = false
self.BnWChatChannelGroup = false
end
end




function DKP_Manager:Button_EnableDKPWhisper( wndHandler, wndControl)
self.isAllowWhisper = wndControl:IsChecked()
end

function DKP_Manager:Button_EnableTwinkMode( wndHandler, wndControl, eMouseButton )
self.isTwinkMode = wndControl:IsChecked()
end

function DKP_Manager:Button_EnableEngTime( wndHandler, wndControl, eMouseButton )
self.engTime = wndControl:IsChecked()
end

function DKP_Manager:Slider_DrawTimer( wndHandler, wndControl, fNewValue, fOldValue )
firstmatch = false


for strNewVal in string.gmatch(tostring(fNewValue), "([^.]+)") do
if firstmatch == false then
strDnewVal = strNewVal
firstmatch = true
end
end

--548
self.itemBetTime = tonumber(strDnewVal)
self.wndSettings:FindChild("Label_DrawTimerDisplay"):SetText(strDnewVal .. "s")
end



function DKP_Manager:OnDKPKtToogle( wndHandler, wndControl, eMouseButton )
if multidkp_pools ~= nil then
	if self.wndDKPKtList ~= nil then
		self.wndDKPKtList:Destroy()

	end
	self.wndDKPKtList = Apollo.LoadForm(self.xmlDoc, "DKP_Konten", wndControl, self)
	self.wndDKPKtItemList = self.wndDKPKtList:FindChild("KontenList")
	self.wndDKPKtList:SetData(wndControl)
	self.wndDKPKtList:SetAnchorPoints(0,1,1,0)
	self.wndDKPKtList:SetAnchorOffsets(0, -100, -15, 165)		

	self:PopulateDKPKtList()
	self.wndDKPKtList:Invoke()
end
end

function DKP_Manager:OnDKPPlayerToogle( wndHandler, wndControl, eMouseButton )
if players ~= nil then
	if self.wndDKPPlayerList ~= nil then
		self.wndDKPPlayerList:Destroy()

	end
	self.wndDKPPlayerList = Apollo.LoadForm(self.xmlDoc, "DKP_Players", wndControl, self)
	self.wndDKPPlayerItemList = self.wndDKPPlayerList:FindChild("PlayerList")
	self.wndDKPPlayerList:SetData(wndControl)
	self.wndDKPPlayerList:SetAnchorPoints(0,1,1,0)
	self.wndDKPPlayerList:SetAnchorOffsets(0, -100, -15, 165)		

	self:PopulateDKPPlayerList()
	self.wndDKPPlayerList:Invoke()
end
end


function DKP_Manager:OnDKPEventToogle( wndHandler, wndControl, eMouseButton )
if multidkp_pools ~= nil then
	if self.wndDKPEventList ~= nil then
		self.wndDKPEventList:Destroy()

	end
	self.wndDKPEventList = Apollo.LoadForm(self.xmlDoc, "DKP_Events", wndControl, self)
	self.wndDKPEventItemList = self.wndDKPEventList:FindChild("EventList")
	self.wndDKPEventList:SetData(wndControl)
	self.wndDKPEventList:SetAnchorPoints(0,1,1,0)
	self.wndDKPEventList:SetAnchorOffsets(0, -100, -15, 165)		

	self:PopulateDKPEventList()
	self.wndDKPEventList:Invoke()
end
end

function DKP_Manager:OpenImportWindow( wndHandler, wndControl, eMouseButton )
self.wndImport:Invoke()
end

function DKP_Manager:OnDKP_AddItem()
	players[1].items[#players[1].items + 1] = {game_id = "12345", itempool_id = "1", name = "SUCCESS!", value = "30"}
end

function DKP_Manager:OnLootAssigned(item, player)
	for key,lstitem in pairs(self.betItem) do
		if lstitem:FindChild("PlayerName"):GetText() == player then
			for key,val in pairs(players) do
				if players[key].name == player then
					local valueName = lstitem:FindChild("DKPName"):GetText()
					local string_player = tostring(player)
					local itemName = tostring(item:GetName())
					local Rover = Apollo.GetAddon("Rover")
					Rover:AddWatch("item", item)
					Rover:AddWatch("player", player)
					Rover:AddWatch("valueName", lstitem:FindChild("DKPName"):GetText())
					Rover:AddWatch("itemname", tostring(item:GetName()))
					self.BnWAssigned:FindChild("lbl_item_name"):SetText(itemName)
					self.BnWAssigned:FindChild("BGImport"):FindChild("fldDKPValue"):SetText(valueName)
					self.BnWAssigned:FindChild("Label_KtDropDown_Name"):SetText(player)
					
					self.BnWAssigned:Show(true)
					--DKP_Manager:BnWAssigned(itemName, string_player, valueName)
					players[key].items[#players[key].items + 1] = {game_id = tostring(item:GetItemId()), itempool_id = tostring(self.dkpItemPoolID), name = item:GetName(), value = lstitem:FindChild("DKPName"):GetText()}
					ChatSystemLib.Command(self:GetDKPChat("BnW") .. " " .. item:GetChatLinkString() .. " assigned to " .. player .. " for " .. lstitem:FindChild("DKPName"):GetText() .. " DKP!")
				end
			end
		end					
	end

end


---------------------------------------------------------------------------------------------------
-- DKP_Konten_ListItem Functions
---------------------------------------------------------------------------------------------------

function DKP_Manager:OnDKPKtSelected( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
   if wndHandler ~= wndControl then
        return
    end
    
    -- change the old item's text color back to normal color
    local wndItemText
    if self.wndSelectedListItem  ~= nil then
        wndItemText = self.wndSelectedListItem:FindChild("lbl_desc"):GetText()

      --  wndItemText:SetTextColor(kcrNormalText)
    end
    
	-- wndControl is the item selected - change its color to selected
	self.wndSelectedListItem = wndControl
	wndItemText = self.wndSelectedListItem:FindChild("lbl_desc"):GetText()
	wndKtID = self.wndSelectedListItem:FindChild("lbl_id"):GetText()
   -- wndItemText:SetTextColor(kcrSelectedText)
    
    self.wndSettingsList:FindChild("Label_KtDropDown_Name"):SetText(wndItemText)  
	self.dkpKtId = wndKtID 
	self.wndDKPKtList:Destroy()
    
		--self:SearchForItems(self.wndSelectedListItem:GetData())
		--self.wndItems:Invoke()
	

end


function DKP_Manager:OnStartAuction( betItem )
	if betItem ~= Nil and betItem ~= "" then
		isWinTime = true
		isFirstCalling=true
		self.timer = ApolloTimer.Create(1.0,true,"OnTimer",self)
		betTime = self.itemBetTime
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, "You dont have an Item selected!")
	end
end


function DKP_Manager:OnDKPEventSelected( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
   if wndHandler ~= wndControl then
        return
    end
    
    -- change the old item's text color back to normal color
    local wndItemText
    if self.wndSelectedListItem  ~= nil then
     wndItemText = self.wndSelectedListItem:FindChild("lbl_event"):GetText()
      --  wndItemText:SetTextColor(kcrNormalText)
    end
    
	-- wndControl is the item selected - change its color to selected
	self.wndSelectedListItem = wndControl
	wndItemText = self.wndSelectedListItem:FindChild("lbl_event"):GetText()
	wndEventID = self.wndSelectedListItem:FindChild("lbl_id"):GetText()
   -- wndItemText:SetTextColor(kcrSelectedText)
 
    self.wndItems:FindChild("Label_EventDropDown_Name"):SetText(wndItemText)  
	self.dkpEventId = wndEventID 
	self.wndDKPEventList:Destroy()
    
		--self:SearchForItems(self.wndSelectedListItem:GetData())
		--self.wndItems:Invoke()
	
end

---------------------------------------------------------------------------------------------------
-- DKP_PlayersItems Functions
---------------------------------------------------------------------------------------------------

function DKP_Manager:OnDKPPlayerSelected( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
 if wndHandler ~= wndControl then
        return
    end
    
    -- change the old item's text color back to normal color
    local wndItemText
    if self.wndSelectedListItem  ~= nil then
     wndItemText = self.wndSelectedListItem:FindChild("lbl_player"):GetText()
      --  wndItemText:SetTextColor(kcrNormalText)
    end
    
	-- wndControl is the item selected - change its color to selected
	self.wndSelectedListItem = wndControl
	wndItemText = self.wndSelectedListItem:FindChild("lbl_player"):GetText()
	--wndEventID = self.wndSelectedListItem:FindChild("lbl_id"):GetText()
   -- wndItemText:SetTextColor(kcrSelectedText)
 
    self.BnWAssigned:FindChild("Label_KtDropDown_Name"):SetText(wndItemText)  
	--self.dkpEventId = wndEventID 
	self.wndDKPPlayerList:Destroy()
    
		--self:SearchForItems(self.wndSelectedListItem:GetData())
		--self.wndItems:Invoke()
	

end

---------------------------------------------------------------------------------------------------
-- DKP_BnW_Assigned Functions
---------------------------------------------------------------------------------------------------

function DKP_Manager:CreateDKPAssign( wndHandler, wndControl, eMouseButton )
end

-----------------------------------------------------------------------------------------------
-- DKP_Manager Instance
-----------------------------------------------------------------------------------------------
local DKP_ManagerInst = DKP_Manager:new()
DKP_ManagerInst:Init()
