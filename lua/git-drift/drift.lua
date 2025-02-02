local config = require("git-drift.config")
local util = require("git-drift.util")
local icons = require("git-drift.icons")

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

  -- Keep track of background jobs
  running_jobs = {
    upstream = nil,
    fetch = nil,
    drift = nil,
  },
}

-- Render state into a string indicator
local function render()
  -- Still initializing, no info on upstream
  if state.upstream.found == nil then
    return icons.SEARCHING
  end

  -- No upstream found
  if state.upstream.found == false then
    return icons.NO_UPSTREAM
  end

  -- Upstream found, divergence info available in state
  if state.last_upstream_check > 0 then
    return string.format("%d%s %d%s", state.upstream.ahead, icons.AHEAD, state.upstream.behind, icons.BEHIND)
  end

  -- Fallback
  return icons.FALLBACK
end

-- Check if the current branch has an upstream
local function check_upstream(callback)
  -- Call the next step right away if throttled
  if util.now() - state.last_upstream_check < config.options.check_upstream_interval then
    callback()
    return
  end

  -- Check if the branch has an upstream
  state.running_jobs.upstream = util.with_timeout({ "git", "rev-parse", "@{upstream}" }, {
    on_exit = vim.schedule_wrap(function(_, code)
      -- Update state
      state.last_upstream_check = util.now()
      state.upstream.found = (code == 0)

      -- Call next step
      callback(code == 0)
    end),
  }, config.options.command_timeout)
end

-- Start background git fetch
local function git_fetch(callback)
  -- Call the next step right away if throttled
  if util.now() - state.last_fetch < config.options.fetch_interval then
    callback()

    return
  end

  -- Skip to the next step if no upstream
  if state.upstream.found == false then
    callback()
    return
  end

  -- Do async git fetch
  state.running_jobs.fetch = util.with_timeout({ "git", "fetch" }, {
    on_exit = vim.schedule_wrap(function(_, code)
      -- Update state
      state.last_fetch = util.now()

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
      and util.now() - state.last_drift_eval < config.options.eval_drift_interval
  then
    callback()

    return
  end

  -- Return if no upstream
  if state.upstream.found == false then
    callback()
    return
  end

  -- Run an async job to get count of commits ahead and behind upstream
  state.running_jobs.drift = util.with_timeout({ "git", "rev-list", "--count", "--left-right", "@{upstream}...HEAD" }, {
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
        state.last_drift_eval = util.now()
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
    -- Kill any hanging jobs and restart if looks stuck for a while
    if state.last_upstream_check > 0 and util.now() - state.last_drift_eval > config.options.hard_reset_timeout then
      for job_name, job in pairs(state.running_jobs) do
        if job.cleanup then
          job.cleanup()
          state.running_jobs[job_name] = nil
        end
      end
    else
      return
    end
  end

  state.working = true


  check_upstream(function()
    state.running_jobs.upstream = nil
    git_fetch(function()
      state.running_jobs.fetch = nil
      eval_drift(function()
        state.running_jobs.drift = nil
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
    running_jobs = {
      upstream = state.running_jobs.upstream and state.running_jobs.upstream.job_id,
      fetch = state.running_jobs.fetch and state.running_jobs.fetch.job_id,
      drift = state.running_jobs.drift and state.running_jobs.drift.job_id,
    },
  }
end

-- Reset state so the indicator is re-rendered
function M.reset_timers()
  vim.schedule_wrap(function()
    state.last_fetch = 0
    state.last_upstream_check = 0
    state.last_drift_eval = 0
  end)()
end

return M
