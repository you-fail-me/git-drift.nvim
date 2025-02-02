local config = require("git-drift.config")
local util = require("git-drift.util")

local M = {}

local state = {
  -- Whether the workflow is currently running (to prevent concurrent runs)
  working = false,
  -- Last time the git fetch was done
  last_fetch = 0,
  -- Last time the upstream check was done
  last_upstream_check = 0,
  -- Last time the commits ahead and behind were counted
  last_drift_eval = 0,

  -- Upstream info
  upstream = {
    -- Whether the current branch has an upstream detected
    found = nil,
    -- Number of commits, by which the local branch is ahead of the upstream
    ahead = 0,
    -- Number of commits, by which the local branch is behind the upstream
    behind = 0,
  },
}

-- Render state into a string indicator
local function render()
  -- Still initializing, no info on upstream
  if state.upstream.found == nil then
    return "󱋖"
  end

  -- No upstream found
  if state.upstream.found == false then
    return ""
  end

  -- Upstream found, divergence info available in state
  if state.upstream.last_update_time > 0 then
    return string.format("%d %d", state.upstream.ahead, state.upstream.behind)
  end

  -- Fallback
  return ""
end

-- Check if the current branch has an upstream
local function check_upstream(callback)
  -- Call the next step right away if throttled
  if state.last_upstream_check > 0 and vim.uv.now() - state.last_upstream_check < config.options.check_upstream_interval then
    callback()
    return
  end

  -- Check if the branch has an upstream
  util.with_timeout({ "git", "rev-parse", "@{upstream}" }, {
    on_exit = vim.schedule_wrap(function(_, code)
      -- Update state
      state.upstream.last_update_time = vim.uv.now()
      state.upstream.found = (code == 0)

      -- Call next step
      callback(code == 0)
    end),
  }, config.options.command_timeout)
end

-- Start background git fetch
local function git_fetch(callback)
  -- Call the next step right away if throttled
  if state.last_fetch > 0 and vim.uv.now() - state.last_fetch < config.options.fetch_interval then
    callback()
    return
  end

  -- Return without calling the next step if no upstream
  if state.upstream.found == false then
    return
  end

  -- Do async git fetch
  util.with_timeout({ "git", "fetch" }, {
    on_exit = vim.schedule_wrap(function(_, code)
      -- Update state
      state.last_fetch = vim.uv.now()

      -- Call next step
      callback(code == 0)
    end),
  }, config.options.command_timeout)
end

-- Update the upstream state from git
local function eval_drift(callback)
  -- Return right away if throttled
  if
      state.last_drift_eval > 0
      and vim.uv.now() - state.last_drift_eval < config.options.eval_drift_interval
  then
    callback()
    return
  end

  -- Run an async job to get count of commits ahead and behind upstream
  util.with_timeout({ "git", "rev-list", "--count", "--left-right", "@{upstream}...HEAD" }, {
    on_stdout = vim.schedule_wrap(function(_, data)
      if not data or #data == 0 then
        return
      end

      -- Parse the output
      local line = data[1]
      local behind, ahead = line:match("^(%d+)%s+(%d+)$")

      -- Update state
      if behind and ahead then
        state.upstream.behind = tonumber(behind) or 0
        state.upstream.ahead = tonumber(ahead) or 0
        state.last_drift_eval = vim.uv.now()
      end
    end),

    on_exit = vim.schedule_wrap(function(_, code)
      -- Call the next step
      callback(code == 0)
    end),
  }, config.options.command_timeout)
end

-- Run the workflow: check upstream, fetch, count divergence from upstream
function M.run()
  if state.working then
    return
  end

  state.working = true

  check_upstream(function()
    git_fetch(function()
      eval_drift(function()
        state.working = false
      end)
    end)
  end)
end

-- Get commits ahead and behind from cache
function M.status()
  local timer = vim.uv.new_timer()
  timer:start(
    0,
    0,
    vim.schedule_wrap(function()
      M.run()
      timer:close()
    end)
  )

  return render()
end

-- View current state
function M.get_state()
  return {
    working = state.working,
    last_fetch = state.last_fetch,
    last_upstream_check = state.last_upstream_check,
    last_drift_eval = state.last_drift_eval,
    upstream = {
      found = state.upstream.found,
      ahead = state.upstream.ahead,
      behind = state.upstream.behind,
    },
  }
end

-- Reset state so the indicator is re-rendered
function M.reset_timers()
  vim.schedule_wrap(function()
    -- Reset the working flag if working for way too long
    if state.working and vim.uv.now() - state.last_fetch > 10 * config.options.eval_drift_interval then
      state.working = false
    end

    state.last_fetch = 0
    state.last_upstream_check = 0
    state.last_drift_eval = 0
  end)()
end

return M
