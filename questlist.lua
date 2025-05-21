--[[
Ashita Addon - Quest List
Author: mielke
Description:
    This addon reads packet 0x0056 as described in the documentation provided:
    https://github.com/atom0s/XiPackets/blob/main/world/server/0x0056/README.md
    It parses the list of available missions and populates a 'quests' table
    with the currently ready (not completed) missions, categorized by their types.

Dependencies:
    - Ashita v4
    - Lua 5.1+

Commands:
    /quests - Display the list of current quests.
]]--

addon.name     = 'questlist'
addon.author   = 'mielke'
addon.version  = '1.0.0'
addon.desc     = 'Displays currently ready quests.'

require('common')

local imgui = require('imgui')

local walkthroughs = require('ffxi_walkthroughs')

require('quests')
require('missions')

local questStatus = T{
    ['Open'] = 0,
    ['Completed'] = 1
}

local mapping = T{
    -- missions
    [0x00D0] = { Container='San dOria, Bastok, Windurst', Offset=0x0, Area=xi.questLog.SANDORIA_BASTOK_WINDURST, Status=questStatus.Completed },
    [0x00D8] = { Container='Treasures, Wings of the Goddess', Offset=0x20, Area=xi.questLog.TREASURES_WINGS, Status=questStatus.Completed },
    [0x0030] = { Container='Campaign', Offset=0x40, Area=xi.questLog.OTHERS, Status=questStatus.Completed },
    [0x0038] = { Container='Campaign', Offset=0x60, Area=xi.questLog.OTHERS, Status=questStatus.Completed },

    --quests
    [0x0090] = { Container='San dOria', Offset=0x0, Area=xi.questLog.SANDORIA, Status=questStatus.Completed },
    [0x0098] = { Container='Bastok', Offset=0x20, Area=xi.questLog.BASTOK, Status=questStatus.Completed },
    [0x00A0] = { Container='Windurst', Offset=0x40, Area=xi.questLog.WINDURST, Status=questStatus.Completed },
    [0x00A8] = { Container='Jeuno', Offset=0x60, Area=xi.questLog.JEUNO, Status=questStatus.Completed },
    [0x00B0] = { Container='Other Areas', Offset=0x80, Area=xi.questLog.OTHER_AREAS, Status=questStatus.Completed },
    [0x00B8] = { Container='Outlands', Offset=0xA0, Area=xi.questLog.OUTLANDS, Status=questStatus.Completed },
    [0x00C0] = { Container='Aht Urhgan', Offset=0xC0, Area=xi.questLog.AHT_URHGAN, Status=questStatus.Completed },
    [0x00C8] = { Container='Crystal War', Offset=0xE0, Area=xi.questLog.CRYSTAL_WAR, Status=questStatus.Completed },
    [0x00E8] = { Container='Abyssea', Offset=0x100, Area=xi.questLog.ABYSSEA, Status=questStatus.Completed },
    [0x00F8] = { Container='Adoulin', Offset=0x120, Area=xi.questLog.ADOULIN, Status=questStatus.Completed },
    [0x0108] = { Container='Coalition', Offset=0x140, Area=xi.questLog.COALITION, Status=questStatus.Completed },

    [0x0050] = { Container='San dOria', Offset=0x0, Area=xi.questLog.SANDORIA, Status=questStatus.Open },
    [0x0058] = { Container='Bastok', Offset=0x20, Area=xi.questLog.BASTOK, Status=questStatus.Open },
    [0x0060] = { Container='Windurst', Offset=0x40, Area=xi.questLog.WINDURST, Status=questStatus.Open },
    [0x0068] = { Container='Jeuno', Offset=0x60, Area=xi.questLog.JEUNO, Status=questStatus.Open },
    [0x0070] = { Container='Other Areas', Offset=0x80, Area=xi.questLog.OTHER_AREAS, Status=questStatus.Open },
    [0x0078] = { Container='Outlands', Offset=0xA0, Area=xi.questLog.OUTLANDS, Status=questStatus.Open },
    [0x0080] = { Container='Aht Urhgan', Offset=0xC0, Area=xi.questLog.AHT_URHGAN, Status=questStatus.Open },
    [0x0088] = { Container='Crystal War', Offset=0xE0, Area=xi.questLog.CRYSTAL_WAR, Status=questStatus.Open },
    [0x00E0] = { Container='Abyssea', Offset=0x100, Area=xi.questLog.ABYSSEA, Status=questStatus.Open },
    [0x00F0] = { Container='Adoulin', Offset=0x120, Area=xi.questLog.ADOULIN, Status=questStatus.Open },
    [0x0100] = { Container='Coalition', Offset=0x140, Area=xi.questLog.COALITION, Status=questStatus.Open }
}
local nations = T{
    [0] = "San dOria",
    [1] = "Bastok",
    [2] = "Windurst"
}
local player_nation = 0

