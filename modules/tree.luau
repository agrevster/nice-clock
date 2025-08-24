local test_animation: CustomAnimation = {
  component_indexes = { 1, 2, 3, 4 },
  animation = { duration = 30, loop = true, speed = 3 },
  states = {
    { timestamp = 00, color = { r = 255, g = 0, b = 0 } },
    { timestamp = 10, color = { r = 0, g = 0, b = 255 } },
    { timestamp = 20, color = { r = 0, g = 255, b = 0 } },
  },
}
local test = niceclock
  .modulebuilder("Test module", 30, { "tree" }, { test_animation })
  :image({ x = 0, y = 0 }, "tree")
  :tile({ x = 0, y = 10 }, { r = 255, g = 0, b = 0 })
  :tile({ x = 2, y = 6 }, { r = 255, g = 0, b = 0 })
  :tile({ x = 6, y = 2 }, { r = 255, g = 0, b = 0 })
  :tile({ x = 9, y = 8 }, { r = 255, g = 0, b = 0 })

return test
