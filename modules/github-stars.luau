-- Config
local repo = "agrevster/pocketbase-kotlin"

-- code
local star_count =
  json.load(http.fetch(`https://api.github.com/repos/{repo}`, http.methods.GET, nil, nil, nil).body).stargazers_count

local module = niceclock
  .modulebuilder("github-stars", 20, { "github", "star" }, {})
  :image({ x = 0, y = 0 }, "github")
  :image({ x = 47, y = 0 }, "star")
  :horizontalscrollingtext(
    { x = 64, y = 23 },
    niceclock.fonts.Font5x8,
    repo,
    { r = 255, g = 255, b = 255 },
    0,
    -1,
    { loop = true, speed = 4, duration = 20 }
  )

if #tostring(star_count) >= 4 then
  module = module:text({ x = 22, y = 9 }, niceclock.fonts.Font5x8, tostring(star_count), { r = 255, g = 255, b = 255 })
else
  module = module:text({ x = 24, y = 5 }, niceclock.fonts.Font7x14, tostring(star_count), { r = 255, g = 255, b = 255 })
end

return module
