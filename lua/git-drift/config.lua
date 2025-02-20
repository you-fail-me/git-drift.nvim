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
  -- Timeout for hard reset of any hanging jobs
  hard_reset_timeout = 180e3,
}

M.options = {}

function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts)
  -- Use explicit hard_reset_timeout if provided, otherwise calculate from eval_drift_interval
  -- Useful for edge cases like leaving process running when OS goes to sleep - can get weird inconsistent states
  if not opts.hard_reset_timeout then
    M.options.hard_reset_timeout = M.options.eval_drift_interval * 6
  end
end

return M
