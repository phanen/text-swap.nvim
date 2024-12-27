package.path = table.concat({ package.path, './lua/?.lua' }, ';')

local api = vim.api

local a = require('luassert')

---@class SwapTest
local SwapTest = {
  init = function(self, lines)
    assert(type(lines) == 'table')
    self.buf = api.nvim_create_buf(false, false)
    api.nvim_win_set_buf(0, self.buf)
    api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)

    vim.keymap.set({ 'n', 'x' }, 'gs', require('text-swap').swap, { expr = true })
  end,
  run_keys = function(self, keys)
    keys = type(keys) == 'table' and table.concat(keys) or keys
    vim.cmd([[normal ]] .. keys)
    return self
  end,
  expect = function(self, lines)
    local buf_lines = api.nvim_buf_get_lines(self.buf, 0, -1, false)
    a.is_equal(table.concat(lines, '\n'), table.concat(buf_lines, '\n'))
    return self
  end,
  __call = function(cls, lines)
    local obj = setmetatable({}, { __index = cls })
    obj:init(lines)
    return obj
  end,
}
setmetatable(SwapTest, SwapTest)

describe('test', function()
  it(
    'one-line chunk swap',
    function()
      SwapTest {
          'aaaaaaabbbbbbbb',
          'foo + bar + baz',
          'c ddddddddddddd',
        }
        :run_keys('gstbfbgs$')
        :expect {
          'bbbbbbbbaaaaaaa',
          'foo + bar + baz',
          'c ddddddddddddd',
        }
        :run_keys('jgsiw^gsegse$gsiw')
        :expect {
          'bbbbbbbbaaaaaaa',
          'baz + foo + bar',
          'c ddddddddddddd',
        }
        :run_keys('kgsTb2j^gsl')
        :expect {
          'bbbbbbbbcaaa',
          'baz + foo + bar',
          'aaaa ddddddddddddd',
        }
    end
  )

  it(
    'work well with unicode',
    function()
      SwapTest {
        'あああ 你好',
        '🧑‍🌾❤️❤️❤️❤️❤️❤️❤️❤️❤️❤️ ❤️',
        '😂😂😂😂😂😂😂😂😂😂😂',
      }:run_keys('2gslwgs2l'):expect {
        '你好あ ああ',
        '🧑‍🌾❤️❤️❤️❤️❤️❤️❤️❤️❤️❤️ ❤️',
        '😂😂😂😂😂😂😂😂😂😂😂',
      }
    end
  )
end)

-- don't trust anything
describe('test helper', function()
  it('simple equal', function()
    for _ in ipairs {
      { 'xxx', '', 'bbb' },
      {
        'あああ 你好',
        '🧑‍🌾❤️❤️❤️❤️❤️❤️❤️❤️❤️❤️ ❤️',
        '😂😂😂😂😂😂😂😂😂😂😂',
      },
    } do
      SwapTest {
        'xxx',
        '',
        'bbb',
      }:expect {
        'xxx',
        '',
        'bbb',
      }
    end
  end)
end)
