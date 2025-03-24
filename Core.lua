local addon, Engine = ...
---@class CC
local CC = LibStub('AceAddon-3.0'):NewAddon(addon, 'AceEvent-3.0', 'AceHook-3.0')

Engine.Core = CC
_G[addon] = Engine

local _G = _G
local format, ipairs, min, pairs, select, strsplit, tonumber, wipe = format, ipairs, min, pairs, select, strsplit, tonumber, table.wipe
local tinsert, tremove = table.insert, table.remove

local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local CreateFrame = CreateFrame
local UnitGUID = UnitGUID
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local GetTime = GetTime

local Details = _G.Details

CC.debug = false

function CC:IsPlayerOrPlayerPet(flags)
    return bit.band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 or bit.band(flags, COMBATLOG_OBJECT_TYPE_PET) > 0
end

function CC:GetActualPlayerGUID(guid, flags)
    if bit.band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then
        return guid
    end

    if bit.band(flags, COMBATLOG_OBJECT_TYPE_PET) > 0 then
        local ownerGUID = self:GetOwnerFromPetGUID(guid)
        if ownerGUID then
            return ownerGUID
        end
    end
    
    return guid
end

function CC:GetOwnerFromPetGUID(petGUID)
    local function checkUnitAndPet(unitID)
        local petID = unitID .. "pet"
        if UnitExists(petID) and UnitGUID(petID) == petGUID then
            return UnitGUID(unitID)
        end
        return nil
    end
    
    local ownerGUID = checkUnitAndPet("player")
    if ownerGUID then return ownerGUID end
    
    local isInRaid = IsInRaid()
    local numMembers = isInRaid and GetNumGroupMembers() or GetNumSubgroupMembers()
    local unitPrefix = isInRaid and "raid" or "party"
    
    for i = 1, numMembers do
        ownerGUID = checkUnitAndPet(unitPrefix .. i)
        if ownerGUID then return ownerGUID end
    end
    
    for i = 1, 40 do
        for _, unitPrefix in ipairs({"nameplate", "arena"}) do
            ownerGUID = checkUnitAndPet(unitPrefix .. i)
            if ownerGUID then return ownerGUID end
        end
    end
    
    return nil
end

CC.interruptSpells = {
    [1766] = true,   -- Kick (Rogue)
    [2139] = true,   -- Counterspell (Mage)
    [6552] = true,   -- Pummel (Warrior)
    [19647] = true,  -- Spell Lock (Warlock)
    [47528] = true,  -- Mind Freeze (Death Knight)
    [57994] = true,  -- Wind Shear (Shaman)
    [96231] = true,  -- Rebuke (Paladin)
    [106839] = true, -- Skull Bash (Druid)
    [116705] = true, -- Spear Hand Strike (Monk)
    [147362] = true, -- Counter Shot (Hunter)
    [183752] = true, -- Disrupt (Demon Hunter)
    [187707] = true, -- Muzzle (Hunter - Survival)
    [212619] = true, -- Call Felhunter (Warlock - PvP)
    [351338] = true, -- Quell (Evoker)
    [31935] = true,  -- Avenger's Shield (Paladin - Protection)
    [217824] = true, -- Shield of Virtue (Paladin - Holy PvP)
    [15487] = true,  -- Silence (Priest - Shadow)
    [171138] = true, -- Shadow Lock (Warlock - Grimoire of Sacrifice)
    [288047] = true, -- Nullification Dynamo (Engineering - Mechagon robot)
}

