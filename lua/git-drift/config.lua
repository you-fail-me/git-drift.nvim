local M = {}

M.defaults = {
  -- How often to do git fetch
  fetch_interval = 5 * 60e3,
  -- How often to check if there's upstream (rev-parse)
  check_upstream_interval = 60e3,
  -- How often to get commits ahead and behind upstream (rev-list)
  eval_drift_interval = 30e3,
  -- Timeout for git commands
  command_timeout = 5e3,
  -- Timeout, after which to hard reset the jobs (edge cases, like waking up after OS sleep)
  hard_reset_timeout = 180e3,
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
