local config = require("git-drift.config")
local drift = require("git-drift.drift")

local M = {}

function M.setup(opts)
  opts = opts or {}
  config.setup(opts)
end

M.status = drift.status
M.reset_timers = drift.reset_timers
M.get_state = drift.get_state

return M
