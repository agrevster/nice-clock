local white: Color = { r = 255, g = 255, b = 255 }

local fact = json.load(http.fetch("https://catfact.ninja/fact", http.methods.GET, nil, nil, nil).body).fact

local module_time = #fact // 4
print(module_time)

return niceclock
  .modulebuilder("cat-fact", module_time, { "cat" }, {})
  :box({ x = 17, y = 0 }, 45, 10, false, white)
  :text({ x = 20, y = 1 }, niceclock.fonts.Font5x8, "Cat Fact", white)
  :image({ x = 2, y = 0 }, "cat")
  :horizontalscrollingtext(
    { x = 64, y = 15 },
    niceclock.fonts.Font7x14,
    fact,
    white,
    0,
    -60,
    { loop = false, speed = 2, duration = (#fact * 7) + 60 }
  )
