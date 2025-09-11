# Nice Clock
> Turn your RaspberryPi into a modular smart clock.

**Note: this is designed for 32x64 pixel Led Matrices**

[installation](#installation) - [modules](#modules)

#### TODO: 
1. Add images/gifs to README
2. Setup testing
3. Add links
4. List deps
5. Secure installation prob make another user and give it access to mem.
---


## Installation
*For this guide I am using [Alpine Linux (RaspberryPi version)]() rather than Raspbian, this is because Alpine is more lightweight and so that you don't have to worry about optimization.*
1. Setup RaspberryPi and ensure that it is connected to the internet. [(guide)]()
2. Install led matrix [(guide)]()
3. Install dependencies `apk add git curl`
4. Clone this repo (be sure to use this command so that sub modules are cloned too) `git clone`
    - I suggest cloning to `/opt/nice-clock`
5. Edit `/boot/cmdline.txt` to allow for the clock driver to access the GPIO.
6. Do permission stuff
7. Build the source code `zig build`
8. Test the clock by running `.zig-out/bin/nice-clock-hardware -- ip`
    - This should display the ip address of the pi on the led matrix. 
    - If this step fails check logs and your hardware connection.
9. Install the rc-service to manage the clock from openrc.
11. Make some modules and profit! 

> /boot/cmdline.txt iomem=relaxed 

## Modules
The content the clock displays is called a `module`. While most of the clock's code is written in Zig, modules are created with [Luau](). Luau is a sandboxed version of [Lua]() used primary by Roblox. Luau allows for the easy creation of custom modules without the hassle that is manually managing memory. Each module is made up of a series of `components` examples of `components` include text, boxes and even images. The clock will look for modules in `(Current DIR)/modules/*`, it is recommended to check out the existing modules for examples. Modules will check for assets in `(Current DIR)/assets`. The current assets are `fonts` and `images`, more asset types will be added at a later date. 

#### Asset types:
*Note: modules can access any file in assets regardless of directory. This means that you can create sub-directories for organizing images and fonts.*

**Modules cannot access files outside of the assets directory!**

- `fonts` - `assets/fonts` (fonts in the BDF format)
- `images` - `assets/images` (images stored in the [PPM format (P6)](). I use [GIMP]() to work with PPMs I am sure there are other tools out there.)

### Creating modules
I highly recommend using [Luau LSP]() for code completion and a syntax highlighting plugin for code readability. Adding support for the clock's custom luau functions is as simple as adding `nice-clock.d.luau` to Lusu LSP's definitions *(Check our their readme for a guide on how to do this)*. 

