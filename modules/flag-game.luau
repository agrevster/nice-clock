-- config
local colors = {
  text = { r = 230, g = 69, b = 83 },
  border = { r = 255, g = 255, b = 255 },
  light = { r = 209, g = 188, b = 130 },
}

-- stylua: ignore start
local flags = { { name = "Afghanistan", code = "af" }, { name = "Aland Islands", code = "ax" }, { name = "Albania", code = "al" }, { name = "Algeria", code = "dz" }, { name = "American Samoa", code = "as" }, { name = "Andorra", code = "ad" }, { name = "Angola", code = "ao" }, { name = "Anguilla", code = "ai" }, { name = "Antarctica", code = "aq" }, { name = "Antigua and Barbuda", code = "ag" }, { name = "Argentina", code = "ar" }, { name = "Armenia", code = "am" }, { name = "Aruba", code = "aw" }, { name = "Ascension Island", code = "sh-ac" }, { name = "Association of Southeast Asian Nations", code = "asean" }, { name = "Australia", code = "au" }, { name = "Austria", code = "at" }, { name = "Azerbaijan", code = "az" }, { name = "Bahamas", code = "bs" }, { name = "Bahrain", code = "bh" }, { name = "Bangladesh", code = "bd" }, { name = "Barbados", code = "bb" }, { name = "Basque Country", code = "es-pv" }, { name = "Belarus", code = "by" }, { name = "Belgium", code = "be" }, { name = "Belize", code = "bz" }, { name = "Benin", code = "bj" }, { name = "Bermuda", code = "bm" }, { name = "Bhutan", code = "bt" }, { name = "Bolivia", code = "bo" }, { name = "Bonaire, Sint Eustatius and Saba", code = "bq" }, { name = "Bosnia and Herzegovina", code = "ba" }, { name = "Botswana", code = "bw" }, { name = "Brazil", code = "br" }, { name = "British Indian Ocean Territory", code = "io" }, { name = "Brunei Darussalam", code = "bn" }, { name = "Bulgaria", code = "bg" }, { name = "Burkina Faso", code = "bf" }, { name = "Burundi", code = "bi" }, { name = "Cabo Verde", code = "cv" }, { name = "Cambodia", code = "kh" }, { name = "Cameroon", code = "cm" }, { name = "Canada", code = "ca" }, { name = "Canary Islands", code = "ic" }, { name = "Catalonia", code = "es-ct" }, { name = "Cayman Islands", code = "ky" }, { name = "Central African Republic", code = "cf" }, { name = "Chad", code = "td" }, { name = "Chile", code = "cl" }, { name = "China", code = "cn" }, { name = "Christmas Island", code = "cx" }, { name = "Clipperton Island", code = "cp" }, { name = "Cocos (Keeling) Islands", code = "cc" }, { name = "Colombia", code = "co" }, { name = "Comoros", code = "km" }, { name = "Cook Islands", code = "ck" }, { name = "Costa Rica", code = "cr" }, { name = "Croatia", code = "hr" }, { name = "Cuba", code = "cu" }, { name = "Curacao", code = "cw" }, { name = "Cyprus", code = "cy" }, { name = "Czech Republic", code = "cz" }, { name = "Cote d'Ivoire", code = "ci" }, { name = "Democratic Republic of the Congo", code = "cd" }, { name = "Denmark", code = "dk" }, { name = "Diego Garcia", code = "dg" }, { name = "Djibouti", code = "dj" }, { name = "Dominica", code = "dm" }, { name = "Dominican Republic", code = "do" }, { name = "Ecuador", code = "ec" }, { name = "Egypt", code = "eg" }, { name = "El Salvador", code = "sv" }, { name = "England", code = "gb-eng" }, { name = "Equatorial Guinea", code = "gq" }, { name = "Eritrea", code = "er" }, { name = "Estonia", code = "ee" }, { name = "Eswatini", code = "sz" }, { name = "Ethiopia", code = "et" }, { name = "Europian Union", code = "eu" }, { name = "Falkland Islands", code = "fk" }, { name = "Faroe Islands", code = "fo" }, { name = "Federated States of Micronesia", code = "fm" }, { name = "Fiji", code = "fj" }, { name = "Finland", code = "fi" }, { name = "France", code = "fr" }, { name = "French Polynesia", code = "pf" }, { name = "French Southern Territories", code = "tf" }, { name = "Gabon", code = "ga" }, { name = "Galicia", code = "es-ga" }, { name = "Gambia", code = "gm" }, { name = "Georgia", code = "ge" }, { name = "Germany", code = "de" }, { name = "Ghana", code = "gh" }, { name = "Gibraltar", code = "gi" }, { name = "Greece", code = "gr" }, { name = "Greenland", code = "gl" }, { name = "Grenada", code = "gd" }, { name = "Guadeloupe", code = "gp" }, { name = "Guam", code = "gu" }, { name = "Guatemala", code = "gt" }, { name = "Guernsey", code = "gg" }, { name = "Guinea", code = "gn" }, { name = "Guinea-Bissau", code = "gw" }, { name = "Guyana", code = "gy" }, { name = "Haiti", code = "ht" }, { name = "Heard Island and McDonald Islands", code = "hm" }, { name = "Holy See", code = "va" }, { name = "Honduras", code = "hn" }, { name = "Hong Kong", code = "hk" }, { name = "Hungary", code = "hu" }, { name = "Iceland", code = "is" }, { name = "India", code = "in" }, { name = "Indonesia", code = "id" }, { name = "Iran", code = "ir" }, { name = "Iraq", code = "iq" }, { name = "Ireland", code = "ie" }, { name = "Isle of Man", code = "im" }, { name = "Israel", code = "il" }, { name = "Italy", code = "it" }, { name = "Jamaica", code = "jm" }, { name = "Japan", code = "jp" }, { name = "Jersey", code = "je" }, { name = "Jordan", code = "jo" }, { name = "Kazakhstan", code = "kz" }, { name = "Kenya", code = "ke" }, { name = "Kiribati", code = "ki" }, { name = "Kosovo", code = "xk" }, { name = "Kuwait", code = "kw" }, { name = "Kyrgyzstan", code = "kg" }, { name = "Laos", code = "la" }, { name = "Latvia", code = "lv" }, { name = "League of Arab States", code = "arab" }, { name = "Lebanon", code = "lb" }, { name = "Lesotho", code = "ls" }, { name = "Liberia", code = "lr" }, { name = "Libya", code = "ly" }, { name = "Liechtenstein", code = "li" }, { name = "Lithuania", code = "lt" }, { name = "Luxembourg", code = "lu" }, { name = "Macau", code = "mo" }, { name = "Madagascar", code = "mg" }, { name = "Malawi", code = "mw" }, { name = "Malaysia", code = "my" }, { name = "Maldives", code = "mv" }, { name = "Mali", code = "ml" }, { name = "Malta", code = "mt" }, { name = "Marshall Islands", code = "mh" }, { name = "Martinique", code = "mq" }, { name = "Mauritania", code = "mr" }, { name = "Mauritius", code = "mu" }, { name = "Mayotte", code = "yt" }, { name = "Mexico", code = "mx" }, { name = "Moldova", code = "md" }, { name = "Monaco", code = "mc" }, { name = "Mongolia", code = "mn" }, { name = "Montenegro", code = "me" }, { name = "Montserrat", code = "ms" }, { name = "Morocco", code = "ma" }, { name = "Mozambique", code = "mz" }, { name = "Myanmar", code = "mm" }, { name = "Namibia", code = "na" }, { name = "Nauru", code = "nr" }, { name = "Nepal", code = "np" }, { name = "Netherlands", code = "nl" }, { name = "New Caledonia", code = "nc" }, { name = "New Zealand", code = "nz" }, { name = "Nicaragua", code = "ni" }, { name = "Niger", code = "ne" }, { name = "Nigeria", code = "ng" }, { name = "Niue", code = "nu" }, { name = "Norfolk Island", code = "nf" }, { name = "North Korea", code = "kp" }, { name = "North Macedonia", code = "mk" }, { name = "Northern Ireland", code = "gb-nir" }, { name = "Northern Mariana Islands", code = "mp" }, { name = "Norway", code = "no" }, { name = "Oman", code = "om" }, { name = "Pakistan", code = "pk" }, { name = "Palau", code = "pw" }, { name = "Panama", code = "pa" }, { name = "Papua New Guinea", code = "pg" }, { name = "Paraguay", code = "py" }, { name = "Peru", code = "pe" }, { name = "Philippines", code = "ph" }, { name = "Pitcairn", code = "pn" }, { name = "Poland", code = "pl" }, { name = "Portugal", code = "pt" }, { name = "Puerto Rico", code = "pr" }, { name = "Qatar", code = "qa" }, { name = "Republic of the Congo", code = "cg" }, { name = "Romania", code = "ro" }, { name = "Russia", code = "ru" }, { name = "Rwanda", code = "rw" }, { name = "Reunion", code = "re" }, { name = "Saint Helena", code = "sh-hl" }, { name = "Saint Kitts and Nevis", code = "kn" }, { name = "Saint Lucia", code = "lc" }, { name = "Saint Martin", code = "mf" }, { name = "Saint Pierre and Miquelon", code = "pm" }, { name = "Saint Vincent and the Grenadines", code = "vc" }, { name = "Samoa", code = "ws" }, { name = "San Marino", code = "sm" }, { name = "Sao Tome and Principe", code = "st" }, { name = "Saudi Arabia", code = "sa" }, { name = "Scotland", code = "gb-sct" }, { name = "Senegal", code = "sn" }, { name = "Serbia", code = "rs" }, { name = "Seychelles", code = "sc" }, { name = "Sierra Leone", code = "sl" }, { name = "Singapore", code = "sg" }, { name = "Sint Maarten", code = "sx" }, { name = "Slovakia", code = "sk" }, { name = "Slovenia", code = "si" }, { name = "Solomon Islands", code = "sb" }, { name = "Somalia", code = "so" }, { name = "South Africa", code = "za" }, { name = "South Georgia and the South Sandwich Islands", code = "gs" }, { name = "South Korea", code = "kr" }, { name = "South Sudan", code = "ss" }, { name = "Spain", code = "es" }, { name = "Sri Lanka", code = "lk" }, { name = "State of Palestine", code = "ps" }, { name = "Sudan", code = "sd" }, { name = "Suriname", code = "sr" }, { name = "Sweden", code = "se" }, { name = "Switzerland", code = "ch" }, { name = "Syria", code = "sy" }, { name = "Taiwan", code = "tw" }, { name = "Tajikistan", code = "tj" }, { name = "Tanzania", code = "tz" }, { name = "Thailand", code = "th" }, { name = "Timor-Leste", code = "tl" }, { name = "Togo", code = "tg" }, { name = "Tokelau", code = "tk" }, { name = "Tonga", code = "to" }, { name = "Trinidad and Tobago", code = "tt" }, { name = "Tristan da Cunha", code = "sh-ta" }, { name = "Tunisia", code = "tn" }, { name = "Turkmenistan", code = "tm" }, { name = "Turks and Caicos Islands", code = "tc" }, { name = "Tuvalu", code = "tv" }, { name = "Turkiye", code = "tr" }, { name = "Uganda", code = "ug" }, { name = "Ukraine", code = "ua" }, { name = "United Arab Emirates", code = "ae" }, { name = "United Kingdom", code = "gb" }, { name = "United Nations", code = "un" }, { name = "United States Minor Outlying Islands", code = "um" }, { name = "United States of America", code = "us" }, { name = "Uruguay", code = "uy" }, { name = "Uzbekistan", code = "uz" }, { name = "Vanuatu", code = "vu" }, { name = "Venezuela", code = "ve" }, { name = "Vietnam", code = "vn" }, { name = "Virgin Islands (British)", code = "vg" }, { name = "Virgin Islands (U.S.)", code = "vi" }, { name = "Wales", code = "gb-wls" }, { name = "Wallis and Futuna", code = "wf" }, { name = "Western Sahara", code = "eh" }, { name = "Yemen", code = "ye" }, { name = "Zambia", code = "zm" }, { name = "Zimbabwe", code = "zw" }, }
-- stylua: ignore end

