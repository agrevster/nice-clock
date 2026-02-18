local url = "https://site.web.api.espn.com/apis/site/v2/olympics/winter/2026/medals"
local data = json.load(http.fetch(url, http.methods.GET, nil, nil, nil).body)

local leaders = data.leaders.total
local rankings: { { name: string, total: number } } = {}

for i in leaders do
  local leader = leaders[i]
  table.insert(rankings, { name = leader.name, total = leader.medalStandings.totalMedals })
end

function abbreviate(name: string): string
  -- We abbreviate names with more than 12 chars
  if #name > 12 then
    local result = ""
    for _, item in ipairs(name:split(" ")) do
      local first_char = item:sub(1, 1)
      local ord = first_char:byte()
      if ord >= 65 and ord <= 90 then
        result = `{result}{item:sub(1, 1)}.`
      end
    end
    return result
  else
    return name
  end
end

local colors = {
  { r = 254, g = 225, b = 1 }, -- Gold
  { r = 215, g = 215, b = 215 }, -- Silver
  { r = 167, g = 112, b = 68 }, -- Bronze
  white = { r = 255, g = 255, b = 255 },
  blue = { r = 0, g = 90, b = 155 },
}

local module = niceclock
  .modulebuilder("Olympic Medals Top", 20, {}, {})
  :text({ x = 0, y = 0 }, niceclock.fonts.Font5x8_2, "Top Medals:", colors.blue)

for i in rankings do
  local item = rankings[i]
  module = module
    :text({ x = 0, y = i * 8 }, niceclock.fonts.Font5x8, `{i}:`, colors[i])
    :text({ x = 13, y = i * 8 }, niceclock.fonts.Font5x8, `{abbreviate(item.name)} {item.total}`, colors.white)
end

return module
