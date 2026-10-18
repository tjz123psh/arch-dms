local M = {}

function M.setup()
  local ui = require("jdtls.ui")
  if ui._snacks_pick_many then
    return
  end
  ui._snacks_pick_many = true
  local original = ui.pick_many
  ui.pick_many = function(items, prompt, label, opts)
    if #items == 0 then
      return {}
    end
    local co, main = coroutine.running()
    if not co or main then
      return original(items, prompt, label, opts)
    end
    label, opts = label or tostring, opts or {}
    local finished = false
    local function finish(value)
      if finished then
        return
      end
      finished = true
      vim.schedule(function()
        if coroutine.status(co) == "suspended" then
          local ok, err = coroutine.resume(co, value)
          if not ok then
            vim.notify("Java 多选回调失败：" .. tostring(err), vim.log.levels.ERROR)
          end
        end
      end)
    end
    local choices = {}
    for index, item in ipairs(items) do
      choices[index] = { idx = index, item = item, text = label(item) }
    end
    -- Snacks 的 keys 整表替换，必须保留默认确认、取消和 Tab 多选键。
    local defaults = require("snacks.picker.config.defaults").defaults.win
    local ok, picker = pcall(require("snacks").picker.pick, {
      source = "jdtls-pick-many",
      title = vim.trim((prompt or "选择"):gsub("%s+", " ")),
      items = choices,
      filter = {},
      layout = {
        preset = vim.g.jdtls_pick_layout or "picker_compact",
        preview = false,
        backdrop = tonumber(vim.g.jdtls_pick_backdrop) or 60,
      },
      formatters = { selected = { show_always = true, unselected = true } },
      format = function(item)
        return { { label(item.item) } }
      end,
      win = {
        input = {
          keys = vim.tbl_extend("force", vim.deepcopy(defaults.input.keys), {
            ["<Esc>"] = { "cancel", mode = { "n", "i" } },
          }),
        },
        list = {
          keys = vim.tbl_extend("force", vim.deepcopy(defaults.list.keys), {
            ["<Space>"] = { "toggle_item", mode = { "n", "x" } },
          }),
        },
      },
      actions = {
        toggle_item = function(pk)
          pk.list:select()
        end,
        confirm = function(pk)
          local selected = {}
          for _, item in ipairs(pk.list.selected) do
            selected[#selected + 1] = item.item
          end
          finish(selected)
          pk:close()
        end,
      },
      on_show = function(pk)
        local attempts = 0
        local function preselect()
          if finished then
            return
          end
          attempts = attempts + 1
          if #pk.list.items == 0 and attempts < 25 then
            return vim.defer_fn(preselect, 20)
          end
          local selected = {}
          for _, item in ipairs(pk.list.items) do
            if opts.is_selected and opts.is_selected(item.item) then
              selected[#selected + 1] = item
            end
          end
          pk.list:set_selected(selected)
        end
        preselect()
      end,
      on_close = function()
        finish({}) -- nvim-jdtls 的取消契约是空表，不是 nil。
      end,
    })
    if not ok or not picker then
      finished = true
      vim.notify("Java 多选不可用，回退到输入框：" .. tostring(picker), vim.log.levels.WARN)
      return original(items, prompt, label, opts)
    end
    return coroutine.yield() or {}
  end
end

return M
