local now = datetime.now("America/Chicago")
local epoch = math.floor(datetime.utcnow().epoch)
local module_time = 10

function create_epoch_advance_states(): { CustomAnimationState }
  local state_table: { CustomAnimationState } = {}
  for i = 0, module_time + 1, 1 do
    table.insert(state_table, { timestamp = i, text = `{epoch + i}` })
  end
  return state_table
end

function padded_second(time: Time): string
  local second = time.second
  return if second < 10 then `0{second}` else `{second}`
end

function create_second_advance_states(): { CustomAnimationState }
  local state_table: { CustomAnimationState } = {}
  for i = 0, module_time + 1, 1 do
    local updated_time = now:shift({ seconds = i })
    table.insert(state_table, {
      timestamp = i,
      text = `{updated_time.time.hour}:{updated_time.time.padded_minute} {padded_second(updated_time.time)}`,
    })
  end
  return state_table
end

local epoch_advance_animation: CustomAnimation = {
  component_indexes = { 3 },
  animation = { loop = false, speed = 61, duration = module_time },
  states = create_epoch_advance_states(),
}

local time_advance_animation: CustomAnimation = {
  component_indexes = { 4 },
  animation = { loop = false, speed = 61, duration = module_time },
  states = create_second_advance_states(),
}

local green: Color = { r = 0, g = 255, b = 0 }
local white: Color = { r = 255, g = 255, b = 255 }

return niceclock
  .modulebuilder("epoch clock", module_time, {}, { epoch_advance_animation, time_advance_animation })
  :box({ x = 0, y = 0 }, 64, 10, false, green)
  :box({ x = 0, y = 21 }, 64, 1, false, white)
  :text({ x = 7, y = 1 }, niceclock.fonts.Font5x8, "Unix Epoch", white)
  -- To the developer maintaining this in 2286... You're going to need to decrease the font size
  :text(
    { x = 0, y = 9 },
    niceclock.fonts.Font6x12,
    `{epoch}`,
    white
  )
  :text(
    { x = 0, y = 21 },
    niceclock.fonts.Font6x12,
    `{now.time.hour}:{now.time.padded_minute} {padded_second(now.time)}`,
    white
  )
