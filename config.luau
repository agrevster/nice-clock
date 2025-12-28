function get_config(): ClockConfig
  local config: ClockConfig = {
    brightness = 80,
    config = {},
    modules = { "test" },
  }
  return config
end
