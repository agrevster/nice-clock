# Nice Clock Luau
> UPDATED: 2025-11-13


##### Contents
[http](#http) - [json](#json) - [datetime](#datetime) - [global](#global)

## `http` library
- `http.fetch`
  ```lua
    function http.fetch(url: string, method: http.Methods, body: string?, content_type: string?, authorization: string?): http.Response
    ```
    - Makes an HTTP request to the given `url` with the given `method`. Optionally a `body`, can be supplied as well as the `content_type` of the body and an `authorization` header. This function returns an `http.Response` table. *In some cases including but not limited to a lack of connection, an error will be thrown by this method.* 
- `http.Methods`
    ```lua
    http.Methods = {
        GET = "GET",
        HEAD = "HEAD",
        POST = "POST",
        PUT = "PUT",
        DELETE = "DELETE",
        CONNECT = "CONNECT",
        OPTIONS = "OPTIONS",
        TRACE = "TRACE",
        PATCH = "PATCH",
    }
    ```
    - A table containing HTTP methods used in creating an `http.fetch` request.
- `http.Response`
    ```lua
    http.Response = {
        body: string,
        status: number
    }
    ```
    - The table returned from an HTTP request created with `http.fetch`. `body` contains the body of the response and `status` contains the status code.


## `json` library
> [!WARNING] 
> Due to the way Luau handles null (nil) values, they will be ignored by all clock JSON methods.
- `json.load`
  ```lua
    function json.load(str: string): any
    ```
    - Converts a giving JSON `str` into a Luau table. If the given `str` is not valid JSON an error will be thrown. 
- `json.dump`
  ```lua
    function json.dump(obj: any): string
    ```
    - Converts a given Luau table (`obj`) to a JSON string. If values in the table cannot traditionally be represented as JSON like: `userdata`, `functions` or `vectors` an error will be thrown.


## `datetime` library
- `datetime.utcnow`
  ```lua
    function datetime.utcnow(): datetime.Datetime
    ```
    - Returns the current time in UTC.
- `datetime.now`
  ```lua
    function datetime.now(timezone: string): datetime.Datetime
    ```
    - Returns the current time in the given `timezone`. A list of valid timezone can be found [here](https://github.com/frmdstryr/zig-datetime/blob/master/src/timezones.zig).
- `datetime.fromiso`
  ```lua
    function datetime.fromiso(iso8601_timestamp: string): datetime.Datetime
    ```
    - Returns a `Datetime` from a given `iso8601_timestamp`.
- `datetime.new`
  ```lua
    function datetime.new(year: number, month: number, day: number, hour: number, minute: number, second: number, timezone: string): datetime.Datetime
    ```
    - Returns a new `Datetime` from a given arguments.
- `datetime.Datetime`
    ```lua
    datetime.Datetime = {
        date: Date,
        time: Time,
        -- The ISO 8061 timestamp of the datetime.
        iso: string,
        -- The unix timestamp for datetime.
        epoch: number,
        shift: (self: Datetime, delta: DatetimeDelta) -> Datetime,
        sub: (self: Datetime, datetime: Datetime) -> DatetimeDelta,
        shiftzone: (self: Datetime, zone: string) -> Datetime,
    }
    ```

- `datetime.Datetime.shiftzone`
    ```lua
    function datetime.Datetime.shiftzone(self: Datetime, zone: string): datetime.Datetime
    ```
    - Returns `self` shifted to the given `zone` timezone. A list of valid timezone can be found [here](https://github.com/frmdstryr/zig-datetime/blob/master/src/timezones.zig).

- `datetime.Datetime.sub`
    ```lua
    function datetime.Datetime.sub(self: Datetime, datetime: Datetime): datetime.DatetimeDelta
    ```
    - Returns a `DatetimeDelta` with `self` subtracted from `Datetime`. 

- `datetime.Datetime.shift`
    ```lua
    function datetime.Datetime.shift(self: Datetime, delta: DatetimeDelta): datetime.Datetime
    ```
    - Returns `self` shifted ahead or behind by the given `delta`.
- `datetime.Date`
    ```lua
    datetime.Date = {
        year: number,
        month: number,
        day: number,
        day_name: string,
        month_name: string,
        day_of_week: number,
        day_of_year: number,
        week_of_year: number,
    }
    ```
- `datetime.Time`
    ```lua
    datetime.Time = {
        hour: number,
        minute: number,
        second: number,
        -- AM or PM
        am_pm: string,
        -- The 12 hour representation of the time
        twelve_hour: number,
        -- The string representation of the minute 5 -> 05 
        padded_minute: string,
    }
    ```
- `datetime.Delta`
    ```lua 
    datetime.DatetimeDelta = {
        years: number?,
        days: number?,
        seconds: number?,
    }
    ```

## `global` additions
- `error`
    ```lua
    function error(message: string)
    ```
    - Throws a luau error halting executing of the current module.
- `getenv`
    ```lua
    function getenv(key: str): str?
    ```
    - Gets an environment variable with the given `key`. If it does not exist returns `nil`.

## `niceclock` library
- **This is the main library used to create modules**
### Creating modules
- `niceclock.modulebuilder`
    ```lua
    function niceclock.modulebuilder(name: string, timelimit: number, imagenames: {string}, animations: {CustomAnimation}): niceclock.ClockModuleBuilder
    ```
    -  Used to create a `niceclock.ClockModuleBuilder` with a given `name`, that lasts for `timelimit` seconds, loads all images in `imagenames` for use, and runs all `animations` every screen update. **All clock modules must return** this to be valid. 
    - Once the `ClockModuleBuilder` has been created, you can use its methods to add components to the module.
- `niceclock.ClockModuleBuilder`
    ```lua
    niceclock.ClockModuleBuilder = {
        -- The name of the clock module
        name: string,
        -- How many seconds the module appears on the screen before the clock switches to another module
        timelimit: number,
        -- The list of components that make up the module
        components: {ClockComponent},
        -- The list of images that are loaded by the module
        imagenames: {string},
        -- THe list of custom animations that the module runs every update.
        animations: {CustomAnimation},
        -- Component creation functions
        tile: (self: ClockModuleBuilder, pos: Pos, color: Color) -> ClockModuleBuilder,
        box: (self: ClockModuleBuilder, pos: Pos, width: number, height: number, fill_inside: boolean, color: Color) -> ClockModuleBuilder,
        circle: (self: ClockModuleBuilder, pos: Pos, radius: number, outline_thickness: number, color: Color) -> ClockModuleBuilder,
        image: (self: ClockModuleBuilder, pos: Pos, image_name: string) -> ClockModuleBuilder,
        char: (self: ClockModuleBuilder, pos: Pos, font: string, char: string, color: Color) -> ClockModuleBuilder,
        text: (self: ClockModuleBuilder, pos: Pos, font: string, text: string, color: Color)-> ClockModuleBuilder,
        wrappedtext: (self: ClockModuleBuilder, pos: Pos, font: string, text: string, color: Color, line_spacing: number) -> ClockModuleBuilder,
        horizontalscrollingtext: (self: ClockModuleBuilder, pos: Pos, font: string, text: string, color: Color, cutof_x: number, text_pos: number, animation: Animation) -> ClockModuleBuilder,
        verticalscrollingtext: (self: ClockModuleBuilder, pos: Pos, width: number, height: number, font: string, text: string, color: Color, text_pos: number,line_spacing: number, animation: Animation) -> ClockModuleBuilder,
    }
    ```
    - Holds all the data contained within a clock module.
    - **Each module must return a table of this type to be valid.** The best way to do this is to create a builder with the `niceclock.modulebuilder` function.
- `ClockModuleBuilder.tile`
    ```lua
    function tile(self: ClockModuleBuilder, pos: Pos, color: Color): niceclock.ClockModuleBuilder,
    ```
    - Used to create a single pixel at a given `pos` and of a given `color` as a component on the clock.
    - ![Tile image](./.github/assets/tile.png) 
- `ClockModuleBuilder.box`
    ```lua
    function box(self: ClockModuleBuilder, pos: Pos, width: number, height: number, fill_inside: boolean, color: Color): niceclock.ClockModuleBuilder,
    ```
    - Used to create a box of color `color` at the given `pos` with the given `width` and `height`. `fill_inside` determines whether or not to fill the inside of the box. 
    - ![Box image](./.github/assets/box.png) 

- `ClockModuleBuilder.circle`
    ```lua
    function circle(self: ClockModuleBuilder, pos: Pos, radius: number, outline_thickness: number, color: Color): niceclock.ClockModuleBuilder,
    ```
    - Used to create a circle of color `color` at the given `pos` with the given `radius` and `online_thickness`.
    - ![Circle image](./.github/assets/circle.png) 
- `ClockModuleBuilder.image`
    ```lua
    function image(self: ClockModuleBuilder, pos: Pos, image_name: string): niceclock.ClockModuleBuilder,
    ```
    - Used to draw a given `image` on a screen at the given `pos`. The image must be loaded via `imagenames`. `image_name` should not contains an extension.
    - ![Image image](./.github/assets/image.png) 
- `ClockModuleBuilder.char`
    ```lua
    function char(self: ClockModuleBuilder, pos: Pos, font: string, char: string, color: Color): niceclock.ClockModuleBuilder,
    ```
    - Used to draw a single `char` of the given `color` with the given `font` *(`NiceClock.Font`)* at the given `pos`.
> [!WARNING]
> Char should only be of len 1!
    - ![Char image](./.github/assets/char.png) 
- `ClockModuleBuilder.text`
    ```lua
    function text(self: ClockModuleBuilder, pos: Pos, font: string, text: string, color: Color): niceclock.ClockModuleBuilder,
    ```
    - Used to draw the given `text` of the given `color` with the given `font` *(`NiceClock.Font`)* at the given `pos`. **Overflowing text will cause an error. If you have overflowing text use a `wrappedtext` component.** 
    - ![Text image](./.github/assets/text.png) 
- `ClockModuleBuilder.wrappedtext`
    ```lua
    function wrappedtext(self: ClockModuleBuilder, pos: Pos, font: string, text: string, color: Color, line_spacing: number): niceclock.ClockModuleBuilder,
    ```
    - Used to draw the given `text` of the given `color` with the given `font` *(`NiceClock.Font`)* at the given `pos`. This time if any text goes over the screen, it wraps to the next line. `line_spacing` pixels are added to the y after every wrap to a newline.
    - ![Wrapped text image](./.github/assets/wrappedtext.png) 
- `ClockModuleBuilder.horizontalscrollingtext`
    ```lua
    function horizontalscrollingtext(self: ClockModuleBuilder, pos: Pos, font: string, text: string, color: Color, cutof_x: number, text_pos: number, animation: Animation): niceclock.ClockModuleBuilder,
    ```
    - Used to draw the given `text` of the given `color` with the given `font` *(`NiceClock.Font`)* at the given `pos`. This time the text scrolls horizontally (right to left) instead of overflowing. `cutof_x` is the x position where the text starts (on the right) and `pox.x` is where the text ends (on the left). `text_pos` is the pos that the animation starts at, where `0` represents the first letter in `text` being at x position `0`.
    - ![horizontal scrolling text gif](./.github/assets/horizontalscrollingtext.gif) 
- `ClockModuleBuilder.verticalscrollingtext`
    ```lua
    function verticalscrollingtext(self: ClockModuleBuilder, pos: Pos, width: number, height: number, font: string, text: string, color: Color, text_pos: number,line_spacing: number, animation: Animation): niceclock.ClockModuleBuilder,
    ```
    - Used to draw the given `text` of the given `color` with the given `font` *(`NiceClock.Font`)* at the given `pos`. This time the text scrolls vertically (bottom to top) instead of overflowing. `width` is the height of the scrolling window, and `height` is the height. `text_pos` is the pos that the animation starts at, where `0` represents the first line in `text` being at the top of the box.
    - ![vertical scrolling text gif](./.github/assets/verticalscrollingtext.gif) 
- `niceclock.ClockComponent`
    ```lua
    niceclock.ClockComponent = {
        type: number,
        props: {}
    }
    ```
    - Used internally to pass components to Zig. (*You shouldn't ever have to create this manually*) `type` is the enum to int representation of the component type. `props` contains all the component data required to make the underlying Zig struct.

- `niceclock.Color`
    ```lua
    niceclock.Color = {
        b: number,
        g: number,
        r: number,
    }
    ```
    - An RGB color.

- `niceclock.Pos`
    ```lua
    niceclock.Pos = {
        y: number,
        x: number,
    }
    ```
    - Represents the `x` and `y` position of a component.

### Animations

- `niceclock.CustomAnimation`
    ```lua
    niceclock.CustomAnimation = {
        animation: Animation,
        component_indexes: {number},
        states: {CustomAnimationState},
    }
    ```
    - Creates a custom animation for every component in `component_indexes` (*The index of each component you want to be affected by the animation*).  `animation` holds animation config. `states` is the state of all components at a given timestamp. You only need to set this when you want the state to change.
- `niceclock.CustomAnimationState`
    ```lua
    niceclock.CustomAnimationState = {
        timestamp: number,
        color: Color?,
        pos: Pos?,
        text: string?,
    }
    ```
    - Holds custom animation data. `timestamp` is the timestamp where the given state is applied to all components in the animation. All `?` fields are optional and can be `nil`. `color` is the color of all components with a color. Setting `pos` sets the position of all positionable components. `text` changes the text content of all text components in the animations.

- `niceclock.Animation`
    ```lua
    niceclock.Animation = {
        duration: number,
        loop: boolean,
        speed: number,
    }
    ```
    - Used to store animation properties. The greater the `speed` the slower the animation. `duration` is the amount of frames in the animation. `loop` means when the animation reaches the final frame it starts back at `frame 0`.

- `niceclock.Fonts`
    ```lua
    niceclock.Fonts = {
        Font5x8 = "Font5x8",
        Font5x8_2 = "Font5x8_2",
        Font6x12 = "Font6x12",
        Font6x13 = "Font6x13",
        Font7x13 = "Font7x13",
        Font7x14 = "Font7x14",
        Font12x24 = "Font12x24",
    }
    ```
    - Represents all of the fonts loaded in the clock.

