local QBCore = exports['qb-core']:GetCoreObject()
local Config = lib.require('config/sh_config')

local preferOx = Config.PreferOxTarget ~= false
local usingOxTarget = preferOx and GetResourceState('ox_target') == 'started'
local usingQBTarget = (not usingOxTarget) and GetResourceState('qb-target') == 'started'

local state = {
    onDuty = false,
    carrying = false,
    active = false,
    delivered = false,
    vehicle = nil,
    vehNet = nil,
    blip = nil,
    zoneId = nil,
    bossPed = nil,
    bossPoint = nil,
    rearBox = nil,
    current = nil,
    customerPed = nil,
}

local deliveriesDone, deliveriesTotal = 0, 0
local counterVisible = false

local function notify(msg, nType)
    lib.notify({ description = msg, type = nType or 'inform', position = 'top-right' })
end

local function UpdateCounterUI()
    if not counterVisible then return end
    lib.showTextUI(('Deliveries: %s/%s'):format(deliveriesDone, deliveriesTotal), {
        position = 'right-center',
        icon = 'pizza-slice'
    })
end

local function ShowCounterUI(total)
    deliveriesDone = 0
    deliveriesTotal = total or 0
    counterVisible = true
    UpdateCounterUI()
end

local function HideCounterUI()
    if counterVisible then
        lib.hideTextUI()
    end
    counterVisible = false
end

local function safeRemoveBlip()
    if state.blip then
        RemoveBlip(state.blip)
        state.blip = nil
    end
end

local function deleteCustomer()
    Wait(2000)
    if DoesEntityExist(state.customerPed) then
        DeleteEntity(state.customerPed)
    end
    state.customerPed = nil
end

local function safeRemoveZone()
    if not state.zoneId then return end
    if usingOxTarget then
        exports.ox_target:removeZone(state.zoneId)
    elseif usingQBTarget then
        exports['qb-target']:RemoveZone(state.zoneId)
    end
    state.zoneId = nil
end

local function keysForVehicle(veh)
    if not DoesEntityExist(veh) then return end
    if GetResourceState('qb-vehiclekeys') ~= 'started' then return end
    local plate = QBCore.Functions.GetPlate(veh)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
end

local function removeRearBox()
    if DoesEntityExist(state.rearBox) then
        DetachEntity(state.rearBox, true, true)
        DeleteEntity(state.rearBox)
    end
    state.rearBox = nil
end

local function attachRearBox(veh)
    removeRearBox()
    if not Config.VehicleBoxEnabled then return end
    if not DoesEntityExist(veh) then return end

    lib.requestModel(Config.VehicleBoxProp)
    local c = GetEntityCoords(veh)
    state.rearBox = CreateObject(Config.VehicleBoxProp, c.x, c.y, c.z + 0.2, false, false, false)

    local off = Config.VehicleBoxOffset
    local rot = Config.VehicleBoxRotation

    AttachEntityToEntity(
        state.rearBox, veh, Config.VehicleBoxBone,
        off.x, off.y, off.z,
        rot.x, rot.y, rot.z,
        false, false, false, false, 2, true
    )

    SetModelAsNoLongerNeeded(Config.VehicleBoxProp)
end

local function setCarry(on)
    if on == state.carrying then return end

    if on then
        lib.requestModel(Config.CarryBoxProp)
        local p = cache.ped
        local c = GetEntityCoords(p)
        state.carryProp = CreateObject(Config.CarryBoxProp, c.x, c.y, c.z, true, true, true)

        local off = Config.CarryOffset
        local rot = Config.CarryRotation
        AttachEntityToEntity(
            state.carryProp, p, GetPedBoneIndex(p, Config.CarryBone),
            off.x, off.y, off.z, rot.x, rot.y, rot.z,
            true, true, false, true, 0, true
        )

        lib.requestAnimDict(Config.CarryAnimDict)
        TaskPlayAnim(p, Config.CarryAnimDict, Config.CarryAnimName, 5.0, 5.0, -1, 51, 0, 0, 0, 0)

        CreateThread(function()
            while DoesEntityExist(state.carryProp) do
                if not IsEntityPlayingAnim(p, Config.CarryAnimDict, Config.CarryAnimName, 3) then
                    TaskPlayAnim(p, Config.CarryAnimDict, Config.CarryAnimName, 5.0, 5.0, -1, 51, 0, 0, 0, 0)
                end
                Wait(1000)
            end
            RemoveAnimDict(Config.CarryAnimDict)
        end)

        SetModelAsNoLongerNeeded(Config.CarryBoxProp)
        state.carrying = true
    else
        if DoesEntityExist(state.carryProp) then
            DetachEntity(state.carryProp, true, true)
            DeleteEntity(state.carryProp)
        end
        state.carryProp = nil
        state.carrying = false
        ClearPedTasksImmediately(cache.ped)
    end

    state.carrying = on
