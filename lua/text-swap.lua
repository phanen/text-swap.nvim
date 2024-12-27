local Swap = {}

local fn, api = vim.fn, vim.api

local options = {
  ns = api.nvim_create_namespace('swap'),
  hl = { name = 'SwapRegion', link = 'IncSearch' },
  save_pos = true, -- restore cursor position
}

api.nvim_set_hl(0, options.hl.name, { link = options.hl.link })

--- exchange (sorted) two chunk
---@param edits [lsp.TextEdit, lsp.TextEdit]
local function do_swap(edits)
  if -- trivial overlap: one include the other (replace larger chunk with smaller chunk)
    edits[1].range['end'].line > edits[2].range['end'].line
    or edits[1].range['end'].line == edits[2].range['end'].line
      and edits[1].range['end'].character >= edits[2].range['end'].character
  then
    edits = { edits[2] }
  elseif -- otherwise, for non-trivial overlap: meaningless to swap
    edits[1].range['end'].line > edits[2].range.start.line
    or edits[1].range['end'].line == edits[2].range.start.line
      and edits[1].range['end'].character > edits[2].range.start.character
  then
    edits = {}
  end
  vim.lsp.util.apply_text_edits(edits, vim._resolve_bufnr(0), 'utf-16')
end

--- save and hl the first swap chunk of text
---@param linewise boolean
local do_first_range = function(linewise)
  vim.hl.range(0, options.ns, options.hl.name, "'[", "']", {
    regtype = linewise and 'V' or 'v',
    inclusive = true,
  })
  vim.b.swap_save_esc = fn.maparg('<esc>', 'n', false, true)
  vim.keymap.set('n', '<esc>', Swap.cancel, {})
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
  table.sort(range, function(a, b) return a[1] < b[1] or a[1] == b[1] and a[2] <= b[2] end)
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
  if mode == 'block' then error("[SWAP] doesn't works with blockwise selections") end
  local linewise = mode == 'line'
  local range = fake_edits(linewise) -- make (0, 0)-index range used for lsp apply_text_edits

  if vim.b.swap_save_range then
    local edits = { range, vim.b.swap_save_range }
    table.sort(
      edits,
      function(a, b)
        return a.range.start.line < b.range.start.line
          or a.range.start.line == b.range.start.line
            and a.range.start.character <= b.range.start.character
      end
    )
    edits[1].newText, edits[2].newText = edits[2].newText, edits[1].newText
    do_swap(edits)
    vim.b.swap_save_range = nil
    Swap.cancel() -- force cancel in case nothing happened
  else
    do_first_range(linewise)
    vim.b.swap_save_range = range
  end

  if vim.b.swap_save_pos then
    api.nvim_win_set_cursor(0, vim.b.swap_save_pos)
    vim.b.swap_save_pos = nil
  end
end
_G.__swap_opfunc = Swap.opfunc

Swap.cancel = function()
  api.nvim_buf_clear_namespace(0, options.ns, 0, -1)
  vim.b.swap_save_range = nil
  if not vim.b.swap_save_esc then return end
  if vim.tbl_isempty(vim.b.swap_save_esc) then
    vim.keymap.set('n', '<esc>', '<nop>', {})
  else
    fn.mapset('n', false, vim.b.swap_save_esc)
  end
  vim.b.swap_save_esc = nil
end

Swap.operator = function()
  local motion = api.nvim_get_mode().mode:match('[Vv\022]') and '`<' or nil
  if options.save_pos then vim.b.swap_save_pos = api.nvim_win_get_cursor(0) end
  vim.o.opfunc = 'v:lua.__swap_opfunc'
  -- g@ quit visual mode, then `> or '< (idk, but work)
  api.nvim_feedkeys(('g@%s'):format(motion or ''), 'm', false)
end

return Swap
