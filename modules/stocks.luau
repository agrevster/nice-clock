-- config
-- inside config.luau:
--     stock_tickers = "AAPL,TSLA,^DJI,^GSPC", # Comma separated list of tickers
--     stock_custom_names = "^DJI:DOW,^GSPC:SNP", # Comma separated list of ticker names mapped to custom names by :
--
local tickers_cfg = getcfg("stock_tickers") or ""
local tickers = tickers_cfg:split(",")

local custom_names_cfg = getcfg("stock_custom_names") or ""
local custom_name_data: { string } = custom_names_cfg:split(",")

local custom_names = {}

for _, data in ipairs(custom_name_data) do
  local data = data:split(":")
  custom_names[data[1]] = data[2]
end

-- code

local ticker = tickers[math.random(1, #tickers)]
local random_vartime = math.random(1, 3)
local vartime = { "1mo", "6mo", "1y" }
local ticker_name = custom_names[ticker] or ticker

local stock_data = http.fetch(`http://127.0.0.1:9820/api/stocks/{ticker}`, http.methods.GET, nil, nil, nil)

if stock_data.status ~= 200 then
  error(`Invalid stock ticker: {ticker}`)
end

local colors = {
  white = { r = 255, g = 255, b = 255 },
  green = { r = 64, g = 160, b = 43 },
  red = { r = 210, g = 15, b = 57 },
}

-- Adds + to the string representation of the given number if the number is positive
function tostring_with_plus(number: number): string
  if number >= 100 then
    number = math.round(number)
  end
  return if number > 0 then `+{number}` else tostring(number)
end

function round_stock_price_to_size(price: number): string
  local price_str = tostring(price)
  if #price_str > 6 then
    return tostring(math.round(price))
  end
  return price_str
end

stock_data = json.load(stock_data.body)
local vartime_stock_percent = stock_data[`percent_{vartime[random_vartime]}`]

local today_color = if stock_data.percent > 0 then colors.green else colors.red
local vartime_color = if vartime_stock_percent > 0 then colors.green else colors.red

return niceclock
  .modulebuilder("stocks", 20, {}, {})
  :text({ y = 0, x = 0 }, niceclock.fonts.Font6x13, ticker_name, colors.white)
  :text({ y = 24, x = 0 }, niceclock.fonts.Font5x8_2, round_stock_price_to_size(stock_data.price), colors.white)
  -- Today
  :text({ y = 0, x = 34 }, niceclock.fonts.Font5x8, "Today", colors.white)
  :text({ y = 8, x = 34 }, niceclock.fonts.Font5x8_2, tostring_with_plus(stock_data.percent), today_color)
  -- Variable time
  :text(
    { y = 16, x = 34 },
    niceclock.fonts.Font5x8,
    `{vartime[random_vartime]:gsub("o", ""):upper()}`,
    colors.white
  )
  :text({ y = 24, x = 34 }, niceclock.fonts.Font5x8_2, tostring_with_plus(vartime_stock_percent), vartime_color)
