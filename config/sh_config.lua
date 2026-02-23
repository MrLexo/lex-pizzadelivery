Config = Config or {}

-- Job Start Point
Config.JobModel = `a_m_m_business_01`
Config.JobCoords = vec4(-1529.23, -908.69, 9.17, 138.73)
Config.JobSpawnRadius = 50.0
Config.JobInteract = 1.6

-- Blip
Config.BlipEnabled = true
Config.BlipSprite = 267
Config.BlipScale = 0.6
Config.BlipColor = 44
Config.BlipLabel = 'Pizza Delivery'

-- Vehicle
Config.VehicleModel = `faggio`
Config.VehicleSpawn = vec4(-1533.17, -907.92, 9.15, 137.8)
Config.VehiclePlatePrefix = 'PIZZA'
Config.VehiclePrimaryColor = 111
Config.VehicleSecondaryColor = 111

-- Box Prop Faggio
Config.VehicleBoxEnabled = true
Config.VehicleBoxProp = `h4_prop_h4_box_delivery_01a`
Config.VehicleBoxBone = 21
Config.VehicleBoxOffset = vec3(0.0, 0.40, -0.20)
Config.VehicleBoxRotation = vec3(0.0, 0.0, -90.0)

-- Carry Pizza Box Prop
Config.CarryBoxProp = `prop_pizza_box_01`
Config.CarryAnimDict = 'anim@heists@box_carry@'
Config.CarryAnimName = 'idle'
Config.CarryBone = 28422
Config.CarryOffset = vec3(0.0100, -0.1000, -0.1590)
Config.CarryRotation = vec3(20.0, 0.0, 0.0)

-- Inventory
Config.PizzaItem = "pizza_box"
Config.PizzaItemAmount = 1

-- Delivery
Config.DeliveryRadius = 1.3
Config.DeliverInteractDistance = 1.5
Config.DeliveryProgressMs = 7000

-- Route / Payments
Config.DeliveriesPerRun = 10
Config.PayAccount = 'cash'
Config.PayMin = 105
Config.PayMax = 135

-- Fuel
Config.FuelAmount = 100.0

-- Target
Config.OxTarget = true -- False for qb-target
Config.MaxStartDistance = 15.0
Config.MaxDeliverDistance = 5.0

-- Locations
Config.DeliveryLocations = {
    vec4(57.69, 449.83, 146.03, 326.38),
    vec4(-355.45, 469.78, 111.49, 281.84),
    vec4(-516.59, 433.4, 96.81, 135.11),
    vec4(-509.29, -22.78, 44.61, 359.67),
    vec4(324.92, -229.76, 53.22, 157.46),
    vec4(352.72, -142.67, 65.69, 339.2),
    vec4(920.81, -238.49, 69.17, 151.81),
    vec4(840.82, -182.19, 73.59, 58.63),
    vec4(773.55, -150.33, 74.62, 157.22),
    vec4(1028.83, -408.31, 65.34, 220.0),
    vec4(1006.5, -510.87, 59.99, 117.8),
    vec4(964.37, -596.16, 58.9, 73.46),
    vec4(1130.72, -963.65, 46.27, 17.76),
    vec4(500.62, -1697.04, 28.79, 143.77),
    vec4(514.33, -1780.87, 27.91, 91.12),
    vec4(399.28, -1865.08, 25.72, 312.69),
    vec4(362.31, -1987.22, 23.23, 340.86),
    vec4(365.26, -2064.69, 20.74, 49.91),
    vec4(321.91, -2100.11, 17.24, 29.05),
    vec4(114.44, -1961.22, 20.33, 20.36),
    vec4(23.15, -1896.94, 21.97, 319.63),
    vec4(-141.9, -1697.57, 29.77, 142.32),
    vec4(-173.81, -1562.14, 34.36, 257.73),
    vec4(-170.65, -1449.6, 30.64, 56.32),
    vec4(-210.4, -1292.32, 30.3, 157.87),
    vec4(87.61, -1294.27, 28.2, 125.09),
    vec4(116.43, -1089.09, 28.23, 4.2),
    vec4(259.77, -783.18, 29.51, 72.78),
    vec4(347.78, -745.15, 28.27, 71.73),
}

-- Customer Models
Config.CustomerModels = {
    `a_m_m_business_01`,
    `a_m_m_eastsa_01`,
    `a_f_y_business_01`,
    `a_f_y_hipster_02`,
    `a_m_y_hipster_01`,
}

Config.CustomerScenario = 'WORLD_HUMAN_STAND_IMPATIENT'

return Config