end

local function takePizzaFromBike()
    if not state.onDuty or not state.active then return end
    if state.carrying then return end
    if IsPedInAnyVehicle(cache.ped, false) or IsEntityDead(cache.ped) then return end
    if not state.vehNet then return end

    local ok, err = lib.callback.await('lex_pizza:server:takePizza', false, state.vehNet)
    if not ok then
        return notify(err or 'Could not take pizza.', 'error')
    end

    setCarry(true)
end

local function returnPizzaToBike()
    if not state.onDuty or not state.active then return end
    if not state.carrying then return end
    if not state.vehNet then return end

    local ok, err = lib.callback.await('lex_pizza:server:returnPizza', false, state.vehNet)
    if not ok then
        return notify(err or 'Could not return pizza.', 'error')
    end

    setCarry(false)
end

local function resetAll()
    safeRemoveZone()
    safeRemoveBlip()
    setCarry(false)
    removeRearBox()
    deleteCustomer()

    state.onDuty = false
    state.active = false
    state.delivered = false
    state.vehicle = nil
    state.vehNet = nil
    state.current = nil
    HideCounterUI()
end

local function makeDeliveryBlip(coords)
    safeRemoveBlip()
    state.blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(state.blip, 1)
    SetBlipDisplay(state.blip, 4)
    SetBlipScale(state.blip, 0.8)
    SetBlipFlashes(state.blip, true)
    SetBlipAsShortRange(state.blip, true)
    SetBlipColour(state.blip, 44)
    SetBlipRoute(state.blip, true)
    SetBlipRouteColour(state.blip, 44)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Customer')
    EndTextCommandSetBlipName(state.blip)
end

