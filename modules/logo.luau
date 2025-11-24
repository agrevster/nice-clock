local colors: { Color } = {
  { r = 220, g = 138, b = 120 },
  { r = 221, g = 120, b = 120 },
  { r = 234, g = 118, b = 203 },
  { r = 136, g = 57, b = 239 },
  { r = 210, g = 15, b = 57 },
  { r = 230, g = 69, b = 83 },
  { r = 254, g = 100, b = 11 },
  { r = 223, g = 142, b = 29 },
  { r = 64, g = 160, b = 43 },
  { r = 23, g = 146, b = 153 },
  { r = 4, g = 165, b = 229 },
  { r = 32, g = 159, b = 181 },
  { r = 30, g = 102, b = 245 },
  { r = 114, g = 135, b = 253 },
}

function circular_index<T>(arr: { T }, index: number): T
  return arr[((index - 1) % #arr) + 1]
end

function make_bouncy_letter(index: number): CustomAnimation
  local states: { CustomAnimationState } = {}
  local bounce_floor: number = 8
  local bounce_cel: number = 0

  local x_pos = (((index + 1) * 6) - 6) + 2

  for i = bounce_cel, bounce_floor do
    states[i + 1] = { timestamp = i + index, pos = { x = x_pos, y = i } }
    states[i + 1 + bounce_floor] = { timestamp = i + index + bounce_floor, pos = { x = x_pos, y = bounce_floor - i } }
  end

  return { states = states, component_indexes = { index }, animation = { speed = 7, loop = false, duration = 23 } }
end

function logo(builder: ClockModuleBuilder): ClockModuleBuilder
  local title = "Nice Clock"
  local starting_color = math.random(1, #colors)
  local component_count = 0

  -- Draw letters
  for i, char in ipairs(title:split("")) do
    builder = builder:char(
      { y = 0, x = ((i * 6) - 6) + 2 },
      niceclock.fonts.Font6x13,
      char,
      circular_index(colors, starting_color + i)
    )
    component_count += 1
    builder.animations[i] = make_bouncy_letter(i - 1)
  end

  -- Draw smile
  local smile_x = 29
  local smile_y = 22
  local invis: Color = { r = 0, g = 0, b = 0 }
  local smile_color = colors[starting_color]
  builder = builder:tile({ x = smile_x - 5, y = smile_y - 2 }, invis)
  builder = builder:tile({ x = smile_x - 4, y = smile_y - 1 }, invis)
  for i = smile_x - 3, smile_x + 3 do
    builder = builder:tile({ x = i, y = smile_y }, invis)
  end
  builder = builder:tile({ x = smile_x + 4, y = smile_y - 1 }, invis)
  builder = builder:tile({ x = smile_x + 5, y = smile_y - 2 }, invis)

  -- Eyes
  builder = builder:tile({ x = smile_x - 2, y = smile_y - 6 }, invis)
  builder = builder:tile({ x = smile_x + 2, y = smile_y - 6 }, invis)

  -- Animate smile
  for i = component_count, component_count + 10 do
    builder.animations[i + 1] = {
      component_indexes = { i },
      animation = { loop = false, duration = 40, speed = 6 },
      states = { { timestamp = 0, color = invis }, { timestamp = (21 + i), color = smile_color } },
    }
  end

  -- Animate eyes
  builder.animations[component_count + 12] = {
    component_indexes = { component_count + 11 },
    animation = { loop = false, duration = 50, speed = 6 },
    states = { { timestamp = 0, color = invis }, { timestamp = 43, color = smile_color } },
  }
  -- Wink animation
  builder.animations[component_count + 13] = {
    component_indexes = { component_count + 12 },
    animation = { loop = false, duration = 57, speed = 6 },
    states = {
      { timestamp = 0, color = invis },
      { timestamp = 43, color = smile_color },
      { timestamp = 50, color = invis },
      { timestamp = 57, color = smile_color },
    },
  }

  return builder
end
return logo(niceclock.modulebuilder("nice-clock logo", 10, {}, {}))
