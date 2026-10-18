-- 共享浮窗配色：通用浮窗、Snacks、Noice、速查和 Spring 向导

local M = {}

local SOFT_HL = {
  { "SnacksTitle", { fg = "#89b4fa", bold = true } },
  { "SnacksPickerTitle", { fg = "#89b4fa", bold = true } },
  { "SnacksPickerInputTitle", { fg = "#89b4fa", bold = true } },
  { "SnacksPickerBorder", { fg = "#7f849c" } },
  { "SnacksPickerBoxBorder", { fg = "#7f849c" } },
  { "SnacksPickerListBorder", { fg = "#7f849c" } },
  { "SnacksPickerInputBorder", { fg = "#7f849c" } },
  { "SnacksPickerPrompt", { fg = "#89b4fa", bold = true } },
  { "FloatBorder", { fg = "#7f849c" } },
  { "FloatTitle", { fg = "#89b4fa", bold = true } },
  { "NormalFloat", { bg = "#1e1e2e" } },
  { "SnacksInputBorder", { fg = "#7f849c" } },
  { "SnacksInputTitle", { fg = "#89b4fa", bold = true } },
  { "SnacksInputNormal", { bg = "#1e1e2e" } },
  { "NoiceCmdlinePopup", { bg = "#1e1e2e" } },
  { "NoiceCmdlinePopupBorder", { fg = "#7f849c" } },
  { "SnacksPickerBox", { bg = "#1e1e2e" } },
  { "SnacksPickerList", { bg = "#1e1e2e" } },
  { "SnacksPicker", { bg = "#1e1e2e" } },
  { "SnacksPickerInput", { bg = "#1e1e2e" } },
  { "SnacksPickerCursorLine", { bg = "#313244", bold = true } },
  { "SnacksPickerListCursorLine", { bg = "#313244", bold = true } },
  { "SnacksPickerInputCursorLine", { bg = "#313244", bold = true } },
  { "SnacksPickerMatch", { fg = "#f9e2af", bold = true } },
  { "SnacksPickerFile", { fg = "#cdd6f4" } },
  { "SnacksPickerDirectory", { fg = "#cdd6f4" } },
  { "SnacksPickerDir", { fg = "#7f849c" } },
  { "SnacksPickerDelim", { fg = "#585b70" } },
  { "SnacksPickerTotals", { fg = "#7f849c" } },
  { "CheatSheetBg", { bg = "#1e1e2e" } },
  { "CheatSheetBorder", { fg = "#7f849c" } },
  { "CheatSheetWinTitle", { fg = "#89b4fa", bold = true } },
  { "CheatSheetTitle", { fg = "#89b4fa", bold = true } },
  { "CheatSheetSection", { fg = "#89b4fa", bold = true } },
  { "CheatSheetBar", { fg = "#585b70" } },
  { "CheatSheetSeparator", { fg = "#585b70" } },
  { "CheatSheetHint", { fg = "#7f849c" } },
  { "CheatSheetKey", { fg = "#f9e2af", bold = true } },
  { "CheatSheetText", { fg = "#cdd6f4" } },
  { "SnacksPickerIdx", { fg = "#6c7086" } },
  { "SnacksPickerBufNr", { fg = "#6c7086" } },
  { "SnacksPickerBufFlags", { fg = "#f9e2af" } },
  { "SnacksPickerSpecial", { fg = "#89b4fa" } },
  { "SnacksPickerCurrentProject", { fg = "#89b4fa", bold = true } },
  { "SnacksPickerCurrentBadge", { fg = "#6c7086" } },
  { "SnacksPickerBackdrop", { bg = "#11111b" } },
  { "WizBg", { bg = "#1e1e2e" } },
  { "WizBorder", { fg = "#7f849c" } },
  { "WizTitle", { fg = "#89b4fa", bold = true } },
  { "WizCursorLine", { bg = "#313244", fg = "#cdd6f4", bold = true } },
  { "WizKey", { fg = "#cdd6f4" } },
  { "WizSel", { fg = "#89b4fa", bold = true } },
  { "WizBadge", { fg = "#f9e2af", bold = true } },
  { "WizHint", { fg = "#a6adc8" } },
  { "WizDim", { fg = "#585b70" } },
  { "WizMagenta", { fg = "#f9e2af", bold = true } },
  { "WizMarker", { fg = "#89b4fa", bold = true } },
  { "WizPeach", { fg = "#fab387" } },
  { "WizMenuSel", { fg = "#cdd6f4", bold = true } },
}

