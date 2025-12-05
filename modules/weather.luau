--- Config

local lat = getenv("NICE_CLOCK_WEATHER_LAT")
local lon = getenv("NICE_CLOCK_WEATHER_LON")

local colors = {
  white = { r = 255, g = 255, b = 255 },
  min = { r = 4, g = 165, b = 229 },
  max = { r = 221, g = 120, b = 120 },
}

--- Code

local url =
  `https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&daily=uv_index_clear_sky_max,temperature_2m_min,temperature_2m_max&current=weather_code,is_day,temperature_2m&timezone=America%2FChicago&forecast_days=1&timeformat=unixtime&wind_speed_unit=mph&temperature_unit=fahrenheit&precipitation_unit=inch`

local res = http.fetch(url, http.methods.GET, nil, nil, nil)

if res.status >= 300 then
  error(`Error fetching wether data: {res.body}`)
end
local data = json.load(res.body)

local current_temp = tostring(math.round(data["current"]["temperature_2m"]))
local current_code = data["current"]["weather_code"]
local daily_max_temp = tostring(math.round(data["daily"]["temperature_2m_max"][1]))
local daily_min_temp = tostring(math.round(data["daily"]["temperature_2m_min"][1]))
local big = #current_temp > 2 or #daily_max_temp > 2 or #daily_min_temp > 2
local is_day = data["current"]["is_day"] == 1

-- stylua: ignore start
local image_for_code = 
	if (current_code == 0 or current_code == 1) and is_day then "sun" else 
	if (current_code == 0 or current_code == 1) and not is_day then "moon" else 
	if current_code == 2 and is_day then "cloud-sun" else 
	if current_code == 2 and not is_day then "cloud-moon" else 
	if current_code == 3 then "cloud" else 
	if (current_code == 45 or current_code == 48) and is_day then "fog-sun" else 
	if (current_code == 45 or current_code == 48) and not is_day then "fog-moon" else 
	-- Rain
	if (current_code == 51 or current_code == 53 or current_code == 55)
	or (current_code == 61 or current_code == 63 or current_code == 65)
	or (current_code == 80 or current_code == 81 or current_code == 82)
	then "rain" else 
	-- 
	if (current_code == 56 or current_code == 57 or current_code == 66 or current_code == 67) then "rain-snow-mix" else 
	-- Snow
	if (current_code == 71 or current_code == 73 or current_code == 75)
	or (current_code == 77 or current_code == 85 or current_code == 86)
	then "snow" else 
	--
	if (current_code == 95 or current_code == 96 or current_code == 99) then "storm"
	else error(`Invalid weather code: {current_code}`)
-- stylua: ignore end

function get_temp_pos(temp: string): number
  return if #temp > 2 then 47 else 52
end

return niceclock
  .modulebuilder("Weather", 20, { `weather/{image_for_code}` }, {})
  :text({ x = get_temp_pos(daily_max_temp), y = 4 }, niceclock.fonts.Font5x8, daily_max_temp, colors.max)
  :text({ x = get_temp_pos(current_temp), y = 12 }, niceclock.fonts.Font5x8, current_temp, colors.white)
  :text({ x = get_temp_pos(daily_min_temp), y = 20 }, niceclock.fonts.Font5x8, daily_min_temp, colors.min)
  :box({ x = if big then 45 else 50, y = 1 }, if big then 18 else 13, 30, false, colors.white)
  :image({ x = 0, y = 0 }, `weather/{image_for_code}`)