CC.ccInterruptSpells = {
    -- Death Knight
    [108194] = true, -- Asphyxiate
    [108199] = true, -- Gorefiend's Grasp
    [207167] = true, -- Blinding Sleet
    [47481] = true,  -- Gnaw
    -- Druid
    [5211] = true,   -- Mighty Bash
    [99] = true,     -- Incapacitating Roar
    [2637] = true,   -- Hibernate
    -- Hunter
    [187650] = true, -- Freezing Trap
    [3355] = true,   -- Freezing Trap
    [19577] = true,  -- Intimidation
    [24394] = true,  -- Intimidation
    [202914] = true, -- Spider Sting (PvP)
    [213691] = true, -- Scatter Shot (Marksmanship)
    [19386] = true,  -- Wyvern Sting
    -- Mage
    [31661] = true,  -- Dragon's Breath
    [118] = true,    -- Polymorph
    [82691] = true,  -- Ring of Frost
    -- Monk
    [119381] = true, -- Leg Sweep
    [115078] = true, -- Paralysis
    [119392] = true, -- Charging Ox Wave
    -- Paladin
    [853] = true,    -- Hammer of Justice
    [105421] = true, -- Blinding Light
    [20066] = true,  -- Repentance
    -- Priest
    [8122] = true,   -- Psychic Scream
    [64044] = true,  -- Psychic Horror
    [605] = true,    -- Mind Control
    [226943] = true, -- Mind Bomb
    -- Rogue
    [2094] = true,   -- Blind
    [1833] = true,   -- Cheap Shot
    [408] = true,    -- Kidney Shot
    [1776] = true,   -- Gouge
    -- Shaman
    [51514] = true,  -- Hex
    [118905] = true, -- Static Charge (Lightning Surge Totem)
    [192058] = true, -- Capacitor Totem
    -- Warlock
    [5484] = true,   -- Howl of Terror
    [6789] = true,   -- Mortal Coil
    [30283] = true,  -- Shadowfury
    [6358] = true,   -- Seduction (Succubus)
    [5782] = true,   -- Fear
    [710] = true,    -- Banish
    -- Warrior
    [46968] = true,  -- Shockwave
    [5246] = true,   -- Intimidating Shout
    [107570] = true, -- Storm Bolt
    -- Demon Hunter
    [179057] = true, -- Chaos Nova
    [217832] = true, -- Imprison
    [211881] = true, -- Fel Eruption
    [205630] = true, -- Illidan's Grasp (PvP talent)
    -- Evoker
    [360806] = true, -- Sleep Walk
}

CC.knockbackSpells = {
    -- Death Knight
    [49576] = true,  -- Death Grip
    [323710] = true, -- Abomination Limb
    [323798] = true, -- Abomination Limb
    -- Druid
    [132469] = true, -- Typhoon
    [102793] = true, -- Ursol's Vortex
    -- Hunter
    [186387] = true, -- Bursting Shot
    [236776] = true, -- High Explosive Trap
    [236777] = true, -- High Explosive Trap
    [462031] = true, -- Implosive Trap
    [357214] = true, -- Wing Clip
    -- Mage
    [157981] = true, -- Blast Wave
    [235450] = true, -- Prismatic Barrier (with talent)
    -- Monk
    [116844] = true, -- Ring of Peace
    [232055] = true, -- Fists of Fury (with effect)
    -- Priest
    [204263] = true, -- Shining Force
    -- Shaman
    [51490] = true,  -- Thunderstorm
    [192077] = true, -- Wind Rush Totem
    -- Warrior
    [6544] = true,   -- Heroic Leap (with talent)
    [46968] = true,  -- Shockwave (knockback component)
    -- Demon Hunter
    [198793] = true, -- Vengeful Retreat 
    [207684] = true, -- Sigil of Misery (with displacement)
    -- Evoker
    [368970] = true, -- Tail Swipe
    [357214] = true, -- Wing Buffet
    [396286] = true, -- Upheaval
    -- Engineering
    [172024] = true, -- Pulse Grenade
}

CC.allStopSpells = {}