local NEON = {
  border = "#F38BA8",
  borderB = "#F5A0B8",
  borderC = "#E893AC",
  sun = "#F5C2E7",
  white = "#CDD6F4",
  grey = "#A6ADC8",
  dim = "#585B70",
  magenta = "#CBA6F7",
  amber = "#FAB387",
  green = "#A6E3A1",
  rowbg = "#313244",
}

local HL_DEFS = {
  { "WizBg", { bg = "NONE" } },
  { "WizBorder", { fg = NEON.border } },
  { "WizTitle", { fg = NEON.border, bold = true } },
  { "WizCursorLine", { bg = NEON.rowbg, fg = NEON.sun, bold = true, underline = true, sp = NEON.border } },
  { "WizKey", { fg = NEON.white } },
  { "WizSel", { fg = NEON.sun, bold = true } },
  { "WizBadge", { fg = NEON.amber, bold = true } },
  { "WizHint", { fg = NEON.grey } },
  { "WizDim", { fg = NEON.dim } },
  { "WizMagenta", { fg = NEON.magenta, bold = true } },
  { "WizMarker", { fg = NEON.border, bold = true } },
  { "WizPeach", { fg = NEON.amber } },
  { "WizMenuSel", { fg = NEON.sun, bold = true } },
}

local SNACKS_HL = {
  { "SnacksPicker", { bg = "NONE", fg = NEON.white } },
  { "SnacksPickerBorder", { fg = NEON.border } },
  { "SnacksPickerBoxBorder", { fg = NEON.border } },
  { "SnacksPickerListBorder", { fg = NEON.border } },
  { "SnacksPickerInputBorder", { fg = NEON.border } },
  { "SnacksPickerInputTitle", { fg = NEON.border, bold = true } },
  { "FloatBorder", { fg = NEON.border } },
  { "FloatTitle", { fg = NEON.border, bold = true } },
  { "NormalFloat", { bg = "NONE" } },
  { "SnacksInputBorder", { fg = NEON.border } },
  { "SnacksInputTitle", { fg = NEON.border, bold = true } },
  { "SnacksInputNormal", { bg = "NONE" } },
  { "NoiceCmdlinePopup", { bg = "NONE" } },
  { "NoiceCmdlinePopupBorder", { fg = NEON.border } },
  { "SnacksPickerBox", { bg = "NONE" } },
  { "SnacksPickerList", { bg = "NONE" } },
  { "SnacksPickerInput", { bg = "NONE" } },
  { "SnacksPickerTitle", { fg = NEON.border, bold = true } },
  { "SnacksPickerFooter", { fg = NEON.dim } },
  { "SnacksTitle", { fg = NEON.border, bold = true } },
  { "SnacksNormal", { bg = "NONE", fg = NEON.white } },
  { "SnacksNormalNC", { bg = "NONE", fg = NEON.white } },
  { "SnacksPickerTotals", { fg = NEON.magenta, bold = true } },
  { "SnacksPickerPrompt", { fg = NEON.green, bold = true } },
  { "SnacksPickerMatch", { fg = NEON.magenta, bold = true } },
  { "SnacksPickerSelected", { fg = NEON.border, bold = true } },
  { "SnacksPickerUnselected", { fg = NEON.dim } },
}

local function set_highlights(defs)
  for _, d in ipairs(defs) do
    vim.api.nvim_set_hl(0, d[1], d[2])
  end
end

function M.apply()
  if (vim.g.picker_skin or "soft") == "pink" then
    set_highlights(HL_DEFS)
    set_highlights(SNACKS_HL)
  else
    set_highlights(SOFT_HL)
  end
end

function M.border_colors()
  if (vim.g.picker_skin or "soft") == "pink" then
    return { NEON.border, NEON.borderB, NEON.borderC }
  end
  return { "#7f849c", "#89b4fa", "#6c7086" }
end

function M.setup()
  M.apply()
  vim.defer_fn(M.apply, 1000)
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("PickerSkin", { clear = true }),
    callback = function()
      vim.schedule(M.apply)
    end,
  })
  vim.api.nvim_create_user_command("PickerSkin", function(cmd)
    local skin = cmd.args ~= "" and cmd.args or "soft"
    if skin ~= "soft" and skin ~= "pink" then
      vim.notify("可用皮肤：soft / pink", vim.log.levels.WARN)
      return
    end
    vim.g.picker_skin = skin
    M.apply()
    vim.notify(
      "picker 皮肤 = " .. skin .. (skin == "soft" and "（细灰边 + 背景变暗）" or "（向导洋红）")
    )
  end, {
    nargs = "?",
    complete = function()
      return { "soft", "pink" }
    end,
    desc = "切换 picker 皮肤（soft|pink）",
  })
end

return M
