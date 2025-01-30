local M = {}

-- Wrapper around vim jobs to implement timeouts
function M.with_timeout(cmd, opts, timeout)
  local job_id
  local timer = vim.uv.new_timer()

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
    if job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1 then
      vim.fn.jobstop(job_id)
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
      if timer then
        timer:again()
      end
      original_callbacks.on_stdout(...)
    end
  end

  -- Start the timer
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

  -- Start the job
  job_id = vim.fn.jobstart(cmd, opts)
  return job_id
end

return M
