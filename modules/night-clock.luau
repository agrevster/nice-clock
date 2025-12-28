function random_color(): Color
  local colors: { Color } = {
    { r = 240, g = 248, b = 255 },
    { r = 219, g = 235, b = 255 },
    { r = 117, g = 147, b = 175 },
    { r = 255, g = 233, b = 159 },
  }
  return colors[math.random(1, #colors)]
end

function draw_star1(self: ClockModuleBuilder, pos: Pos, color: Color): ClockModuleBuilder
  return self
    :tile(pos, color)
    :tile({ x = pos.x + 1, y = pos.y }, color)
    :tile({ x = pos.x - 1, y = pos.y }, color)
    :tile({ x = pos.x, y = pos.y + 1 }, color)
    :tile({ x = pos.x, y = pos.y - 1 }, color)
end

function draw_star2(self: ClockModuleBuilder, pos: Pos, color: Color): ClockModuleBuilder
  return self
    :tile(pos, color)
    :tile({ x = pos.x + 1, y = pos.y + 1 }, color)
    :tile({ x = pos.x + 1, y = pos.y - 1 }, color)
    :tile({ x = pos.x - 1, y = pos.y + 1 }, color)
    :tile({ x = pos.x - 1, y = pos.y - 1 }, color)
end

function draw_star3(self: ClockModuleBuilder, pos: Pos, color: Color): ClockModuleBuilder
  return self
    :tile(pos, color)
    :tile({ x = pos.x + 2, y = pos.y }, color)
    :tile({ x = pos.x - 2, y = pos.y }, color)
    :tile({ x = pos.x, y = pos.y + 2 }, color)
    :tile({ x = pos.x, y = pos.y - 2 }, color)
end

function draw_star4(self: ClockModuleBuilder, pos: Pos, color: Color): ClockModuleBuilder
  return self
    :tile(pos, color)
    :tile({ x = pos.x, y = pos.y + 1 }, color)
    :tile({ x = pos.x, y = pos.y + 2 }, color)
    :tile({ x = pos.x, y = pos.y - 1 }, color)
    :tile({ x = pos.x, y = pos.y - 2 }, color)
    :tile({ x = pos.x + 1, y = pos.y }, color)
    :tile({ x = pos.x - 1, y = pos.y }, color)
end

function draw_star5(self: ClockModuleBuilder, pos: Pos, color: Color): ClockModuleBuilder
  return self
    :box({ x = pos.x - 1, y = pos.y - 1 }, 3, 3, true, color)
    :tile({ x = pos.x, y = pos.y + 2 }, color)
    :tile({ x = pos.x, y = pos.y - 2 }, color)
    :tile({ x = pos.x + 2, y = pos.y }, color)
    :tile({ x = pos.x - 2, y = pos.y }, color)
    -- Bottom right wing
    :tile({ x = pos.x + 2, y = pos.y + 2 }, color)
    :tile({ x = pos.x + 3, y = pos.y + 3 }, color)
    -- Top right wing
    :tile({ x = pos.x + 2, y = pos.y - 2 }, color)
    :tile({ x = pos.x + 3, y = pos.y - 3 }, color)
    -- Bottom left wing
    :tile({ x = pos.x - 2, y = pos.y - 2 }, color)
    :tile({ x = pos.x - 3, y = pos.y - 3 }, color)
    -- Top top right wing
    :tile({ x = pos.x - 2, y = pos.y + 2 }, color)
    :tile({ x = pos.x - 3, y = pos.y + 3 }, color)
end

local module = niceclock.modulebuilder("night-clock", 30, {}, {})

for i = 0, 8 do
  module = module:tile({ x = math.random(3, 60), y = math.random(10, 28) }, random_color())
end

for i = 0, 4 do
  module = draw_star1(module, { x = math.random(3, 60), y = math.random(10, 28) }, random_color())
end

for i = 0, 4 do
  module = draw_star2(module, { x = math.random(3, 60), y = math.random(10, 28) }, random_color())
end

for i = 0, 1 do
  module = draw_star3(module, { x = math.random(3, 60), y = math.random(10, 28) }, random_color())
end

for i = 0, 4 do
  module = draw_star4(module, { x = math.random(3, 60), y = math.random(10, 28) }, random_color())
end

module = draw_star5(module, { x = math.random(23, 60), y = math.random(4, 7) }, random_color())

--- Clock
local time = datetime.now("America/Chicago").time
module = module:text(
  { x = 1, y = 1 },
  niceclock.fonts.Font5x8,
  `{time.twelve_hour}:{time.padded_minute}`,
  { r = 238, g = 186, b = 11 }
)

return module

