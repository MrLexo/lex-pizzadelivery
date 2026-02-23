🍕 Pizza Delivery for FiveM

## 📌 Overview

**Pizza Delivery** is a lightweight activity built for QBCore servers.

Players start a delivery run, receive a randomly generated route,
collect pizzas from their faggio, and complete drop offs across the
map.

It does **not** require a specific job role and works as a standalone
activity.

------------------------------------------------------------------------

## 📸 Preview

![Pizza Delivery](https://your-image-link-here.png)

------------------------------------------------------------------------

## 🛠️ Features

-   🛵 **Delivery vehicle**

    -   Configurable vehicle model
    -   Optional rear pizza box prop attachment (use on 'faggio')

-   📍 **Random Delivery Routes**

    -   The player will not be directed to go to a house already completed
    -   There are plenty of spots to keep it engaging and fun

-   📦 **Carry System**

    -   Player take the pizza from vehicle
    -   Animated carry prop system

-   🗺️ **Blip + Toute Guidance**

    -   GPS route enabled
    -   Removal on completion

-   📊 **Live Delivery counter**

    -   Displays: `Deliveries: X / Total`

-   🔔 **ox_lib Notifications**

-   🎯 **ox_target / qb-target support**

    -   Automatically detects and uses available target system

-   🧼 **Full cleanup**

    -   Vehicle removed on finish or disconnect
    -   Props safely detached
    -   Zones cleaned properly
    
------------------------------------------------------------------------

## 📂 Installation

1.  Download or clone this repository.
2.  Place it inside your FiveM `resources` folder.
3.  Ensure dependencies are started before this script.
4.  Add to your `server.cfg`:

``` cfg
ensure ox_lib
ensure qb-core
ensure lex-pizzadelivery
```

------------------------------------------------------------------------

## 📝 License

Free to use and modify for your server.\
Attribution appreciated but not required.
