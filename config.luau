function get_config(): ClockConfig
  local config: ClockConfig = {
    brightness = 80,
    config = {
      zone = "America/Chicago", -- The clock's time zone
    },
    modules = { "demo" },
  }
  return config
end
