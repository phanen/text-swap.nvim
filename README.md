## two step opfunc
```lua
vim.keymap.set({ 'n', 'x' }, 'gs', function() return require('two').swap() end, { expr = true })
vim.keymap.set({ 'n', 'x' }, ' d', function() return require('two').diff() end, { expr = true })
```

## key push/pop
e.g. https://github.com/abo-abo/ace-window
```lua
-- stylua: ignore
vim.keymap.set('n', ' <c-w>', function()
  local wink = { '+', '-', '<', '<bs>', '<cr>', '<down>', '<enter>', '<left>', '<right>', '<up>', '=', '>', '<c-b>', '<c-c>', '<c-d>', '<c-f>', '<c-h>', '<c-i>', '<c-j>', '<c-k>', '<c-l>', '<c-n>', '<c-o>', '<c-p>', '<c-q>', '<c-r>', '<c-s>', '<c-t>', '<c-v>', '<c-w>', '<c-x>', '<c-z>', '<c-]>', '<c-^>', '<c-_>', 'F', 'H', 'J', 'K', 'L', 'P', 'R', 'S', 'T', 'W', ']', '^', '_', 'b', '|', 'c', 'd', 'f', 'g<Tab>', 'gF', 'gT', 'g]', 'g<c-]>', 'ge', 'gf', 'gt', 'g}', 'h', 'i', 'j', 'k', 'l', 'n', 'o', 'p', 'q', 'r', 's', 't', 'v', 'w', 'x', 'z', '}', }
  local toggle = not _G.win_ns and require('two.key').push or require('two.key').pop
  local ns = _G.win_ns or api.nvim_create_namespace('win.map')
  _G.win_ns = not _G.win_ns and ns or nil
  for _, k in ipairs(wink) do ---@diagnostic disable-next-line: redundant-parameter
    toggle(ns, { 'n', 'x' }, k, '<c-w>' .. k, { noremap = true, nowait = true })
  end
end)
```

## todo
* one step
* more steps
* multi cursor
