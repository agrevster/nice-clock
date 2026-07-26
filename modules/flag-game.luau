-- config
local colors = {
  text = { r = 230, g = 69, b = 83 },
  border = { r = 255, g = 255, b = 255 },
  light = { r = 209, g = 188, b = 130 },
}

local flags = json.load(json.read("flags.json") or "{}")

function distribute_lights(self: ClockModuleBuilder): ClockModuleBuilder
  local builder = self
  for y = 0, 31, 1 do
    if y == 0 or y == 31 then
      for x = 0, 63, 1 do
        if x % 4 == 0 then
          builder = builder:tile({ x = x, y = y }, colors.light)
        end
      end
    else
      if y % 4 == 0 then
        builder = builder:tile({ x = 0, y = y }, colors.light)
        builder = builder:tile({ x = 63, y = y }, colors.light)
      end
    end
  end
  return builder
end

function range(start: number, finish: number): { number }
  local array = {}
  for i = start, finish do
    table.insert(array, i)
  end
  return array
end

function create_light_flash_animation(count: number, default_color: Color): { CustomAnimationState }
  local animations: { CustomAnimationState } = {}
  for i in range(0, count + 1) do
    local color = default_color
    if i % 2 == 0 then
      color = colors.light
    end
    if i <= count then
      table.insert(animations, { timestamp = i, color = color })
    else
      table.insert(animations, { timestamp = i, color = { r = 0, g = 0, b = 0 } })
    end
  end
  return animations
end

local flag = flags[math.random(1, #flags)]
local flag_image_name = `flags/{flag.code}`

local animations: { CustomAnimation } = {
  --Blink lights
  {
    component_indexes = range(6, 51),
    animation = {
      loop = false,
      speed = 12,
      duration = 20,
    },
    states = create_light_flash_animation(19, colors.border),
  },
  --Blink text
  {
    component_indexes = { 0 },
    animation = {
      loop = false,
      speed = 10,
      duration = 24,
    },
    states = create_light_flash_animation(23, colors.text),
  },
  {
    component_indexes = { 1 },
    animation = {
      loop = false,
      speed = 12,
      duration = 20,
    },
    states = create_light_flash_animation(20, colors.text),
  },
  {
    component_indexes = { 2 },
    animation = {
      loop = false,
      speed = 8,
      duration = 30,
    },
    states = create_light_flash_animation(30, colors.text),
  },
  --End blink text
  --Make the boarder disappear
  {
    component_indexes = { 3 },
    animation = {
      loop = false,
      speed = 12,
      duration = 20,
    },
    states = { { timestamp = 0 }, { timestamp = 20, color = { r = 0, g = 0, b = 0 } } },
  },
  -- Make flag appear
  {
    component_indexes = { 5 },
    animation = {
      loop = false,
      speed = 12,
      duration = 110,
    },
    states = { { timestamp = 0 }, { timestamp = 20, text = flag_image_name }, { timestamp = 109, text = "empty" } },
  },
  --Make answer appear
  {
    component_indexes = { 4 },
    animation = {
      loop = false,
      speed = 12,
      duration = 111,
    },
    states = { { timestamp = 0 }, { timestamp = 110, color = colors.text } },
  },
}

local builder = niceclock
  .modulebuilder("Flag Game", 30, { flag_image_name }, animations)
  :text({ x = 22, y = 3 }, niceclock.fonts.Font5x8_2, "Fun", colors.text)
  :text({ x = 22, y = 12 }, niceclock.fonts.Font5x8_2, "With", colors.text)
  :text({ x = 22, y = 20 }, niceclock.fonts.Font5x8_2, "Flags", colors.text)
  :box({ x = 0, y = 0 }, 64, 32, false, colors.border)
  :wrappedtext({ x = 0, y = 0 }, niceclock.fonts.Font5x8, `The flag was\n {flag.name}`, { r = 0, g = 0, b = 0 }, 1)
  :image({ x = 0, y = 0 }, "empty")

builder = distribute_lights(builder)
return builder