CC.CustomDisplayStops = {
    name = "Stops",
    icon = 136018,
    source = false,
    attribute = false,
    spellid = false,
    target = false,
    author = "Cline",
    desc = "Show how many enemy casts were stopped by each player.",
    script_version = 11,
    script = [[
        local Combat, CustomContainer, Instance = ...
        local total, top, amount = 0, 0, 0

        if _G.Details_CancelCulture then
            local Container = Combat:GetActorList(DETAILS_ATTRIBUTE_MISC)
            for _, player in ipairs(Container) do
                if player:IsGroupPlayer() then
                    local stops, _ = _G.Details_CancelCulture:GetStopsRecord(Combat:GetCombatNumber(), player:guid())
                    if stops > 0 then
                        CustomContainer:AddValue(player, stops)
                    end
                end
            end

            total, top = CustomContainer:GetTotalAndHighestValue()
            amount = CustomContainer:GetNumActors()
        end

        return total, top, amount
    ]],
    tooltip = [[
        local Actor, Combat, Instance = ...
        local GameCooltip = GameCooltip

        if _G.Details_CancelCulture then
            local realCombat
            for i = -1, 25 do
                local current = Details:GetCombat(i)
                if current and current:GetCombatNumber() == Combat.combat_counter then
                    realCombat = current
                    break
                end
            end

            if not realCombat then 
                return 
            end
            
            local actorObj = realCombat[1]:GetActor(Actor.nome)
            if not actorObj then
                return
            end
            
            local playerGUID = actorObj:guid()
            
            local stops, overlaps, stopsSpells, overlapsSpells = _G.Details_CancelCulture:GetStopsRecord(Combat:GetCombatNumber(), playerGUID)
            
            local sortedList = {}
            
            if type(stopsSpells) == "table" then
                for spellID, spelldata in pairs(stopsSpells) do
                    if type(spelldata) == "table" and spelldata.cnt then
                        tinsert(sortedList, {spellID, spelldata.cnt})
                    end
                end
            end
            sort(sortedList, Details.Sort2)

            local format_func = Details:GetCurrentToKFunction()
            for _, tbl in ipairs(sortedList) do
                local spellID, cnt = unpack(tbl)
                local spellName, _, spellIcon = Details.GetSpellInfo(spellID)

                local colorCode, barR, barG, barB
                local spellType = _G.Details_CancelCulture:GetSpellType(spellID)
                
                if spellType == "interrupt" then
                    colorCode = "|cFF00A3FF"
                    barR, barG, barB = 0.0, 0.2, 0.4
                elseif spellType == "cc" then
                    colorCode = "|cFFFF5555"
                    barR, barG, barB = 0.4, 0.1, 0.1
                elseif spellType == "knockback" then
                    colorCode = "|cFFFFCC00"
                    barR, barG, barB = 0.4, 0.3, 0.0
                else
                    colorCode = "|cFF00DDFF"
                    barR, barG, barB = 0.0, 0.3, 0.4
                end
                
                GameCooltip:AddLine(colorCode .. spellName .. "|r", cnt)
                GameCooltip:AddStatusBar(100, 1, barR, barG, barB, 0.6, false, {value = 100, color = {0.1, 0.1, 0.1, 0.8}})
                GameCooltip:AddIcon(spellIcon, 1, 1, _detalhes.tooltip.line_height * 1.1, _detalhes.tooltip.line_height * 1.1)
                
                local currentSpellData = stopsSpells[spellID]
                if currentSpellData and currentSpellData.interrupted and type(currentSpellData.interrupted) == "table" then
                    local interruptedList = {}
                    for enemySpellID, enemyData in pairs(currentSpellData.interrupted) do
                        tinsert(interruptedList, {enemySpellID, enemyData.cnt, enemyData.name})
                    end
                    sort(interruptedList, Details.Sort2)
                    
                    for _, enemyTbl in ipairs(interruptedList) do
                        local enemySpellID, enemyCnt, enemyName = unpack(enemyTbl)
                        local enemySpellName = enemyName or "Unknown Spell"
                        local _, _, enemySpellIcon = Details.GetSpellInfo(enemySpellID)
                        
                        GameCooltip:AddLine("|cFFAAAAAA" .. enemySpellName .. "|r", enemyCnt)
                        GameCooltip:AddStatusBar(100, 1, barR * 0.5, barG * 0.5, barB * 0.5, 0.3, false, {value = 100, color = {0.1, 0.1, 0.1, 0.6}})
                        if enemySpellIcon then
                            GameCooltip:AddIcon(enemySpellIcon, 1, 1, _detalhes.tooltip.line_height * 0.7, _detalhes.tooltip.line_height * 0.7, nil, nil, nil, nil, {0.2, 0.8, 0.2, 0.6})
                        end
                    end
                end
            end
        end
    ]],
    total_script = [[
        local value, top, total, Combat, Instance, Actor = ...

        if _G.Details_CancelCulture then
            return _G.Details_CancelCulture:GetStopsDisplayText(Combat:GetCombatNumber(), Actor.my_actor.serial)
        end
        return ""
    ]]
}

