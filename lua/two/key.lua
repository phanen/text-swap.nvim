local M = {}

---@alias key.dict_raw table<string, any>
---@alias key.dict [integer, string|function, vim.api.keyset.keymap?]

---@alias key.lhs string
---@alias key.stack key.dict[]?

---@type table<'n'|'x'|'o'|'i'|'c'|'t'|'s', table<key.lhs, key.stack>>
local stks = { n = {}, x = {}, o = {}, i = {}, c = {}, t = {}, s = {} }
M.stks = stks

---@change
---@param dict key.dict_raw
---@return vim.api.keyset.keymap, string, boolean, boolean
local convert_dict = function(dict)
  -- dict = vim.deepcopy(dict)
  local rhs, buffer
  dict.abbr = nil
  dict.lhs = nil
  dict.lhsraw = nil
  dict.lnum = nil
  dict.mode = nil
  dict.mode_bits = nil
  dict.script = nil
  dict.scriptversion = nil
  dict.sid = nil
  buffer = dict.buffer == 1
  dict.buffer = nil
  if dict.expr == 1 then dict.replace_keycodes = 0 end
  local mapped = getmetatable(dict) ~= vim._empty_dict_mt
  if mapped then
    rhs = dict.rhs or ''
    dict.rhs = nil
  end
  return dict, rhs, mapped, buffer
end

-- handler global key only? single mode?
---@param mode string
---@param lhs string
---@param rhs string|function?
---@param opts vim.api.keyset.keymap?
---@param ns integer
M.push = function(ns, mode, lhs, rhs, opts)
  local dict = fn.maparg(lhs, mode, false, true)
  stks[mode][lhs] = stks[mode][lhs] or {}
  local stk = stks[mode][lhs]
  local old_opts, old_rhs, mapped, buffer = convert_dict(dict)
  assert(not buffer)
  stk[#stk + 1] = { ns, old_rhs, mapped and old_opts or nil }
  stks[mode][lhs] = stk
  if not rhs then
    api.nvim_del_keymap(mode, lhs)
    return
  end

  opts = opts or {}
  if vim.is_callable(rhs) then
    opts.callback = rhs --[[@as function]]
    rhs = ''
  end

  ---@cast rhs string
  api.nvim_set_keymap(mode, lhs, rhs, opts)
end

---@param ns integer
---@param mode string
---@param lhs string
M.pop = function(ns, mode, lhs)
  local stk = stks[mode][lhs]
  if not stk or #stk == 0 then return end
  local top = stk[#stk]

  stk[#stk] = nil
  local _ns, rhs, opts = unpack(top, 1, 3)

  -- guard against twice pop...
  if _ns ~= ns then return end

  if not opts then
    api.nvim_del_keymap(mode, lhs)
    return
  end

  if vim.is_callable(rhs) then
    opts.callback = rhs --[[@as function]]
    rhs = ''
  end

  ---@cast rhs string
  api.nvim_set_keymap(mode, lhs, rhs, opts)
end

return M