local function spawnCustomerAt(loc)
    deleteCustomer()

    if not Config.CustomerModels or #Config.CustomerModels == 0 then return end

    local model = Config.CustomerModels[math.random(1, #Config.CustomerModels)]
    lib.requestModel(model)

    state.customerPed = CreatePed(
        4,
        model,
        loc.x, loc.y, loc.z,
        loc.w or 0.0,
        false,
        true
    )

    if not DoesEntityExist(state.customerPed) then
        state.customerPed = nil
        return
    end

    SetEntityAsMissionEntity(state.customerPed, true, true)
    SetBlockingOfNonTemporaryEvents(state.customerPed, true)
    SetEntityInvincible(state.customerPed, true)
    FreezeEntityPosition(state.customerPed, true)

    PlaceObjectOnGroundProperly(state.customerPed)

    if Config.CustomerScenario and Config.CustomerScenario ~= '' then
        TaskStartScenarioInPlace(state.customerPed, Config.CustomerScenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)
end

local function doHandoff()
    local ped = cache.ped
    local customer = state.customerPed

    if not DoesEntityExist(customer) then return end

    lib.requestAnimDict('mp_common')

    FreezeEntityPosition(ped, true)
    FreezeEntityPosition(customer, true)

    TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, 8.0, 2000, 49, 0, false, false, false)
    TaskPlayAnim(customer, 'mp_common', 'givetake2_a', 8.0, 8.0, 2000, 49, 0, false, false, false)

    if DoesEntityExist(state.carryProp) then
        Wait(650)
        DetachEntity(state.carryProp, true, true)

        local hand = GetPedBoneIndex(customer, 57005)
        AttachEntityToEntity(
            state.carryProp,
            customer,
            hand,
            0.12, 0.02, 0.00,
            90.0, 180.0, 0.0,
            true, true, false, true, 0, true
        )

        Wait(600)
        DeleteEntity(state.carryProp)
        state.carryProp = nil
    end

    RemoveAnimDict('mp_common')

    FreezeEntityPosition(ped, false)
    FreezeEntityPosition(customer, false)

    deleteCustomer()

    state.carrying = false
    ClearPedTasksImmediately(ped)
end

local function createDeliveryZone(coords)
    safeRemoveZone()

    if usingOxTarget then
        state.zoneId = exports.ox_target:addSphereZone({
            coords = vec3(coords.x, coords.y, coords.z),
            radius = Config.DeliveryRadius,
            debug = false,
            options = {
                {
                    icon = 'fa-solid fa-pizza-slice',
                    label = 'Deliver Pizza',
                    onSelect = function()
                        if not state.onDuty or not state.active then return end
                        if not state.carrying then return notify('You need to take the pizza from the bike.', 'error') end
                        if state.delivered then return end
                        state.delivered = true

                        lib.progressCircle({
                            duration = Config.DeliveryProgressMs,
                            position = 'bottom',
                            label = 'Delivering Pizza...',
                            useWhileDead = true,
                            canCancel = false,
                            disable = { move = true, car = true, mouse = false, combat = true },
                        })

                        local ok, res = lib.callback.await('lex_pizza:server:deliver', false)
                        state.delivered = false
                        if not ok then
                            notify(res or 'Delivery failed.', 'error')
                            return
                        end
                        if not DoesEntityExist(state.customerPed) then
                            spawnCustomerAt(state.current)
                        end                        
                        doHandoff()
                        deliveriesDone = deliveriesDone + 1
                        UpdateCounterUI()

                        safeRemoveZone()
                        safeRemoveBlip()

                        if res.done then
                            state.active = false
                            deleteCustomer()
                            notify('Run complete. Return to the shop to finish.', 'success')
                            return
                        end

                        state.current = res.current
                        state.active = true
                        makeDeliveryBlip(state.current)
                        createDeliveryZone(state.current)
                        spawnCustomerAt(state.current)
                    end,
                    distance = Config.DeliverInteractDistance
                }
            }
        })
        return
    end

    if usingQBTarget then
        local name = ('pizza_deliver_%s'):format(math.random(10000, 99999))
        exports['qb-target']:AddCircleZone(name, vec3(coords.x, coords.y, coords.z), Config.DeliveryRadius, {
            name = name,
            debugPoly = false,
            useZ = true
        }, {
            options = {
                {
                    icon = 'fa-solid fa-pizza-slice',
                    label = 'Deliver Pizza',
                    action = function()
                        if not state.onDuty or not state.active then return end
                        if not state.carrying then return notify('You need to take the pizza from the scooter.', 'error') end
                        if state.delivered then return end
                        state.delivered = true

                        lib.progressCircle({
                            duration = Config.DeliveryProgressMs,
                            position = 'bottom',
                            label = 'Delivering pizza',
                            useWhileDead = true,
                            canCancel = false,
                            disable = { move = true, car = true, mouse = false, combat = true },
                        })

                        local ok, res = lib.callback.await('lex_pizza:server:deliver', false)
                        state.delivered = false
                        if not ok then
                            notify(res or 'Delivery failed.', 'error')
                            return
                        end
                        if not DoesEntityExist(state.customerPed) then
                            spawnCustomerAt(state.current)
                        end                        
                        doHandoff()
                        deliveriesDone = deliveriesDone + 1
                        UpdateCounterUI()

                        safeRemoveZone()
                        safeRemoveBlip()

                        if res.done then
                            state.active = false
                            deleteCustomer()
                            notify('Run complete. Return to the shop to finish.', 'success')
                            return
                        end

                        state.current = res.current
                        state.active = true
                        makeDeliveryBlip(state.current)
                        createDeliveryZone(state.current)
                        spawnCustomerAt(state.current)
                    end
                }
            },
            distance = Config.DeliverInteractDistance
        })
        state.zoneId = name
    end
end

local function startRun()
    if state.onDuty then return end

    local ok, res = lib.callback.await('lex_pizza:server:startRun', false)
    if not ok or not res then
        notify('Could not start delivery run.', 'error')
        return
    end

    state.onDuty = true
    state.active = true
    state.vehNet = res.vehNet
    state.current = res.current
    spawnCustomerAt(state.current)

    ShowCounterUI((res.remaining or 0) + 1)

    state.vehicle = lib.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(state.vehNet) then
            return NetToVeh(state.vehNet)
        end
    end, 'Vehicle entity timeout.', 1500)

    if not state.vehicle or state.vehicle == 0 then
        notify('Vehicle failed to load.', 'error')
        return
    end

    local plate = (Config.VehiclePlatePrefix or 'PIZZA') .. tostring(math.random(1000, 9999))
    SetVehicleNumberPlateText(state.vehicle, plate)
    SetVehicleColours(state.vehicle, Config.VehiclePrimaryColor, Config.VehicleSecondaryColor)
    SetVehicleDirtLevel(state.vehicle, 1.0)
    SetVehicleEngineOn(state.vehicle, true, true)

    keysForVehicle(state.vehicle)
    attachRearBox(state.vehicle)

    Entity(state.vehicle).state.fuel = Config.FuelAmount

    if usingOxTarget then
        exports.ox_target:addEntity(state.vehNet, {
            {
                icon = 'fa-solid fa-pizza-slice',
                label = 'Take Pizza',
                onSelect = takePizzaFromBike,
                canInteract = function()
                    return state.onDuty and state.active and not state.carrying
                end,
                distance = 2.5
            },
            {
                icon = 'fa-solid fa-pizza-slice',
                label = 'Return Pizza',
                onSelect = returnPizzaToBike,
                canInteract = function()
                    return state.onDuty and state.active and state.carrying
                end,
                distance = 2.5
            }
        })
    elseif usingQBTarget then
        exports['qb-target']:AddTargetEntity(state.vehicle, {
            options = {
                {
                    icon = 'fa-solid fa-pizza-slice',
                    label = 'Take Pizza',
                    action = takePizzaFromBike,
                    canInteract = function()
                        return state.onDuty and state.active and not state.carrying
                    end
                },
                {
                    icon = 'fa-solid fa-pizza-slice',
                    label = 'Return Pizza',
                    action = returnPizzaToBike,
                    canInteract = function()
                        return state.onDuty and state.active and state.carrying
                    end
                }
            },
            distance = 2.5
        })
    end

    makeDeliveryBlip(state.current)
    createDeliveryZone(state.current)
    notify('You have a new delivery!', 'success')