CC.CustomDisplayOverlaps = {
    name = "Overlaps",
    icon = 237555,
    source = false,
    attribute = false,
    spellid = false,
    target = false,
    author = "Cline",
    desc = "Show how many interrupt abilities were wasted by each player.",
    script_version = 11,
    script = [[
        local Combat, CustomContainer, Instance = ...
        local total, top, amount = 0, 0, 0

        if _G.Details_CancelCulture then
            local Container = Combat:GetActorList(DETAILS_ATTRIBUTE_MISC)
            for _, player in ipairs(Container) do
                if player:IsGroupPlayer() then
                    local _, overlaps = _G.Details_CancelCulture:GetStopsRecord(Combat:GetCombatNumber(), player:guid())
                    if overlaps > 0 then
                        CustomContainer:AddValue(player, overlaps)
                    end
                end
            end

            total, top = CustomContainer:GetTotalAndHighestValue()
            amount = CustomContainer:GetNumActors()
        end

        return total, top, amount
    ]],
    tooltip = [[
        local Actor, Combat, Instance = ...
        local GameCooltip = GameCooltip

        if _G.Details_CancelCulture then
            local realCombat
            for i = -1, 25 do
                local current = Details:GetCombat(i)
                if current and current:GetCombatNumber() == Combat.combat_counter then
                    realCombat = current
                    break
                end
            end

            if not realCombat then 
                return 
            end
            
            local actorObj = realCombat[1]:GetActor(Actor.nome)
            if not actorObj then
                return
            end
            
            local playerGUID = actorObj:guid()
            
            local stops, overlaps, stopsSpells, overlapsSpells = _G.Details_CancelCulture:GetStopsRecord(Combat:GetCombatNumber(), playerGUID)
            
            local sortedList = {}
            
            if type(overlapsSpells) == "table" then
                for spellID, spelldata in pairs(overlapsSpells) do
                    if type(spelldata) == "table" and spelldata.cnt then
                        tinsert(sortedList, {spellID, spelldata.cnt})
                    end
                end
            end
            sort(sortedList, Details.Sort2)

            local format_func = Details:GetCurrentToKFunction()
            for _, tbl in ipairs(sortedList) do
                local spellID, cnt = unpack(tbl)
                local spellName, _, spellIcon = Details.GetSpellInfo(spellID)

                GameCooltip:AddLine(spellName, cnt)
                Details:AddTooltipBackgroundStatusbar()
                GameCooltip:AddIcon(spellIcon, 1, 1, _detalhes.tooltip.line_height, _detalhes.tooltip.line_height)
            end
        end
    ]],
    total_script = [[
        local value, top, total, Combat, Instance, Actor = ...

        if _G.Details_CancelCulture then
            return _G.Details_CancelCulture:GetOverlapsDisplayText(Combat:GetCombatNumber(), Actor.my_actor.serial)
        end
        return ""
    ]]
}


CC.debuggedCombats = {}