local missionCore = {}

local function cleanQuestName(text)
    return string.gsub(string.gsub(string.gsub(string.lower(text), "'", ""), " ", ""), "\"", "")
end

local function parse_quest_packet(packet)
    local port = struct.unpack('H', packet, 0x24+1)

    -- 0xFFFE - The Voracious Resurgence Information
    if port == 0xFFFE then
        local byte = struct.unpack('B', packet, 0x04 + 1)
        missionCore['TVR'] = byte

    -- 0xFFFF - Main Mission Information
    elseif port == 0xFFFF then

        -- Nation
        local byte = struct.unpack('B', packet, 0x04 + 1)
        player_nation = nations[byte]


        -- Nation Mission
        byte = struct.unpack('B', packet, 0x04 + 1 + 1)
        if byte == 0xFFFF then
            missionCore['Nation Mission'] = nil
        else
            missionCore['Nation Mission'] = bit.band(byte, 0xFFFF)
        end


        -- Rise of the Zilart
        byte = struct.unpack('B', packet, 0x04 + 2 + 1)
        if byte == 0xFFFF then
            missionCore['Rise of the Zilart'] = nil
        else
            missionCore['Rise of the Zilart'] = bit.band(byte, 0xFFFF)
        end


        -- Chains of Promathia
        byte = struct.unpack('B', packet, 0x04 + 3 + 1)
        missionCore['Chains of Promathia'] = byte
        -- sub mission branches
        if byte == 325 or byte == 530 then
            byte = struct.unpack('B', packet, 0x04 + 4 + 1)
            missionCore['Chains of Promathia - Sub-Mission'] = byte
        end


        -- Addon Scenarios
        byte = struct.unpack('B', packet, 0x04 + 5 + 1)
        byte = bit.band(byte, 0xFFFF)
        local bit1 = bit.band(byte, 0x0F)
        if bit1 >= 0x00 and bit1 <= 0x0B then
            missionCore['Addon Scenarios'] = "A Crystalline Prophecy"
        end
        local bit2 = bit.lshift(byte, 0x04)
        if bit2 >= 0x00 and bit2 <= 0x0E then
            missionCore['Addon Scenarios'] = " A Moogle Kupo d'Etat"
        end
        local bit3 = bit.lshift(byte, 0x08)
        if bit3 >= 0x00 and bit3 <= 0x0E then
            missionCore['Addon Scenarios'] = "A Shantotto Ascension"
        end
        

        -- Tales'Beginning
        byte = struct.unpack('B', packet, 0x04 + 5 + 1)
        missionCore['TalesBeginning'] = bit.rshift(byte, 16)


        -- Seekers of Adoulin
        byte = struct.unpack('B', packet, 0x04 + 6 + 1)
        if byte == 999 then -- When the client has completed the original SoA mission line prior to the Epilogue, this value will be set to 999.
            missionCore['Seekers of Adoulin'] = nil
        else
            byte = bit.rshift(byte, 16)
            missionCore['Seekers of Adoulin'] = {}
            for j = 0,7 do
                local bit = (bit.band(byte, bit.lshift(1, j)) > 0)
                missionCore['Seekers of Adoulin'][j] = bit
            end
        end


        -- Rhapsodies of Vanadiel
        byte = struct.unpack('B', packet, 0x04 + 7 + 1)
        if byte == 999 then -- When the client has completed the original RoV mission line prior to the Epilogue, this value will be set to 999.
            missionCore['Rhapsodies of Vanadiel'] = nil
        else
            missionCore['Rhapsodies of Vanadiel'] = {}
            for j = 0,7 do
                local bit = (bit.band(byte, bit.lshift(1, j)) > 0)
                missionCore['Rhapsodies of Vanadiel'][j] = bit
            end
        end

    -- Other - All Other Port Values
    -- [mission_id] = 1/0
    else
        local mappingData = mapping[port]
        if mappingData then
            local dataTable = missionCore[mappingData.Container]
            if not dataTable then
                dataTable = {}
                missionCore[mappingData.Container] = dataTable
            end
            for i = 0,31 do
                local byte = struct.unpack('B', packet, 0x04 + i + 1)
                local offset = (i + mappingData.Offset) * 8
                for j = 0,7 do
                    local bit = (bit.band(byte, bit.lshift(1, j)) > 0)
                    local id = (i*8)+j
                    if type(xi.quest.id[xi.quest.area[mappingData.Area]]) == 'table' then
                        if bit then
                            local questName = xi.quest.id[xi.quest.area[mappingData.Area]][id] or "NoName"
                            local questNameCheck = cleanQuestName(questName)
                            local walkthrough = ''
                            local title = questName
                            if questName ~= "NoName" then
                                for _, v in pairs(walkthroughs) do
                                    if cleanQuestName(v.title) == questNameCheck then
                                        title = v.title
                                        walkthrough = v.walkthrough
                                        break
                                    end
                                end
                            end

                            if not dataTable[id] or mappingData.Status == questStatus.Completed then
                                dataTable[id] = {
                                    Name = title,
                                    Status = mappingData.Status,
                                    Walkthrough = walkthrough
                                }
                            end
                        end
                    end
                end
            end
        end 
    end
