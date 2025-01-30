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

A nerd font, to correctly render the string returned by `status()`

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

Can be plugged in as a lualine component:

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

## API

- `setup(opts)`: Configure
- `status()`: Get current drift status, as a formatted string, ready for rendering
- `reset_timers()`: Reset internal timers (to force re-sync, e.g. can be configured to fire when closing lazygit to ensure up to date indication after git operations)
- `get_state()`: Get a copy of internal state

## License

MIT
