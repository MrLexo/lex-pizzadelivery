local QBCore = exports['qb-core']:GetCoreObject()
local Config = lib.require('config/sh_config')

local sessions = {}

local function notify(src, msg, nType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Pizza Job',
        description = msg,
        type = nType or 'inform',
        position = 'top-right'
    })
end

local function hasItem(Player, item)
    local it = Player.Functions.GetItemByName(item)
    return it and it.amount and it.amount > 0
end

local function dist(a, b)
    return #(a - b)
end

local function pickUniqueLocations(count)
    local out, used = {}, {}
    local pool = Config.DeliveryLocations
    if not pool or #pool == 0 then return out end

    local wanted = math.min(count, #pool)
    while #out < wanted do
        local idx = math.random(1, #pool)
        if not used[idx] then
            used[idx] = true
            out[#out + 1] = pool[idx]
        end
    end

    return out
end

local function popRandom(t)
    local n = #t
    if n == 0 then return nil end
    local idx = math.random(1, n)
    local v = t[idx]
    table.remove(t, idx)
    return v
end

local function safeDeleteVehicleByNet(netId)
    if not netId then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        DeleteEntity(ent)
    end
end

local function spawnJobVehicleFor(src)
    local spawn = Config.VehicleSpawn
    local veh = CreateVehicle(Config.VehicleModel, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    while not DoesEntityExist(veh) do Wait(0) end

    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        TaskWarpPedIntoVehicle(ped, veh, -1)
    end

    return NetworkGetNetworkIdFromEntity(veh)
end

lib.callback.register('lex_pizza:server:startRun', function(source)
    local src = source

    if sessions[src] then
        notify(src, 'You are already on a delivery run.', 'error')
        return false
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return false
    end

    local pos = GetEntityCoords(ped)
    local boss = vec3(Config.JobCoords.x, Config.JobCoords.y, Config.JobCoords.z)
    if dist(pos, boss) > (Config.MaxStartDistance or 15.0) then
        notify(src, 'You must be at the pizza shop to start.', 'error')
        return false
    end

    local netId = spawnJobVehicleFor(src)
    if not netId then
        notify(src, 'Vehicle spawn failed.', 'error')
        return false
    end

    local route = pickUniqueLocations(Config.DeliveriesPerRun or 10)
    local current = popRandom(route)
    if not current then
        safeDeleteVehicleByNet(netId)
        notify(src, 'No delivery locations configured.', 'error')
        return false
    end

    sessions[src] = {
        vehNet = netId,
        route = route,
        current = current,
        pay = math.random(Config.PayMin, Config.PayMax),
        hasBox = false,
    }

    return true, {
        vehNet = netId,
        current = current,
        remaining = #route,
    }
end)

lib.callback.register('lex_pizza:server:finishRun', function(source)
    local src = source
    local s = sessions[src]
    if not s then return false end

    if s.hasBox then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.RemoveItem(Config.PizzaItem, Config.PizzaItemAmount or 1)
        end
    end

    safeDeleteVehicleByNet(s.vehNet)
    sessions[src] = nil
    return true
end)

lib.callback.register('lex_pizza:server:deliver', function(source)
    local src = source
    local s = sessions[src]
    if not s or not s.current then
        return false, 'No active delivery.'
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return false, 'Invalid player.'
    end

    local pos = GetEntityCoords(ped)
    local drop = vec3(s.current.x, s.current.y, s.current.z)
    if dist(pos, drop) > (Config.MaxDeliverDistance or 5.0) then
        return false, 'Not at delivery point.'
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        return false, 'Player not found.'
    end

    if not s.hasBox then
        return false, 'You need a pizza box to deliver.'
    end
    
    local item = Config.PizzaItem
    local amount = Config.PizzaItemAmount or 1
    
    if not hasItem(Player, item) then
        s.hasBox = false
        return false, 'Missing pizza box.'
    end
    
    Player.Functions.RemoveItem(item, amount)
    s.hasBox = false

    local pay = s.pay or math.random(Config.PayMin, Config.PayMax)
    Player.Functions.AddMoney(Config.PayAccount, pay, 'pizza-delivery')

    if #s.route == 0 then
        notify(src, ('Delivered. You received $%s. No more deliveries, return to the boss.'):format(pay), 'success')
        return true, { done = true, paid = pay, remaining = 0 }
    end

    local nextLoc = popRandom(s.route)
    s.current = nextLoc
    s.pay = math.random(Config.PayMin, Config.PayMax)

    notify(src, ('Delivered. You received $%s.'):format(pay), 'success')
    return true, { done = false, paid = pay, current = nextLoc, remaining = #s.route }
end)

lib.callback.register('lex_pizza:server:takePizza', function(source, vehNet)
    local src = source
    local s = sessions[src]
    if not s then return false, 'No active run.' end

    if s.hasBox then return false, 'You already have a pizza.' end
    if vehNet ~= s.vehNet then return false, 'Invalid vehicle.' end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'Invalid player.' end

    local vehEnt = NetworkGetEntityFromNetworkId(s.vehNet)
    if not vehEnt or vehEnt == 0 or not DoesEntityExist(vehEnt) then
        return false, 'Vehicle missing.'
    end

    local pPos = GetEntityCoords(ped)
    local vPos = GetEntityCoords(vehEnt)
    if #(pPos - vPos) > 5.0 then
        return false, 'You are too far from the scooter.'
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, 'Player not found.' end

    local item = Config.PizzaItem
    local amount = Config.PizzaItemAmount or 1

    local added = Player.Functions.AddItem(item, amount, false, nil)
    if not added then
        return false, 'Inventory full.'
    end

    s.hasBox = true
    return true
end)

lib.callback.register('lex_pizza:server:returnPizza', function(source, vehNet)
    local src = source
    local s = sessions[src]
    if not s then return false, 'No active run.' end

    if not s.hasBox then return false, 'You are not carrying a pizza.' end
    if vehNet ~= s.vehNet then return false, 'Invalid vehicle.' end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'Invalid player.' end

    local vehEnt = NetworkGetEntityFromNetworkId(s.vehNet)
    if not vehEnt or vehEnt == 0 or not DoesEntityExist(vehEnt) then
        return false, 'Vehicle missing.'
    end

    local pPos = GetEntityCoords(ped)
    local vPos = GetEntityCoords(vehEnt)
    if #(pPos - vPos) > 5.0 then
        return false, 'You are too far from the scooter.'
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false, 'Player not found.' end

    local item = Config.PizzaItem
    local amount = Config.PizzaItemAmount or 1

    if not hasItem(Player, item) then
        s.hasBox = false
        return false, 'You do not have the pizza item.'
    end

    Player.Functions.RemoveItem(item, amount)
    s.hasBox = false
    return true
end)

AddEventHandler('playerDropped', function()
    local src = source
    local s = sessions[src]
    if not s then return end

    if s.hasBox then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.RemoveItem(Config.PizzaItem, Config.PizzaItemAmount or 1)
        end
    end

    safeDeleteVehicleByNet(s.vehNet)
    sessions[src] = nil
end)