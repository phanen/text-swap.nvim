---@diagnostic disable: duplicate-doc-field, duplicate-set-field, duplicate-doc-alias, unused-local, undefined-field
local fn, api, lsp = vim.fn, vim.api, vim.lsp

local u = {
  key = require('two.key'),
}

---START INJECT two.lua

local M = {}

local options = {
  ns = api.nvim_create_namespace('two'),
  hl = { name = 'TwoRegion', link = 'Search' },
  diff = { side_by_side = true },
}

api.nvim_set_hl(0, options.hl.name, { link = options.hl.link, default = true })

---@alias two.op 'swap'|'diff'
---@alias two.handler fun(linewise: boolean, start_pos: two.pos, end_pos: two.pos)
---@alias two.mode "char"|"line"|"block"
---@alias two.pos [integer, integer]

M.state = {
  op = nil, ---@type two.op?
  count = nil, ---@type integer?
  cancel_callback = nil, ---@type function?
}

---@param mode two.mode
---@return boolean, two.pos, two.pos
local get_context = function(mode)
  if mode == 'block' then error("[TWO] doesn't works with blockwise selections") end
  local linewise = mode == 'line'
  local start_pos, end_pos = api.nvim_buf_get_mark(0, '['), api.nvim_buf_get_mark(0, ']')
  return linewise, start_pos, end_pos
end

M.cancel = function(buf)
  api.nvim_buf_clear_namespace(buf or 0, options.ns, 0, -1)
  u.key.pop(options.ns, 'n', '<esc>')
end

---@param linewise boolean
---@param callback function
M.mark_region = function(linewise, callback)
  if vim.is_callable(M.state.cancel_callback) then M.state.cancel_callback() end
  M.state.cancel_callback = callback
  vim.hl.range(0, options.ns, options.hl.name, "'[", "']", {
    regtype = linewise and 'V' or 'v',
    inclusive = true,
  })
  u.key.push(options.ns, 'n', '<esc>', callback)
  api.nvim_buf_attach(0, false, { on_lines = callback })
end

---@type table<two.op, two.handler>
M.handlers = {}

M.handlers.swap = function(linewise, start_pos, end_pos)
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

  local buf = api.nvim_get_current_buf()
  local swap_cancel = function()
    M.cancel(buf)
    vim.b.swap_save = nil
    return true
  end

  ---@param edits [lsp.TextEdit, lsp.TextEdit]
  local function do_swap(edits)
    if cmp_pos(edits[1].range['end'], edits[2].range['end']) >= 0 then
      edits = { edits[2] }
    elseif cmp_pos(edits[1].range['end'], edits[2].range.start) > 0 then
      edits = {}
    end
    lsp.util.apply_text_edits(edits, vim._resolve_bufnr(0), 'utf-8')
    swap_cancel()
  end

  ---@type lsp.TextEdit
  local edit = (function()
    local lines = fn.getregion(fn.getpos "'[", fn.getpos "']", { type = linewise and 'V' or 'v' })
    if linewise then lines[#lines + 1] = '' end
    return {
      newText = table.concat(lines, '\r\n'),
      range = {
        start = {
          line = start_pos[1] - 1,
          character = linewise and 0 or start_pos[2],
        },
        ['end'] = {
          line = linewise and end_pos[1] or end_pos[1] - 1,
          character = linewise and 0 or end_pos[2] + vim.str_utf_end(
            api.nvim_buf_get_lines(0, end_pos[1] - 1, end_pos[1], true)[1],
            end_pos[2] + 1
          ) + 1,
        },
      },
    }
  end)()

  if not vim.b.swap_save then
    M.mark_region(linewise, swap_cancel)
    vim.b.swap_save = edit
    return
  end

  local edits = { edit, vim.b.swap_save }
  table.sort(edits, function(a, b) return cmp_range(a.range, b.range) <= 0 end)
  edits[1].newText, edits[2].newText = edits[2].newText, edits[1].newText
  do_swap(edits)
end

M.handlers.diff = function(linewise, _, _)
  local buf = api.nvim_get_current_buf()
  local diff_cancel = function()
    M.cancel(buf)
    vim.g.diff_save = nil
    return true
  end

  local lines = fn.getregion(fn.getpos "'[", fn.getpos "']", { type = linewise and 'V' or 'v' })

  if not vim.g.diff_save then
    M.mark_region(linewise, diff_cancel)
    vim.g.diff_save = lines
    return
  end

  if options.diff.side_by_side then
    local ft = vim.bo[buf].ft
    local create_buf = function(lines0)
      local buf0 = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf0, 0, -1, false, lines0)
      vim.bo[buf0].ft = ft
      vim.bo[buf0].bufhidden = 'wipe'
      return buf0
    end
    local buf1 = create_buf(lines)
    local buf2 = create_buf(vim.g.diff_save)
    vim.cmd(([[tabnew | b %s | vert sb %s | windo diffthis]]):format(buf1, buf2))
    diff_cancel()
    return
  end

  local newbuf = api.nvim_create_buf(false, true)
  local text = vim.split(
    vim.diff(table.concat(lines, '\n'), table.concat(vim.g.diff_save, '\n')) --[[@as string]],
    '\n'
  )
  api.nvim_buf_set_lines(newbuf, 0, -1, false, text)
  vim.bo[newbuf].ft = 'diff'
  api.nvim_open_win(newbuf, true, {
    relative = 'win',
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    row = math.floor((vim.o.lines - vim.o.lines * 0.8) / 2),
    col = math.floor((vim.o.columns - vim.o.columns * 0.8) / 2),
    style = 'minimal',
    border = _G.border,
  })
  diff_cancel()
end

---@param mode two.mode
M.opfunc = function(mode)
  local handler = M.handlers[M.state.op]
  if not handler then return end
  local linewise, start_pos, end_pos = get_context(mode)
  handler(linewise, start_pos, end_pos)
end

_G._U_TWO_OPFUNC = M.opfunc

---@param op two.op
local with_op = function(op)
  local motion = api.nvim_get_mode().mode:match('[vV\022]') and '`<' or ''
  M.state.op = op
  M.state.count = (M.state.count or 0) + 1
  if vim.o.opfunc ~= 'v:lua._U_TWO_OPFUNC' then vim.o.opfunc = 'v:lua._U_TWO_OPFUNC' end
  return 'g@' .. motion
end

M.swap = function() return with_op('swap') end

M.diff = function() return with_op('diff') end

return M