end

local function render_quests(status)
    for k_mission, missions in pairs(missionCore) do
        if type(missions) == "table" then
            local rendered_header = false
            for k, v in pairs(missions) do
                if type(v) == "table" then
                    if v.Status == status then
                        if not rendered_header then
                            imgui.TextColored({ 1.0, 1.0, 0.26, 1.0 }, string.format("%s", k_mission))
                            rendered_header = true
                        end
                        imgui.TextColored({ 1.0, 0.65, 0.26, 1.0 }, string.format("  %s", v.Name));
                        if imgui.IsItemHovered() then
                            if imgui.IsMouseClicked(0) then
                                ashita.misc.open_url(string.format("https://www.bg-wiki.com/ffxi/%s", v.Name))
                            end
                            if v.Walkthrough and v.Walkthrough ~= "" then
                                imgui.BeginTooltip()
                                imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, string.format("%s", v.Walkthrough))
                                imgui.EndTooltip()
                            end
                        end
                    end
                else
                    if v then
                        if not rendered_header then
                            imgui.TextColored({ 1.0,  1.0, 0.26, 1.0 }, string.format("%s", k_mission))
                            rendered_header = true
                        end
                        imgui.TextColored({ 1.0, 0.65, 0.26, 1.0 }, string.format("%s: %s", k, v))
                    end
                end
            end
        else
            if (type(missions) == 'number' and missions > 0) then
                imgui.TextColored({ 1.0, 0.65, 0.26, 1.0 }, string.format("- %s: %s", k_mission, missions))
            end
        end
    end
end

local function render()
    imgui.SetNextWindowSize({ 300, 400, })
    imgui.SetNextWindowSizeConstraints({ 300, 400, }, { FLT_MAX, FLT_MAX, })
    if (imgui.Begin('QuestList', true, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoBackground))) then
        if (imgui.BeginTabBar('##questlist_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton)) then
            -- open missions
            if (imgui.BeginTabItem('Missions', nil)) then
                imgui.EndTabItem()
            end
            -- open quests
            if (imgui.BeginTabItem('Quests', nil)) then
                render_quests(questStatus.Open)
                imgui.EndTabItem()
            end
            -- completed quests
            if (imgui.BeginTabItem('Completed', nil)) then
                render_quests(questStatus.Completed)
                imgui.Separator()

                imgui.EndTabItem()
            end

            imgui.EndTabBar()
        end
    end
    imgui.End()
end

-- Event: Load
ashita.events.register('load', 'load_cb', function()
    print(string.format('%s v%s loaded.', addon.name, addon.version))
end)

-- Event: Unload
ashita.events.register('unload', 'unload_cb', function()
    print(string.format('%s unloaded.', addon.name))
end)

-- Event: Incoming Packet
ashita.events.register('packet_in', 'packet_in_cb', function(e)
    if e.id == 0x0056 then
        parse_quest_packet(e.data)
    end
end)

-- Event: Command
ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args()
    if (#args == 0 or not args[1]:any('/quests')) then
        return
    end

    e.blocked = true
    print("quests")
    for k, missions in pairs(missionCore) do
        if type(missions) == "table" then
            print(k)
            for k, v in pairs(missions) do
                if type(v) == "table" then
                    print(string.format('  [%s] %s', k, v.Name))
                else
                    if v then
                        print(string.format('  [%s] - %s', k, v))
                    end
                end
            end
        else
            print(string.format('%s: %s', k, missions))
        end
    end
end)

ashita.events.register('d3d_present', 'present_cb', render)