function Engine:GetStopsRecord(combatID, playerGUID)
    if CC.db[combatID] and CC.db[combatID][playerGUID] then
        local stops = CC.db[combatID][playerGUID].stops or 0
        local overlaps = CC.db[combatID][playerGUID].overlaps or 0
        local stopsSpells = CC.db[combatID][playerGUID].stopsSpells or {}
        local overlapsSpells = CC.db[combatID][playerGUID].overlapsSpells or {}
        
        return stops, overlaps, stopsSpells, overlapsSpells
    end
    
    for id, combatData in pairs(CC.db) do
        if combatData[playerGUID] then
            local stops = combatData[playerGUID].stops or 0
            local overlaps = combatData[playerGUID].overlaps or 0
            local stopsSpells = combatData[playerGUID].stopsSpells or {}
            local overlapsSpells = combatData[playerGUID].overlapsSpells or {}
            
            return stops, overlaps, stopsSpells, overlapsSpells
        end
    end
    
    return 0, 0, {}, {}
end

function Engine:GetStopsDisplayText(combatID, playerGUID)
    local stops, _ = _G.Details_CancelCulture:GetStopsRecord(combatID, playerGUID)
    return "" .. stops
end

function Engine:GetOverlapsDisplayText(combatID, playerGUID)
    local _, overlaps = _G.Details_CancelCulture:GetStopsRecord(combatID, playerGUID)
    return "" .. overlaps
end

function Engine:GetSpellType(spellID)
    if CC.interruptSpells[spellID] then
        return "interrupt"
    elseif CC.ccInterruptSpells[spellID] then
        return "cc"
    elseif CC.knockbackSpells[spellID] then
        return "knockback"
    else
        return "unknown"
    end
end

function Engine:PrintDebugInfo()
    local oldDebug = CC.debug
    CC.debug = true
    CC:Debug("Overall Combat ID: %s", tostring(CC.overall))
    CC.debug = oldDebug
end

function Engine:setDebug(enabled)
    CC.debug = enabled
end


function CC:Debug(...)
    if self.debug then
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cFF70B8FFDetails Cancel Culture:|r " .. format(...))
    end
end

CC.pendingInterrupts = {}
CC.recentInterrupts = {}
CC.INTERRUPT_WINDOW = 0.3
CC.KNOCKBACK_THRESHOLD = 0.5

CC.lastKnockbackCast = {
    time = 0,
    sourceGUID = nil,
    sourceClass = nil,
    spellId = nil
}

function CC:EnsureUnitData(combatNumber, unitGUID)
    if not self.db[combatNumber] then
        self.db[combatNumber] = {}
    end
    if not self.db[combatNumber][unitGUID] then
        self.db[combatNumber][unitGUID] = {
            stops = 0, 
            overlaps = 0, 
            stopsSpells = {}, 
            overlapsSpells = {}
        }
    end
end

function CC:EnsureSpellData(combatNumber, unitGUID, spellId, isStop)
    CC:EnsureUnitData(combatNumber, unitGUID)
    
    local spellsTable = isStop and "stopsSpells" or "overlapsSpells"
    
    if not self.db[combatNumber][unitGUID][spellsTable] then
        self.db[combatNumber][unitGUID][spellsTable] = {}
    end
    if not self.db[combatNumber][unitGUID][spellsTable][spellId] then
        self.db[combatNumber][unitGUID][spellsTable][spellId] = {
            cnt = 0,
            interrupted = {}
        }
    end
end

function CC:RecordStop(unitGUID, spellId, targetGUID, extraSpellId, extraSpellName)
    CC:EnsureSpellData(self.current, unitGUID, spellId, true)
    CC:EnsureSpellData(self.overall, unitGUID, spellId, true)

    local registerHit = function(where)
        where.stops = where.stops + 1
        where.stopsSpells[spellId].cnt = where.stopsSpells[spellId].cnt + 1
        
        if extraSpellId then
            if not where.stopsSpells[spellId].interrupted[extraSpellId] then
                where.stopsSpells[spellId].interrupted[extraSpellId] = {
                    cnt = 0,
                    name = extraSpellName
                }
            end
            where.stopsSpells[spellId].interrupted[extraSpellId].cnt = 
                where.stopsSpells[spellId].interrupted[extraSpellId].cnt + 1
        end
    end

    registerHit(self.db[self.overall][unitGUID])
    registerHit(self.db[self.current][unitGUID])