end

local function finishRun()
    if not state.onDuty then return end

    local pos = GetEntityCoords(cache.ped)
    local boss = vec3(Config.JobCoords.x, Config.JobCoords.y, Config.JobCoords.z)
    if #(pos - boss) > 10.0 then return end

    local ok = lib.callback.await('lex_pizza:server:finishRun', false)
    if not ok then
        notify('Could not finish run.', 'error')
        return
    end

    if usingOxTarget and state.vehNet then
        exports.ox_target:removeEntity(state.vehNet, {'Take Pizza', 'Return Pizza'})
    end

    resetAll()
    HideCounterUI()
    notify('Delivery Complete.', 'success')
end

local function deleteBossPed()
    if not DoesEntityExist(state.bossPed) then return end
    if usingOxTarget then
        exports.ox_target:removeLocalEntity(state.bossPed, {'Start Delivery', 'Finish Delivery'})
    elseif usingQBTarget then
        exports['qb-target']:RemoveTargetEntity(state.bossPed, {'Start Delivery', 'Finish Delivery'})
    end
    DeleteEntity(state.bossPed)
    state.bossPed = nil
end

local function spawnBossPed()
    if DoesEntityExist(state.bossPed) then return end

    lib.requestModel(Config.JobModel)
    state.bossPed = CreatePed(0, Config.JobModel, Config.JobCoords, false, false)

    SetEntityAsMissionEntity(state.bossPed)
    SetBlockingOfNonTemporaryEvents(state.bossPed, true)
    SetEntityInvincible(state.bossPed, true)
    FreezeEntityPosition(state.bossPed, true)
    TaskStartScenarioInPlace(state.bossPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(Config.JobModel)

    if usingOxTarget then
        exports.ox_target:addLocalEntity(state.bossPed, {
            {
                icon = 'fa-solid fa-pizza-slice',
                label = 'Start Delivery',
                onSelect = startRun,
                canInteract = function() return not state.onDuty end,
                distance = Config.JobInteract
            },
            {
                icon = 'fa-solid fa-pizza-slice',
                label = 'Finish Delivery',
                onSelect = finishRun,
                canInteract = function() return state.onDuty end,
                distance = Config.JobInteract
            }
        })
    elseif usingQBTarget then
        exports['qb-target']:AddTargetEntity(state.bossPed, {
            options = {
                {
                    icon = 'fa-solid fa-pizza-slice',
                    label = 'Start Delivery',
                    action = startRun,
                    canInteract = function() return not state.onDuty end
                },
                {
                    icon = 'fa-solid fa-pizza-slice',
                    label = 'Finish Delivery',
                    action = finishRun,
                    canInteract = function() return state.onDuty end
                }
            },
            distance = Config.JobInteract
        })
    end
end

local function setupPoint()
    if state.bossPoint then state.bossPoint:remove() end
    state.bossPoint = lib.points.new({
        coords = Config.JobCoords.xyz,
        distance = Config.JobSpawnRadius,
        onEnter = spawnBossPed,
        onExit = deleteBossPed
    })
end

CreateThread(function()
    if not Config.BlipEnabled then return end
    local b = AddBlipForCoord(vec3(Config.JobCoords.x, Config.JobCoords.y, Config.JobCoords.z))
    SetBlipSprite(b, Config.BlipSprite)
    SetBlipAsShortRange(b, true)
    SetBlipScale(b, Config.BlipScale)
    SetBlipColour(b, Config.BlipColor)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.BlipLabel)
    EndTextCommandSetBlipName(b)
end)

AddEventHandler('onResourceStart', function(res)
    if GetCurrentResourceName() ~= res then return end
    if LocalPlayer.state.isLoggedIn then
        setupPoint()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    deleteBossPed()
    resetAll()
    if state.bossPoint then state.bossPoint:remove() end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    setupPoint()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    deleteBossPed()
    resetAll()
    if state.bossPoint then state.bossPoint:remove() end
end)