function distribute_lights(self: ClockModuleBuilder): ClockModuleBuilder
  local builder = self
  for y = 0, 31, 1 do
    if y == 0 or y == 31 then
      for x = 0, 63, 1 do
        if x % 4 == 0 then
          builder = builder:tile({ x = x, y = y }, colors.light)
        end
      end
    else
      if y % 4 == 0 then
        builder = builder:tile({ x = 0, y = y }, colors.light)
        builder = builder:tile({ x = 63, y = y }, colors.light)
      end
    end
  end
  return builder
end

function range(start: number, finish: number): { number }
  local array = {}
  for i = start, finish do
    table.insert(array, i)
  end
  return array
end

function create_light_flash_animation(count: number, default_color: Color): { CustomAnimationState }
  local animations: { CustomAnimationState } = {}
  for i in range(0, count + 1) do
    local color = default_color
    if i % 2 == 0 then
      color = colors.light
    end
    if i <= count then
      table.insert(animations, { timestamp = i, color = color })
    else
      table.insert(animations, { timestamp = i, color = { r = 0, g = 0, b = 0 } })
    end
  end
  return animations
end

local flag = flags[math.random(1, #flags)]
local flag_image_name = `flags/{flag.code}`

local animations: { CustomAnimation } = {
  --Blink lights
  {
    component_indexes = range(6, 51),
    animation = {
      loop = false,
      speed = 12,
      duration = 20,
    },
    states = create_light_flash_animation(19, colors.border),
  },
  --Blink text
  {
    component_indexes = { 0 },
    animation = {
      loop = false,
      speed = 10,
      duration = 24,
    },
    states = create_light_flash_animation(23, colors.text),
  },
  {
    component_indexes = { 1 },
    animation = {
      loop = false,
      speed = 12,
      duration = 20,
    },
    states = create_light_flash_animation(20, colors.text),
  },
  {
    component_indexes = { 2 },
    animation = {
      loop = false,
      speed = 8,
      duration = 30,
    },
    states = create_light_flash_animation(30, colors.text),
  },
  --End blink text
  --Make the boarder disappear
  {
    component_indexes = { 3 },
    animation = {
      loop = false,
      speed = 12,
      duration = 20,
    },
    states = { { timestamp = 0 }, { timestamp = 20, color = { r = 0, g = 0, b = 0 } } },
  },
  -- Make flag appear
  {
    component_indexes = { 5 },
    animation = {
      loop = false,
      speed = 12,
      duration = 45,
    },
    states = { { timestamp = 0 }, { timestamp = 20, text = flag_image_name }, { timestamp = 45, text = "empty" } },
  },
  --Make answer appear
  {
    component_indexes = { 4 },
    animation = {
      loop = false,
      speed = 12,
      duration = 48,
    },
    states = { { timestamp = 0 }, { timestamp = 48, color = colors.text } },
  },
}

local builder = niceclock
  .modulebuilder("Flag Game", 30, { flag_image_name }, animations)
  :text({ x = 22, y = 3 }, niceclock.fonts.Font5x8_2, "Fun", colors.text)
  :text({ x = 22, y = 12 }, niceclock.fonts.Font5x8_2, "With", colors.text)
  :text({ x = 22, y = 20 }, niceclock.fonts.Font5x8_2, "Flags", colors.text)
  :box({ x = 0, y = 0 }, 64, 32, false, colors.border)
  :wrappedtext({ x = 0, y = 0 }, niceclock.fonts.Font5x8, `The flag was\n {flag.name}`, { r = 0, g = 0, b = 0 }, 1)
  :image({ x = 0, y = 0 }, "empty")

builder = distribute_lights(builder)
return builder