end

function CC:RecordOverlap(unitGUID, spellId)
    CC:EnsureSpellData(self.current, unitGUID, spellId, false)
    CC:EnsureSpellData(self.overall, unitGUID, spellId, false)

    local registerHit = function(where)
        where.overlaps = where.overlaps + 1
        where.overlapsSpells[spellId].cnt = where.overlapsSpells[spellId].cnt + 1
    end

    registerHit(self.db[self.overall][unitGUID])
    registerHit(self.db[self.current][unitGUID])
end

function CC:COMBAT_LOG_EVENT_UNFILTERED()
    if not self.current then
        return
    end
    
    local timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, 
          destGUID, destName, destFlags, destFlags2 = CombatLogGetCurrentEventInfo()
    
    local eventPrefix, eventSuffix = eventType:match("^(.-)_?([^_]*)$")
    
    if eventType == "SPELL_CAST_SUCCESS" then
        local spellId, spellName, spellSchool = select(12, CombatLogGetCurrentEventInfo())
        
        if self.interruptSpells[spellId] then
            local playerGUID = self:GetActualPlayerGUID(srcGUID, srcFlags)
            
            if self:IsPlayerOrPlayerPet(srcFlags) then
                local key = playerGUID .. "-" .. spellId .. "-" .. GetTime()
                self.pendingInterrupts[key] = {
                    playerGUID = playerGUID,
                    spellId = spellId,
                    time = GetTime(),
                    success = false,
                    target = destGUID
                }
                
                C_Timer.After(self.INTERRUPT_WINDOW, function()
                    local data = self.pendingInterrupts[key]
                    if data and not data.success then
                        self:RecordOverlap(data.playerGUID, data.spellId)
                    end
                    self.pendingInterrupts[key] = nil
                end)
            end
        elseif self.knockbackSpells[spellId] then
            if self:IsPlayerOrPlayerPet(srcFlags) then
                self.lastKnockbackCast.time = GetTime()
                self.lastKnockbackCast.sourceGUID = self:GetActualPlayerGUID(srcGUID, srcFlags)
                self.lastKnockbackCast.spellId = spellId
            end
        end
    
    elseif eventType == "SPELL_INTERRUPT" then
        local spellId, spellName, spellSchool, extraSpellId, extraSpellName = select(12, CombatLogGetCurrentEventInfo())
        if self:IsPlayerOrPlayerPet(srcFlags) then
            local playerGUID = self:GetActualPlayerGUID(srcGUID, srcFlags)
            
            local now = GetTime()
            
            for key, data in pairs(self.pendingInterrupts) do
                if data.playerGUID == playerGUID and data.target == destGUID and (now - data.time) < self.INTERRUPT_WINDOW then
                    data.success = true
                    break
                end
            end

            if self.recentInterrupts[destGUID] then
                if self.recentInterrupts[destGUID].timer then
                    self.recentInterrupts[destGUID].timer:Cancel()
                end
                self.recentInterrupts[destGUID].success = true
            end

            self:RecordStop(playerGUID, spellId, destGUID, extraSpellId, extraSpellName)
        end
    
    elseif eventType == "SPELL_AURA_APPLIED" then
        local spellId, spellName, spellSchool, auraType = select(12, CombatLogGetCurrentEventInfo())
        if self.ccInterruptSpells[spellId] and self:IsPlayerOrPlayerPet(srcFlags) then
            local playerGUID = self:GetActualPlayerGUID(srcGUID, srcFlags)
            if self.recentInterrupts[destGUID] then
                self.recentInterrupts[destGUID].timer = C_Timer.NewTimer(self.INTERRUPT_WINDOW, function()
                    if not CC.recentInterrupts[destGUID].success then
                        CC:RecordStop(playerGUID, spellId, destGUID, CC.recentInterrupts[destGUID].spellID, CC.recentInterrupts[destGUID].spellName)
                    end
                    CC.recentInterrupts[destGUID] = nil
                end)
            end
        end
    end
