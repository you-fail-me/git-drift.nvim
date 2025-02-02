local M = {}

function M.now()
  return vim.uv.now()
end

-- Wrapper around vim jobs to implement timeouts
function M.with_timeout(cmd, opts, timeout)
  local job_id
  local timer = vim.uv.new_timer()
  local start_time = M.now()

  local original_callbacks = {
    on_exit = opts.on_exit,
    on_stdout = opts.on_stdout,
  }

  local function cleanup()
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
    -- Attempt graceful termination first
    if job_id then
      vim.fn.jobstop(job_id)
      -- Give it a small grace period then force kill if still running
      vim.defer_fn(function()
        if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
          vim.fn.system('kill -9 ' .. vim.fn.jobpid(job_id))
        end
      end, 100)
    end
  end

  opts.on_exit = function(chan_id, code, ...)
    cleanup()
    if original_callbacks.on_exit then
      original_callbacks.on_exit(chan_id, code, ...)
    end
  end

  if opts.on_stdout then
    opts.on_stdout = function(...)
      -- Only extend timeout if we haven't exceeded maximum allowed time
      if timer then
        local current_time = M.now()
        if (current_time - start_time) < (timeout * 2) then
          timer:again()
        end
      end
      original_callbacks.on_stdout(...)
    end
  end

  -- Start the job first
  job_id = vim.fn.jobstart(cmd, opts)

  local handle = {
    job_id = job_id,
    cleanup = cleanup,
  }

  -- Then immediately start the timer
  if job_id <= 0 then
    -- Job failed to start
    vim.notify(
      string.format("Failed to start job: %s", table.concat(cmd, " ")),
      vim.log.levels.ERROR
    )
    return handle
  end

  timer:start(timeout, 0, vim.schedule_wrap(function()
    vim.notify(
      string.format("Job timed out after %d ms: %s",
        timeout,
        table.concat(cmd, " ")),
      vim.log.levels.WARN
    )
    cleanup()
    -- Call the exit callback with error code
    if original_callbacks.on_exit then
      original_callbacks.on_exit(job_id, -1)
    end
  end))


  return handle
end

return M
