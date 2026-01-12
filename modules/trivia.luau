local categories: { number } = {
  9, -- General
  10, -- Books
  11, -- Film
  12, -- Music
  13, -- Musical
  14, -- TV
  15, -- Video Games
  16, -- Board games
  17, -- Nature
  18, -- Computers
  19, -- Math
  20, -- Mythology
  21, -- Sports
  22, -- Geography
  23, -- History
  24, -- Politics
  25, -- Art
  26, -- Celebrities
  27, -- Animals
  28, -- Vehicles
  29, -- Comics
  30, -- Gadgets
  31, -- Anime
  32, -- Cartoons
}

local trivia = json.load(
  http.fetch(
    `https://opentdb.com/api.php?amount=1&type=multiple&category={math.random(1, #categories)}&encode=url3986`,
    http.methods.GET,
    nil,
    nil,
    nil
  ).body
).results[1]

local question = trivia.question
local answer = trivia.correct_answer
local answers: { string } = {}

for incorrect in trivia.incorrect_answers do
  table.insert(answers, trivia.incorrect_answers[incorrect])
end

-- Insert the correct answer into a random spot
local answer_pos = math.random(1, 4)
table.insert(answers, answer_pos, answer)

-- Colors
local black: Color = { r = 0, g = 0, b = 0 }
local info_blue: Color = { r = 113, g = 145, b = 253 }
local orange: Color = { r = 254, g = 100, b = 11 }

local red: Color = { r = 210, g = 15, b = 57 }
local yellow: Color = { r = 223, g = 142, b = 29 }
local green: Color = { r = 64, g = 160, b = 43 }
local blue: Color = { r = 30, g = 102, b = 245 }
--

local answer_interval = 25

function urldecode(str)
  return string.gsub(str, "%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16) or 0)
  end)
end

function color_for_question_num(question_num: number): Color?
  return if (question_num == 1)
    then yellow
    elseif question_num == 2 then red
    elseif question_num == 3 then green
    elseif question_num == 4 then blue
    elseif question_num == 5 then color_for_question_num(answer_pos)
    else error("Invalid question num!")
end

function create_animations(): { CustomAnimation }
  local ret: { CustomAnimation } = {
    -- Make startup disappear
    {
      animation = { loop = false, speed = 4, duration = 60 },
      component_indexes = { 0, 1, 2 },
      states = {
        { timestamp = 0, color = info_blue },
        { timestamp = 60, color = black },
      },
    },
    -- Make question disappear
    {
      animation = { loop = false, speed = 12, duration = 180 },
      component_indexes = { 3 },
      states = {
        { timestamp = 0, color = info_blue },
        { timestamp = 179, color = black },
      },
    },
  }

  -- Loop through each answer then show the correct one
  for i = 4, 8, 1 do
    local anni: CustomAnimation = {
      animation = { loop = false, speed = 12, duration = 180 + ((i - 3) * answer_interval) },
      component_indexes = { i },
      states = {
        { timestamp = 0, color = black },
        { timestamp = 180 + ((i - 4) * answer_interval), color = color_for_question_num(i - 3) },
        { timestamp = if i == 8 then 400 else 180 + ((i - 3) * answer_interval) - 1, color = black },
      },
    }
    table.insert(ret, anni)
  end

  return ret
end

local module = niceclock
  .modulebuilder("trivia", 60, {}, create_animations())
  :box({ x = 0, y = 0 }, 64, 32, true, info_blue)
  :horizontalscrollingtext(
    { x = 64, y = 3 },
    niceclock.fonts.Font7x13,
    "Trivia",
    orange,
    0,
    -40,
    { duration = 30, speed = 2, loop = false }
  )
  :horizontalscrollingtext(
    { x = 64, y = 17 },
    niceclock.fonts.Font7x13,
    "Time",
    orange,
    0,
    -45,
    { duration = 30, speed = 4, loop = false }
  )
  :verticalscrollingtext(
    { x = 0, y = 0 },
    64,
    32,
    niceclock.fonts.Font5x8,
    urldecode(question),
    info_blue,
    -50,
    1,
    { loop = false, speed = 9, duration = #question * 6 + 20 }
  )
  :wrappedtext({ x = 0, y = 0 }, niceclock.fonts.Font5x8, `A: {urldecode(answers[1])}`, black, 0)
  :wrappedtext({ x = 0, y = 0 }, niceclock.fonts.Font5x8, `B: {urldecode(answers[2])}`, black, 0)
  :wrappedtext({ x = 0, y = 0 }, niceclock.fonts.Font5x8, `C: {urldecode(answers[3])}`, black, 0)
  :wrappedtext({ x = 0, y = 0 }, niceclock.fonts.Font5x8, `D: {urldecode(answers[4])}`, black, 0)
  :wrappedtext(
    { x = 0, y = 0 },
    niceclock.fonts.Font5x8,
    `Answer was: {string.char(64 + answer_pos)}:{urldecode(answer)}`,
    black,
    0
  )

return module