end

function CC:UNIT_SPELLCAST_INTERRUPTED(event, unit, castGUID, spellID)
    if not self.current then
        return
    end
    
    if unit and unit:match("^nameplate") then
        local unitGUID = UnitGUID(unit)
        local unitName = UnitName(unit)
        local spellName = Details.GetSpellInfo(spellID)
        
        
        local now = GetTime()
        local timeSinceKnockback = now - self.lastKnockbackCast.time
        
        
        if timeSinceKnockback < self.KNOCKBACK_THRESHOLD and self.lastKnockbackCast.sourceGUID then
            self:RecordStop(self.lastKnockbackCast.sourceGUID, self.lastKnockbackCast.spellId, unitGUID, spellID, spellName)
        else
            self.recentInterrupts[unitGUID] = {
                time = now,
                spellID = spellID,
                spellName = spellName
            }
            
        end
    end
end

function CC:InitDataCollection()
    self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
    self:RegisterEvent('UNIT_SPELLCAST_INTERRUPTED')
end

function CC:MergeCombat(to, from)
    if self.db[from] then
        if not self.db[to] then
            self.db[to] = {}
        end
        for playerGUID, tbl in pairs(self.db[from]) do
            self:EnsureUnitData(to, playerGUID)
            self.db[to][playerGUID].stops = self.db[to][playerGUID].stops + (tbl.stops or 0)
            self.db[to][playerGUID].overlaps = self.db[to][playerGUID].overlaps + (tbl.overlaps or 0)

            for spellId, spelltbl in pairs(tbl.stopsSpells or {}) do
                self:EnsureSpellData(to, playerGUID, spellId, true)
                self.db[to][playerGUID].stopsSpells[spellId].cnt = 
                    self.db[to][playerGUID].stopsSpells[spellId].cnt + spelltbl.cnt
                
                if spelltbl.interrupted and type(spelltbl.interrupted) == "table" then
                    for enemySpellId, enemyData in pairs(spelltbl.interrupted) do
                        if not self.db[to][playerGUID].stopsSpells[spellId].interrupted[enemySpellId] then
                            self.db[to][playerGUID].stopsSpells[spellId].interrupted[enemySpellId] = {
                                cnt = 0,
                                name = enemyData.name
                            }
                        end
                        self.db[to][playerGUID].stopsSpells[spellId].interrupted[enemySpellId].cnt = 
                            self.db[to][playerGUID].stopsSpells[spellId].interrupted[enemySpellId].cnt + enemyData.cnt
                    end
                end
            end

            for spellId, spelltbl in pairs(tbl.overlapsSpells or {}) do
                self:EnsureSpellData(to, playerGUID, spellId, false)
                self.db[to][playerGUID].overlapsSpells[spellId].cnt = 
                    self.db[to][playerGUID].overlapsSpells[spellId].cnt + spelltbl.cnt
            end
        end
    end
end

function CC:isSameDungeon(combat1, combat2)
    local isMythic1, runId1 = combat1:IsMythicDungeon()
    local isMythic2, runId2 = combat2:IsMythicDungeon()
    return isMythic1 and isMythic2 and runId1 == runId2
end

function CC:MergeSegmentsOnEnd()
    local overallCombat = Details:GetCombat(1)
    local overall = overallCombat:GetCombatNumber()
    for i = 2, 25 do
        local combat = Details:GetCombat(i)
        if not combat or not self:isSameDungeon(overallCombat, combat) or combat:IsMythicDungeonOverall() then
            break
        end

        self:MergeCombat(overall, combat:GetCombatNumber())
    end

    self:CleanDiscardCombat()
end

