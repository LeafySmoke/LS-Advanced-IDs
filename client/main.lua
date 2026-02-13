local Framework = nil
local ESX = nil
local QBCore = nil

-- Detect Framework
CreateThread(function()
    if GetResourceState("es_extended") == "started" then
        Framework = "ESX"
        ESX = exports["es_extended"]:getSharedObject()
    elseif GetResourceState("qb-core") == "started" or GetResourceState("qbx-core") == "started" then
        Framework = "QB"
        QBCore = exports["qb-core"]:GetCoreObject()
    else
        Framework = "Standalone"
    end
end)

local function Notify(msg, type)
    if Framework == "ESX" and ESX then
        ESX.ShowNotification(msg)
    elseif Framework == "QB" and QBCore then
        QBCore.Functions.Notify(msg, type or "primary")
    else
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(true, false)
    end
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
RegisterCommand("showcard", function(_, args)
    local cardType = (args[1] or "driver"):lower()
    local quality = (args[2] or "real"):lower()
    TriggerServerEvent("idcard:showCard", -1, cardType, quality)
end, false)

RegisterCommand("showcardto", function(_, args)
    local closestPlayer, closestDistance = GetClosestPlayer()
    if closestPlayer == -1 or closestDistance > 3.0 then
        Notify("~r~No player nearby!", "error")
        return
    end
    local cardType = (args[1] or "driver"):lower()
    local quality = (args[2] or "real"):lower()
    TriggerServerEvent("idcard:showCard", GetPlayerServerId(closestPlayer), cardType, quality)
end, false)

-- Refactored Photo Setup to prevent "Frozen in sky" bugs
RegisterNetEvent("idcard:capturePhoto", function()
    local ped = PlayerPedId()
    
    -- Wait until player is actually spawned and not in a loading screen
    if IsPlayerSwitchInProgress() or not HasCollisionLoadedAroundEntity(ped) then
        Wait(5000) -- Delay if player is still "falling" or loading
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local bonePos = GetPedBoneCoords(ped, 12844, 0.0, 0.0, 0.0) 

    -- Position camera for clean face shot
    local camPos = vector3(bonePos.x, bonePos.y - 0.4, bonePos.z + 0.15)
    local cam = CreateCamWithParams("DEFAULT_SCRIPTED_FLY_CAMERA", camPos.x, camPos.y, camPos.z, 
                                   0.0, 0.0, heading, 40.0, true, 2)
    
    local function CleanupCamera()
        RenderScriptCams(false, false, 500, true, false)
        DestroyCam(cam, false)
        ClearTimecycleModifier()
        SetFocusEntity(nil)
    end

    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, false)
    SetFocusEntity(ped)
    SetTimecycleModifier("int_extlight_sunrise")

    -- Failsafe: If screenshot takes longer than 10 seconds, force cleanup
    SetTimeout(10000, function()
        CleanupCamera()
    end)

    -- Screenshot - FIXED EXPORT NAME
    exports["screenshot-basic"]:requestScreenshot(function(data)
        TriggerServerEvent("idcard:savePhoto", data)
        CleanupCamera()
        Notify("~g~ID photo captured!")
    end, {
        format = "png",
        quality = 0.85,
        width = 280,
        height = 360
    })
end)

-- Framework auto-request
CreateThread(function()
    while Framework == nil do Wait(100) end
    
    if Framework == "ESX" then
        RegisterNetEvent("esx:playerLoaded")
        AddEventHandler("esx:playerLoaded", function()
            Wait(10000) -- Wait for spawn to fully complete
            TriggerServerEvent("idcard:requestPhoto")
        end)
    elseif Framework == "QB" then
        RegisterNetEvent("QBCore:Client:OnPlayerLoaded")
        AddEventHandler("QBCore:Client:OnPlayerLoaded", function()
            Wait(10000) -- Wait for spawn to fully complete
            TriggerServerEvent("idcard:requestPhoto")
        end)
    end
end)

-- Standalone manual
RegisterCommand("takeidphoto", function()
    TriggerServerEvent("idcard:requestPhoto")
end, false)