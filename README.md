# Nice Clock
> Turn your RaspberryPi into a modular smart clock.

**Note: this is designed for 32x64 pixel Led Matrices**

[installation](#installation-and-usage) - [modules](#modules) - [config](#config) - [simulator](#simulator) 

![Clock Startup Logo gif](./.github/assets/logo.gif) 
*Image rendered in clock simulator*


## Installation and usage
*For this guide I am using [Alpine Linux (RaspberryPi version)](https://wiki.alpinelinux.org/wiki/Raspberry_Pi) rather than Raspbian, this is because Alpine is more lightweight therefore you don't have to worry as much about optimization and removing unnecessary services.*
1. Setup RaspberryPi and ensure that it is connected to the internet.
2. Install dependencies `apk add git curl sdl2-dev python3 zig`
3. Clone this repo (be sure to use this command so that sub modules are cloned too) `git clone --recurse-submodules https://github.com/agrevster/nice-clock.git`
    - I suggest cloning to `/opt/nice-clock`
4. Edit `/boot/cmdline.txt` to allow for the clock driver to access the GPIO.
    - Add the following to the end of `/boot/cmdline.txt`. This allows the clock driver to interact with system memory so it can work with the GPIO.
    - >iomem=relaxed 
5. Connect the led matrix to the PI's GPIO. 
    - I used [this](https://github.com/hzeller/rpi-rgb-led-matrix/blob/master/wiring.md) guide for wiring. 
    - You don't need to worry about chaining.
    - This project uses [hzeller's RGB led matrix API](https://github.com/hzeller/rpi-rgb-led-matrix/tree/master) to control the led matrix for the clock, check out their repository for wiring and connection instructions.
6. Secure your PI
7. Build the source code `zig build -Drelease=true -Dclock-target=hardware`
8. Test the clock by running `./zig-out/bin/nice-clock-hardware`
    - This should display a demo module containing each component.
    - If this step fails check logs and your hardware connection.
    - I have had issues with the hardware mapping of some displays. If you don't want to worry about wiring, Adafruit has a [hat](https://www.adafruit.com/product/3211) that can be used. It also powers the PI which is cool.
9. Make some [modules](#modules)
10. [Configure your clock](#config)
11. Test the modules with the [simulator](#simulator)
12. You can run the clock on the PI with the `nice-clock-hardware` executable.
13. Some of the modules I made require access to custom APIs found in `./scripts/`. If you use them, be sure to start their servers.

## Modules
The content the clock displays is called a `module`. While most of the clock's code is written in Zig, modules are created with [Luau](https://luau.org/). Luau is a sandboxed version of [Lua](https://www.lua.org/) used primarily by Roblox. Luau allows for the easy creation of custom modules without the hassle that is manually managing memory. Each module is made up of a series of `components` examples of `components` include text, boxes and even images. The clock will look for modules in `(CWD)/modules/*`, it is recommended to check out the existing modules for examples. Modules will check for assets in `(CWD)/assets`. The current assets are `fonts` and `images`, more asset types will be added at a later date. 

#### Asset types:
*Note: modules can access any file in assets regardless of directory. This means that you can create sub-directories for organizing images and fonts.*

**Modules cannot access files outside of the assets directory!**

- `fonts` - `assets/fonts` (fonts in the [BDF](https://en.wikipedia.org/wiki/Glyph_Bitmap_Distribution_Format) format)
- `images` - `assets/images` (images stored in the [PPM format (P6)](https://netpbm.sourceforge.net/doc/ppm.html). I use [GIMP](https://www.gimp.org/) to convert and work with PPMs. *I am sure there are other great tools out there.*)

### Creating modules
I highly recommend using [Luau LSP](https://github.com/JohnnyMorganz/luau-lsp) for Luau code completion and a syntax highlighting plugin. Adding support for the clock's custom luau functions is as simple as adding `nice-clock.d.luau` to Lusu LSP's definitions *(Check our their README for a guide on how to do this)*. 


#### Module creation steps
1. Create a file with a unique name ending in `luau` inside the `./modules` directory.
2. Create a `niceclock.ModuleBuilder` table with `niceclock.modulebuilder` and return it.
```lua
return niceclock
  .modulebuilder("MODULE NAME", 30, {}, {})
-- Creates a module named MODULE NAME that appears for 30 seconds before another module is selected with no loaded images and no custom animations.
```
3. Add components with component methods.
```lua
return niceclock
  .modulebuilder("MODULE NAME", 30, {}, {})
  :text({ x = 0, y = 0 }, niceclock.fonts.Font5x8, "Test", { r = 255, g = 0, b = 0 })
```
- For a list of all modules and custom Luau methods used for the clock see [the clock's Luau docs](./luau-docs.md)
- Example modules can be found within the [./modules/](./modules/) directory.

## Config
In order to tell the Clock program which [modules](#module) to display you must modify the clock config file: `(CWD)/config.luau`. This file is used to determine which modules the clock should use, a key value store used by modules and the brightness of the hardware display. Every `5` module runs the clock rereads the config by running the `get_config` function in `config.luau`. The Luau state in the file is preserved across calls, meaning that you can utilize global variables in your config. All [custom luau libraries](./luau-docs.md) _(besides `niceclock`)_ are loaded in this file, meaning that making http requests is fair game!

Every `config.luau` file must contain a function named `get_config` that takes no parameters and returns a [`ClockConfig` table]().

##### Example Config
```lua
-- Global variables are A-OK!
-- The whole file is ovulated once when the clock starts.
count = 0
-- Required function (This is called when the config is reloaded)
function get_config(): ClockConfig
  count += 1
  local config: ClockConfig = {
    -- The brightness of the clock (This is not displayed on the simulator)
    brightness = 80,
    -- A key value store, which can be accessed by clock modules.
    config = {
        text = "Hello",
        num = count,
    },
    -- A list of modules that the clock should use.
    modules = { "logo", "clock", "flag-game" },
  }
  -- Must return a ClockConfig!
  return config
end
```

## Simulator
Most people don't want to test the modules they create on the clock hardware, so I created a simulator which can be run locally for testing clock modules. I have tested the simulator on Linux and Mac, but it probably works on Windows.

**Use instructions**:
1. Install dependencies:
    1. [SDL2 development library](https://wiki.libsdl.org/SDL2/Installation).
    2. [Zig `0.15.2`](https://ziglang.org/download/)
2. Clone this repository on your local machine. (be sure to use this command so that sub modules are cloned too) `git clone --recurse-submodules https://github.com/agrevster/nice-clock.git`
3. Build the simulator `zig build -Dclock-target=sim`.
4. The built binary will be located in `zig-out`. 
