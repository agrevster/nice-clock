# Nice Clock
> Turn your RaspberryPi into a modular smart clock.

**Note: this is designed for 32x64 pixel Led Matrices**

[installation](#installation) - [modules](#modules)

#### TODO: 
1. Add images/gifs to README
2. Setup testing
5. Secure installation prob make another user and give it access to mem.
---


## Installation
*For this guide I am using [Alpine Linux (RaspberryPi version)]() rather than Raspbian, this is because Alpine is more lightweight and so that you don't have to worry about optimization.*
1. Setup RaspberryPi and ensure that it is connected to the internet.
2. Install dependencies `apk add git curl sdl2-dev python3`
3. Clone this repo (be sure to use this command so that sub modules are cloned too) `git clone --recurse-submodules https://github.com/agrevster/nice-clock.git`
    - I suggest cloning to `/opt/nice-clock`
4. Edit `/boot/cmdline.txt` to allow for the clock driver to access the GPIO.
    - Add the following to the end of `/boot/cmdline.txt`. This allows the clock driver to interact with system memory so it can work with the GPIO.
    - >iomem=relaxed 
5. Secure your Pi
    - *(TODO)*
6. Build the source code `zig build -Drelease=true -Dclock-target=hardware`
7. Test the clock by running `./zig-out/bin/nice-clock-hardware ip`
    - This should display the IP address of the Pi on the led matrix. 
    - If this step fails check logs and your hardware connection.
8. Install the rc-service to manage the clock from openrc.
    - *(TODO)*
9. Make some [modules](#modules) and profit! 

## Modules
The content the clock displays is called a `module`. While most of the clock's code is written in Zig, modules are created with [Luau](https://luau.org/). Luau is a sandboxed version of [Lua](https://www.lua.org/) used primary by Roblox. Luau allows for the easy creation of custom modules without the hassle that is manually managing memory. Each module is made up of a series of `components` examples of `components` include text, boxes and even images. The clock will look for modules in `(CWD)/modules/*`, it is recommended to check out the existing modules for examples. Modules will check for assets in `(CWD)/assets`. The current assets are `fonts` and `images`, more asset types will be added at a later date. 

#### Asset types:
*Note: modules can access any file in assets regardless of directory. This means that you can create sub-directories for organizing images and fonts.*

**Modules cannot access files outside of the assets directory!**

- `fonts` - `assets/fonts` (fonts in the [BDF](https://en.wikipedia.org/wiki/Glyph_Bitmap_Distribution_Format) format)
- `images` - `assets/images` (images stored in the [PPM format (P6)](https://netpbm.sourceforge.net/doc/ppm.html). I use [GIMP](https://www.gimp.org/) to convert and work with PPMs. *I am sure there are other great tools out there.*)

### Creating modules
I highly recommend using [Luau LSP](https://github.com/JohnnyMorganz/luau-lsp) for Luau code completion and a syntax highlighting plugin. Adding support for the clock's custom luau functions is as simple as adding `nice-clock.d.luau` to Lusu LSP's definitions *(Check our their README for a guide on how to do this)*. 
