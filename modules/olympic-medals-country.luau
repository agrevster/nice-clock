local url = "http://sports.core.api.espn.com/v2/olympics/winter/2026/countries/79"
local data = json.load(http.fetch(url, http.methods.GET, nil, nil, nil).body)

local medals: { number } = {
  data.medalStandings.goldMedalCount,
  data.medalStandings.silverMedalCount,
  data.medalStandings.bronzeMedalCount,
}

local colors = {
  { r = 254, g = 225, b = 1 }, -- Gold
  { r = 215, g = 215, b = 215 }, -- Silver
  { r = 167, g = 112, b = 68 }, -- Bronze
  white = { r = 255, g = 255, b = 255 },
  blue = { r = 0, g = 90, b = 155 },
}

local module = niceclock
  .modulebuilder("Olympic Medals country", 20, {}, {})
  :text({ x = 0, y = 0 }, niceclock.fonts.Font5x8_2, "USA Medals:", colors.blue)

for i in medals do
  module = module
    :circle({ x = 5, y = (i * 8) + 4 }, 4, 4, colors[i])
    :text({ x = 11, y = i * 8 }, niceclock.fonts.Font5x8, `{medals[i]}`, colors[i])
end

return module
