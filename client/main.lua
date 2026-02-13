-- client/main.lua
local Framework = nil
local ESX = nil
local QBCore = nil

-- Detect Framework
Citizen.CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        Framework = 'ESX'
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    elseif GetResourceState('qb-core') == 'started' or GetResourceState('qbx-core') == 'started' then
        Framework = 'QB'
        QBCore = exports['qb-core']:GetCoreObject()
    else
        Framework = 'Standalone'
    end
end)

local function Notify(msg, type)
    if Framework == 'ESX' and ESX then
        ESX.ShowNotification(msg)
    elseif Framework == 'QB' and QBCore then
        QBCore.Functions.Notify(msg, type or 'primary')
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(true, false)
    end
end

local function GetPlayerData(cardType)
    local data = {type = cardType}
    local playerJob = {name = 'civilian', label = 'Civilian'}

    -- Base info
    if Framework == 'ESX' and ESX then
        local xPlayer = ESX.GetPlayerData()
        data.name = xPlayer.name or xPlayer.getName()
        data.dob = xPlayer.dateofbirth or '01/01/2000'
        data.sex = (xPlayer.sex == 0 and 'Male') or 'Female'
        data.height = xPlayer.height or 180
        playerJob = xPlayer.job
    elseif Framework == 'QB' and QBCore then
        local PlayerData = QBCore.Functions.GetPlayerData()
        data.name = (PlayerData.charinfo.firstname or '') .. ' ' .. (PlayerData.charinfo.lastname or '')
        data.dob = PlayerData.charinfo.birthdate or '01/01/2000'
        data.sex = (PlayerData.charinfo.gender == 0 and 'Male') or 'Female'
        data.height = PlayerData.charinfo.height or 180
        playerJob = PlayerData.job
    else
        data.name = GetPlayerName(PlayerId())
        data.dob = os.date('%m/%d/%Y', os.time() - math.random(18*365, 50*365) * 86400)
        data.sex = math.random() > 0.5 and 'Male' or 'Female'
        data.height = 160 + math.random(0, 40)
    end

if cardType == 'driver' then
        data.dlNumber = Config.DLFormats.number()
        data.class = 'C'
        data.expDate = Config.DLFormats.exp()
        data.issueDate = Config.DLFormats.issue()
        data.restrictions = 'NONE'
        data.sexShort = data.sex:sub(1,1)
        data.heightFt = math.floor(data.height / 30.48) .. '\'-' .. math.floor((data.height % 30.48)/2.54) .. '"'
        data.weight = math.random(120,220) .. ' lbs'
        data.hair = 'BRN'
        data.eyes = 'BLU'
        data.signature = data.name:gsub(' ', '_'):lower()  -- Fake sig
    elseif cardType == 'badge' then
        data.badgeNumber = math.random(1000, 9999)
        data.department = playerJob.label or 'Los Santos PD'
        data.rank = playerJob.grade and playerJob.grade.name or playerJob.label or 'Officer'
    elseif cardType == 'marijuana' then
        data.cardId = string.format('%07d', math.random(1000000,9999999))
        data.expDate = os.date('%m/%d/%Y', os.time() + 365*86400)
        data.verifyUrl = 'www.calmmp.ca.gov'
        data.county = 'Los Santos County'
        data.phone = '888-621-2204'
    end

    return data
end

local function GetClosestPlayer()
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local ply = PlayerPedId()
    local plyCoords = GetEntityCoords(ply, 0)
    for index, value in ipairs(players) do
        local targetPed = GetPlayerPed(value)
        if targetPed ~= ply then
            local targetCoords = GetEntityCoords(targetPed, 0)
            local distance = #(targetCoords - plyCoords)
            if closestDistance == -1 or distance < closestDistance then
                closestPlayer = value
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end

-- Show own card
RegisterCommand('showcard', function(_, args)
    local cardType = (args[1] or 'driver'):lower()
    local quality = (args[2] or 'real'):lower()
    TriggerServerEvent('idcard:showCard', -1, cardType, quality)  -- -1 = self
end, false)

RegisterCommand('showcardto', function(_, args)
    local closestPlayer, closestDistance = GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
        Notify('~r~No player nearby!', 'error')
        return
    end
    local cardType = (args[1] or 'driver'):lower()
    local quality = (args[2] or 'real'):lower()
    TriggerServerEvent('idcard:showCard', GetPlayerServerId(closestPlayer), cardType, quality)
end, false)

-- Auto photo setup
RegisterNetEvent('idcard:capturePhoto')
AddEventHandler('idcard:capturePhoto', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local bonePos = GetPedBoneCoords(ped, 12844, 0.0, 0.0, 0.0)  -- Head bone

    -- Position camera for clean face shot
    local camPos = vector3(bonePos.x, bonePos.y - 0.4, bonePos.z + 0.15)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_FLY_CAMERA', camPos.x, camPos.y, camPos.z, 
                                   0.0, 0.0, heading, 40.0, true, 2)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, false)
    SetFocusEntity(ped)
    SetTimecycleModifier('int_extlight_sunrise')  -- Good lighting

    -- Screenshot
    exports['screenshot-basic']:requestScreenshotClient(function(data)
        TriggerServerEvent('idcard:savePhoto', data)
        
        -- Cleanup
        RenderScriptCams(false, false, 500, true, false)
        DestroyCam(cam, false)
        ClearTimecycleModifier()
        SetFocusEntity(nil)
        Notify('~g~ID photo captured!')
    end, {
        format = 'png',
        quality = 0.85,
        renderer = 'directx',
        width = 280,
        height = 360
    })
end)

-- Framework auto-request
Citizen.CreateThread(function()
    while Framework == nil do Wait(100) end
    
    if Framework == 'ESX' then
        RegisterNetEvent('esx:playerLoaded')
        AddEventHandler('esx:playerLoaded', function()
            TriggerServerEvent('idcard:requestPhoto')
        end)
    elseif Framework == 'QB' then
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            TriggerServerEvent('idcard:requestPhoto')
        end)
    end
end)

-- Standalone manual
RegisterCommand('takeidphoto', function()
    TriggerServerEvent('idcard:requestPhoto')
end, false)