function CC:MergeTrashCleanup()

    local baseCombat = Details:GetCombat(2)
    if not baseCombat or not baseCombat:IsMythicDungeon() or baseCombat:IsMythicDungeonOverall() then
        return
    end

    local base = baseCombat:GetCombatNumber()
    local prevCombat = Details:GetCombat(3)
    if prevCombat then
        local prev = prevCombat:GetCombatNumber()
        for i = prev + 1, base - 1 do
            if i ~= self.overall then
                self:MergeCombat(base, i)
            end
        end
    else
        local minCombat
        for combatID in pairs(self.db) do
            minCombat = minCombat and min(minCombat, combatID) or combatID
        end

        if minCombat then
            for i = minCombat, base - 1 do
                self:MergeCombat(base, i)
            end
        end
    end

    self:CleanDiscardCombat()
end

function CC:MergeRemainingTrashAfterAllBossesDone()

    local prevTrash = Details:GetCombat(2)
    if prevTrash then
        local prev = prevTrash:GetCombatNumber()
        self:MergeCombat(prev, self.current)
    end

    self:CleanDiscardCombat()
end

function CC:CleanDiscardCombat()
    local remain = {}

    for i = 1, 25 do
        local combat = Details:GetCombat(i)
        if not combat then
            break
        end

        remain[combat:GetCombatNumber()] = true
    end
    if self.overall then
        remain[self.overall] = true
    end

    for key in pairs(self.db) do
        if not remain[key] then
            self.db[key] = nil
        end
    end
end

function CC:OnDetailsEvent(event, combat)
    if event == 'COMBAT_PLAYER_ENTER' then
        CC.current = combat:GetCombatNumber()
        CC:UpdateOverall()
    elseif event == 'COMBAT_PLAYER_LEAVE' then
        CC.current = combat:GetCombatNumber()
    elseif event == 'DETAILS_DATA_RESET' then
        CC:UpdateOverall()
        CC:CleanDiscardCombat()
    end
end

function CC:ResetOverall()
    CC:UpdateOverall()
end

function CC:UpdateOverall()
    local newOverall = Details:GetCombat(-1):GetCombatNumber()

    if self.overall and self.overall ~= newOverall and self.db[self.overall] then
        self.db[self.overall] = nil
    end
    self.overall = newOverall
end

function CC:LoadHooks()
    self:SecureHook(_G.DetailsMythicPlusFrame, 'MergeSegmentsOnEnd')
    self:SecureHook(_G.DetailsMythicPlusFrame, 'MergeTrashCleanup')
    self:SecureHook(_G.DetailsMythicPlusFrame, 'MergeRemainingTrashAfterAllBossesDone')

    if Details.historico.ResetOverallData then
        self:SecureHook(Details.historico, 'ResetOverallData', 'ResetOverall')
    else
        self:SecureHook(Details.historico, 'resetar_overall', 'ResetOverall')
    end
    self.overall = Details:GetCombat(-1):GetCombatNumber()

    self.EventListener = Details:CreateEventListener()
    self.EventListener:RegisterEvent('COMBAT_PLAYER_ENTER')
    self.EventListener:RegisterEvent('COMBAT_PLAYER_LEAVE')
    self.EventListener:RegisterEvent('DETAILS_DATA_RESET')
    self.EventListener.OnDetailsEvent = self.OnDetailsEvent

    Details:InstallCustomObject(self.CustomDisplayStops)
    Details:InstallCustomObject(self.CustomDisplayOverlaps)
    self:CleanDiscardCombat()
end

function CC:OnInitialize()
    self.db = CancelCultureLog or {}
    CancelCultureLog = self.db
    
    self.current = 0

    for spellId in pairs(self.interruptSpells) do
        self.allStopSpells[spellId] = true
    end
    for spellId in pairs(self.ccInterruptSpells) do
        self.allStopSpells[spellId] = true
    end
    for spellId in pairs(self.knockbackSpells) do
        self.allStopSpells[spellId] = true
    end

    self:RegisterEvent('PLAYER_ENTERING_WORLD', 'InitDataCollection')
    self:RegisterEvent('CHALLENGE_MODE_START', 'InitDataCollection')

    self:RegisterEvent('PLAYER_LOGIN', 'LoadHooks')
end
