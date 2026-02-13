-- server/main.lua (full refactor + photo logic)
local Framework = nil
local ESX = nil
local QBCore = nil

-- Framework detect (server side)
if GetResourceState('es_extended') == 'started' then
    Framework = 'ESX'
    ESX = exports["es_extended"]:getSharedObject()
elseif GetResourceState('qb-core') == 'started' or GetResourceState('qbx-core') == 'started' then
    Framework = 'QB'
    QBCore = exports['qb-core']:GetCoreObject()
end

-- Base64 decode (pure Lua)
local b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64decode(data)
    data = string.gsub(data, '[^' .. b64 .. '=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', b64:find(x) - 1
        for i = 6, 1, -1 do r = r .. (bit.band(f, bit.lshift(1, i - 1)) ~= 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and bit.lshift(1, 8 - i) or 0) end
        return string.char(c)
    end))
end

local function GetPlayerId(src)
    if Framework == 'ESX' then
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer.identifier
    elseif Framework == 'QB' then
        local player = QBCore.Functions.GetPlayer(src)
        return player.PlayerData.citizenid
    else
        local ids = GetPlayerIdentifiers(src)
        for _, id in ipairs(ids) do
            if string.match(id, 'license:') then
                return id:sub(9)
            end
        end
        return 'unknown'
    end
end

local function GetServerPlayerData(src, cardType)
    local player
    if Framework == 'ESX' then player = ESX.GetPlayerFromId(src)
    elseif Framework == 'QB' then player = QBCore.Functions.GetPlayer(src) end
    if player == nil and Framework ~= 'Standalone' then return nil end

    local data = { type = cardType, photo = GetPlayerId(src) .. '.png' }

    -- Name/DOB/Sex/Height/Job
    if Framework == 'ESX' then
        data.name = player.getName()
        data.dob = player.get('dateofbirth') or os.date('%m/%d/%Y', os.time() - math.random(20*365, 50*365)*86400)
        data.sex = player.get('sex') == 0 and 'Male' or 'Female'
        data.height = player.get('height') or 180
        local job = player.getJob()
        data.job = job.label
    elseif Framework == 'QB' then
        local charinfo = player.PlayerData.charinfo
        data.name = charinfo.firstname .. ' ' .. charinfo.lastname
        data.dob = charinfo.birthdate or os.date('%m/%d/%Y', os.time() - math.random(20*365, 50*365)*86400)
        data.sex = charinfo.gender == 0 and 'Male' or 'Female'
        data.height = charinfo.height or 180
        data.job = player.PlayerData.job.label
    else  -- Standalone
        data.name = GetPlayerName(src)
        data.dob = os.date('%m/%d/%Y', os.time() - math.random(20*365, 50*365)*86400)
        data.sex = math.random(2) == 1 and 'Male' or 'Female'
        data.height = math.random(160, 195)
        data.job = 'Civilian'
    end

    -- Card-specific
    local cardConfig = Config.Cards[cardType]
    if cardConfig and cardConfig.jobRequired then
        local jobName = Framework == 'ESX' and player.getJob().name or player.PlayerData.job.name
        local allowed = false
        for _, req in ipairs(cardConfig.jobRequired) do
            if jobName:lower():find(req:lower()) then allowed = true break end
        end
        if not allowed then return nil end
    end

    if cardType == 'driver' then
        data.dlNumber = Config.DLFormats.number()
        data.class = 'C'
        data.expDate = Config.DLFormats.exp()
        data.issueDate = Config.DLFormats.issue()
        data.restrictions = 'NONE'
        local nameParts = {}
        for part in data.name:gmatch('%S+') do table.insert(nameParts, part:upper()) end
        data.name_split_ln = nameParts[#nameParts] or ''
        table.remove(nameParts, #nameParts)
        data.name_split_fn = table.concat(nameParts, ' ')
        data.sexShort = data.sex:sub(1,1)
        local ft = math.floor(data.height / 30.48)
        local inch = math.floor((data.height % 30.48) / 2.54)
        data.heightFt = ft .. "'" .. inch .. '"'
        data.weight = math.random(120, 220) .. ' lbs'
        data.hair = math.random() > 0.5 and 'BRN' or 'BLK'
        data.eyes = math.random() > 0.5 and 'BLU' or 'BRO'
        data.signature = data.name:gsub(' ', '_'):lower()
    elseif cardType == 'badge' then
        data.badgeNumber = math.random(1000, 9999)
        data.department = data.job or 'Los Santos PD'
        data.rank = data.job:match('Officer') and 'Officer' or data.job
    elseif cardType == 'marijuana' then
        data.cardId = string.format('%07d', math.random(1000000, 9999999))
        data.doctor = 'Dr. Feelgood'
        data.issueDate = os.date('%m/%d/%Y', os.time() - math.random(30, 365)*86400)
        data.expiryDate = os.date('%m/%d/%Y', os.time() + math.random(365, 730)*86400)
        data.conditions = 'Chronic Pain, Anxiety'
        data.verifyUrl = 'www.sacmmj.ca.gov'
        data.county = 'Los Santos County'
        data.phone = '888-621-2204'
    end

    return data
end

-- Show card (unified)
RegisterNetEvent('idcard:showCard')
AddEventHandler('idcard:showCard', function(targetServerId, cardType, quality)
    local data = GetServerPlayerData(source, cardType)
    if not data then return end  -- Invalid card/job
    data.quality = quality
    local ttarget = targetServerId == -1 and source or targetServerId
    TriggerClientEvent('idcard:showUI', ttarget, data)
end)

-- Photo request & save
RegisterNetEvent('idcard:requestPhoto')
AddEventHandler('idcard:requestPhoto', function()
    local id = GetPlayerId(source)
    local path = GetResourcePath(GetCurrentResourceName()) .. '/html/images/' .. id .. '.png'
    local f = io.open(path, 'rb')
    if not f then
        TriggerClientEvent('idcard:capturePhoto', source)
    else
        f:close()
    end
end)

RegisterNetEvent('idcard:savePhoto')
AddEventHandler('idcard:savePhoto', function(base64data)
    local b64 = base64data:match(',(.*)')
    if not b64 then return end
    local id = GetPlayerId(source)
    local path = GetResourcePath(GetCurrentResourceName()) .. '/html/images/' .. id .. '.png'
    local f = io.open(path, 'wb')
    if f then
        f:write(base64decode(b64))
        f:close()
        print(('^2ID Photo saved for %s: %s^7'):format(GetPlayerName(source), id))
    end
end)