local Swap = {}

local fn, api, lsp = vim.fn, vim.api, vim.lsp

local options = {
  ns = api.nvim_create_namespace('swap'),
  hl = { name = 'SwapRegion', link = 'Search' },
  save_pos = true, -- restore cursor position
}

api.nvim_set_hl(0, options.hl.name, { link = options.hl.link, default = true })

---@param a lsp.Position
---@param b lsp.Position
local cmp_pos = function(a, b)
  if a.line == b.line and a.character == b.character then return 0 end
  if a.line < b.line or a.line == b.line and a.character < b.character then return -1 end
  return 1
end

---@param a lsp.Range
---@param b lsp.Range
local cmp_range = function(a, b)
  local rv = cmp_pos(a.start, b.start)
  return rv ~= 0 and rv or cmp_pos(a.start, b.start)
end

--- exchange (sorted) two chunk
---@param edits [lsp.TextEdit, lsp.TextEdit]
local function do_swap(edits)
  -- trivial overlap: one include the other (replace larger chunk with smaller chunk)
  if cmp_pos(edits[1].range['end'], edits[2].range['end']) >= 0 then
    edits = { edits[2] }
  -- otherwise, for non-trivial overlap: meaningless to swap
  elseif cmp_pos(edits[1].range['end'], edits[2].range.start) > 0 then
    edits = {}
  end
  lsp.util.apply_text_edits(edits, vim._resolve_bufnr(0), 'utf-16')
end

--- save and hl the first swap chunk of text
---@param linewise boolean
local do_first_range = function(linewise)
  vim.hl.range(0, options.ns, options.hl.name, "'[", "']", {
    regtype = linewise and 'V' or 'v',
    inclusive = true,
  })
  vim.b.swap_save_esc = fn.maparg('<esc>', 'n', false, true)
  vim.keymap.set('n', '<esc>', Swap.cancel, { buffer = 0 })
  api.nvim_buf_attach(0, false, {
    on_lines = function()
      Swap.cancel()
      return true
    end,
  })
end

--- get a inplace edit won't do anything
---@param linewise boolean
---@return lsp.TextEdit
local fake_edits = function(linewise)
  local range = { api.nvim_buf_get_mark(0, '['), api.nvim_buf_get_mark(0, ']') }
  local start_pos, end_pos = range[1], range[2]
  local lines = fn.getregion(fn.getpos "'[", fn.getpos "']", { type = linewise and 'V' or 'v' })
  if linewise then lines[#lines + 1] = '' end
  return { ---@type lsp.TextEdit
    newText = table.concat(lines, '\r\n'),
    range = {
      start = {
        line = start_pos[1] - 1,
        character = linewise and 0 or start_pos[2],
      },
      ['end'] = {
        line = linewise and end_pos[1] or end_pos[1] - 1,
        character = linewise and 0 or end_pos[2] + 1,
      },
    },
  }
end

---@param mode "char" | "line" | "block"
Swap.opfunc = function(mode)
  if options.save_pos then vim.b.swap_save_pos = api.nvim_win_get_cursor(0) end
  if mode == 'block' then error("[SWAP] doesn't works with blockwise selections") end
  local linewise = mode == 'line'
  local edit = fake_edits(linewise) -- make (0, 0)-index range used for lsp apply_text_edits

  if vim.b.swap_save_edit then
    local edits = { edit, vim.b.swap_save_edit }
    table.sort(edits, function(a, b) return cmp_range(a.range, b.range) <= 0 end)
    edits[1].newText, edits[2].newText = edits[2].newText, edits[1].newText
    do_swap(edits)
    vim.b.swap_save_edit = nil
    Swap.cancel() -- force cancel in case nothing happened
  else
    do_first_range(linewise)
    vim.b.swap_save_edit = edit
  end

  if vim.b.swap_save_pos then
    api.nvim_win_set_cursor(0, vim.b.swap_save_pos)
    vim.b.swap_save_pos = nil
  end
end

Swap.cancel = function()
  api.nvim_buf_clear_namespace(0, options.ns, 0, -1)
  vim.b.swap_save_edit = nil
  if not vim.b.swap_save_esc then return end
  vim.keymap.del('n', '<esc>', { buffer = 0 })
  fn.mapset('n', false, vim.b.swap_save_esc)
  vim.b.swap_save_esc = nil
end

Swap.swap = function()
  local motion = api.nvim_get_mode().mode:match('[vV\022]') and '`<' or ''
  vim.o.opfunc = "v:lua.require'text-swap'.opfunc"
  return 'g@' .. motion
end

return Swap
