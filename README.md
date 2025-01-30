# git-drift.nvim

A very basic nvim plugin exposing a function to indicate how the local git branch diverges from upstream - X commits ahead, Y commits behind. The intended usage is as a lualine component but can be programmatically plugged into pretty much anything.

![lualine usage example](./doc/lualine-drift.png)

## Features

- Shows commits ahead/behind upstream branch
- Throttles git commands to prevent issues if the function is called often (e.g. during render in a UI component)
- Configurable throttle intervals
- Function to force state re-synchronization
- Non-blocking background operations with configurable timeouts

## Requirements

Git, naturally, and a nerd font, to correctly render the string returned by `status()`

## Installation

E.g. [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "you-fail-me/git-drift.nvim",
    config = function()
        require("git-drift").setup()
    end,
}
```

## Configuration

These are the defaults:

```lua
require('git-drift').setup({
  -- How often to git fetch
  fetch_interval = 5 * 60e3,
  -- How often to check if there's upstream
  check_upstream_interval = 60e3,
  -- How often to compare to upstream
  eval_drift_interval = 30e3,
  -- Timeout for background git commands
  command_timeout = 5e3,
})
```

## Usage

### Lualine Integration

Can be plugged in as a [lualine](https://github.com/nvim-lualine/lualine.nvim) component:

```lua
    lualine_b = {
        "branch",
        {
            require("git-drift").status,
            cond = function()
                return vim.b.gitsigns_head ~= nil
            end
        },
        "diff",
        "diagnostics",
    },
```

### Force refresh

Sometimes it makes sense to re-sync the plugin state without waiting for the next throttle timer, e.g. right after git push, pull, commit etc. This can be done with `reset_timers()` function, which will force the indicator state to update on next tick. I personally use [lazygit](https://github.com/folke/snacks.nvim/blob/main/docs/lazygit.md) so tie it into lazygit close event:

```lua
vim.api.nvim_create_autocmd({ "TermClose" }, {
  callback = function(evt)
    local buf_name = vim.api.nvim_buf_get_name(evt.buf)
    if buf_name:match("lazygit") then
      -- Refresh neotree
      local events = require("neo-tree.events")
      events.fire_event(events.GIT_EVENT)
      -- Refresh git upstream indicator
      require("git-drift").reset_timers()
    end
  end,
})
```

Can be also hooked into some other appropriate event.

## API

- `setup(opts)`: Configure
- `status()`: Get current drift status, as a formatted string, ready for rendering
- `reset_timers()`: Reset internal timers (force re-sync)
- `get_state()`: Get a copy of internal state (e.g. for custom rendering)

## License

MIT
