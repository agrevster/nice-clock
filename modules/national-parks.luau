local park_data = json.load(json.read("parks.json") or "{}")

local park = park_data[math.random(1, #park_data)]

local park_name = park.name
local park_image = `./national-parks/{park.image}`
local park_states = `Park\nin\n{park.states:gsub(",", "\n")}`

local colors = {
  brown = {
    r = 111,
    g = 73,
    b = 48,
  },
  green = {
    r = 86,
    g = 144,
    b = 58,
  },
  green_dark = {
    r = 33,
    g = 58,
    b = 27,
  },
  black = {
    r = 0,
    g = 0,
    b = 0,
  },
  blue = {
    r = 153,
    g = 170,
    b = 186,
  },
}

local annimations: { CustomAnimation } = {
  -- Show image
  {
    component_indexes = { 0 },
    animation = { duration = 10, speed = 61, loop = false },
    states = {
      { timestamp = 0, text = "empty" },
      { timestamp = 10, text = park_image },
    },
  },
  -- Hide info
  {
    component_indexes = { 1, 2, 3, 4 },
    animation = { duration = 10, speed = 61, loop = false },
    states = {
      { timestamp = 0 },
      { timestamp = 10, color = colors.black },
    },
  },
  {
    component_indexes = { 5 },
    animation = { duration = 10, speed = 61, loop = false },
    states = {
      { timestamp = 0 },
      { timestamp = 10, color = colors.blue },
    },
  },
}

return niceclock
  .modulebuilder("national-parks", 20, { park_image }, annimations)
  :image({ x = 0, y = 0 }, "empty")
  :text({ x = 12, y = 2 }, niceclock.fonts.Font5x5, "National", colors.green)
  :text({ x = 17, y = 8 }, niceclock.fonts.Font5x5, "Parks", colors.brown)
  :box({ x = 10, y = 0 }, 43, 15, false, colors.green_dark)
  :horizontalscrollingtext(
    { x = 64, y = 20 },
    niceclock.fonts.Font5x8_2,
    park_name,
    colors.blue,
    0,
    -30,
    { loop = true, speed = 4, duration = 50 }
  )
  :wrappedtext({ x = 42, y = 0 }, niceclock.fonts.Font5x5, park_states, colors.black, 3)
