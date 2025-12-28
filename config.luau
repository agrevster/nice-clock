function get_config(): ClockConfig
  local config: ClockConfig = {
    brightness = 80,
    config = {},
    modules = { "logo", "clock", "flag-game" },
  }
  return config
end
