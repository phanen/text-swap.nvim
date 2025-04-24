Two step opfunc.

```lua
vim.keymap.set({ 'n', 'x' }, 'gs', function() return require('two').swap() end, { expr = true })
vim.keymap.set({ 'n', 'x' }, ' d', function() return require('two').diff() end, { expr = true })
```
