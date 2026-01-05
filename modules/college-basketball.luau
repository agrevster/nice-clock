-- config

-- Before adding college teams of your own, be sure to put the team's icon (created from scripts/pull_team_logo.py) into assets/images/sports/${TEAM ID}
-- For more instructions on getting a team's logo and ID see scripts/README.md
local teams: { string } = { "26" }

-- code

if #teams == 0 then
  error("You must specify teams!")
end

team = teams[math.random(1, #teams)]

function create_vs_or_at_mesasge(next_event_data: any, team_id: string): string
  local team1, team2 = unpack(next_event_data["competitions"][1]["competitors"])
  local team1_abbr = team1["team"]["abbreviation"]
  local team2_abbr = team2["team"]["abbreviation"]

  return if team1["id"] == team_id then `VS {team2_abbr}` else `@ {team1_abbr}`
end

local white: Color = { r = 255, g = 255, b = 255 }

local j = http.fetch(
  `https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/teams/{team}`,
  http.methods.GET,
  nil,
  nil,
  nil
).body
local team_data = json.load(j)["team"]

local next_event = team_data["nextEvent"][1]
local game_time = datetime.fromiso(next_event["date"]:gsub("Z", ":00Z")):shiftzone("America/Chicago")
local broadcast_location = next_event["competitions"][1]["broadcasts"][1]["media"]["shortName"]

local abbreviation = team_data["abbreviation"]
local record = team_data["record"]["items"][1]["summary"]
local vs_msg = create_vs_or_at_mesasge(next_event, team)
local game_time_formatted =
  `{game_time.date.month_name:sub(0, 3)} {game_time.date.day} {game_time.time.twelve_hour}:{game_time.time.padded_minute}`

local broadcast_location_formatted = if broadcast_location ~= nil then `Watch on {broadcast_location}` else ""

return niceclock
  .modulebuilder("College Basketball", 30, { `sports/{team}`, "sports/basketball" }, {})
  :text({ x = 0, y = 0 }, niceclock.fonts.Font7x14, abbreviation, white)
  :text({ x = 1, y = 14 }, niceclock.fonts.Font5x8, record, white)
  :horizontalscrollingtext(
    { x = 63, y = 23 },
    niceclock.fonts.Font5x8,
    `{game_time_formatted} {vs_msg} {broadcast_location_formatted}`,
    white,
    0,
    -30,
    { loop = true, speed = 5, duration = 0 }
  )
  :image({ x = 27, y = 0 }, `sports/{team}`)
  :image({ x = 52, y = 0 }, `sports/basketball`)
