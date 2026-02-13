-- client/ui.lua
RegisterNetEvent('idcard:showUI')
AddEventHandler('idcard:showUI', function(data)
    SendNUIMessage({
        action = 'showID',
        data = data
    })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('closeUI', function(_, cb)
    SetNuiFocus(false, false)
    cb(1)
end)