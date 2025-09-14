local config = require("git-drift.config")
local drift = require("git-drift.drift")

local M = {}

---Setup git-drift plugin with user configuration
---@param opts PluginConfig? User configuration options (optional)
function M.setup(opts)
  opts = opts or {}
  config.setup(opts)
end

---Get git status indicator string
---@type fun(): string
M.status = drift.status

---Reset internal timers to force refresh
---@type fun()
M.reset_timers = drift.reset_timers

---Get current internal state for debugging
---@type fun(): StateSnapshot
M.get_state = drift.get_state

return M
