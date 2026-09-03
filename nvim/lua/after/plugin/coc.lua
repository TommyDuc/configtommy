-- https://raw.githubusercontent.com/neoclide/coc.nvim/master/doc/coc-example-config.lua

-- Some servers have issues with backup files, see #649
-- vim.opt.backup = false
-- vim.opt.writebackup = false

-- Having longer updatetime (default is 4000 ms = 4s) leads to noticeable
-- delays and poor user experience
vim.opt.updatetime = 200

-- Always show the signcolumn, otherwise it would shift the text each time
-- diagnostics appeared/became resolved
vim.opt.signcolumn = "yes"

local keyset = vim.keymap.set
-- Autocomplete
function _G.check_back_space()
    local col = vim.fn.col('.') - 1
    return col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') ~= nil
end

-- Use Tab for trigger completion with characters ahead and navigate
-- NOTE: There's always a completion item selected by default, you may want to enable
-- no select by setting `"suggest.noselect": true` in your configuration file
-- NOTE: Use command ':verbose imap <tab>' to make sure Tab is not mapped by
-- other plugins before putting this into your config
local opts = {silent = true, noremap = true, expr = true, replace_keycodes = false}
keyset("i", "<TAB>", 'coc#pum#visible() ? coc#pum#next(1) : v:lua.check_back_space() ? "<TAB>" : coc#refresh()', opts)
keyset("i", "<S-TAB>", [[coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"]], opts)

-- gopls append a trailing comma to struct field completions,
-- leaving the cursor before it. Skip over instead of inserting a duplicate.
keyset("i", ",", function()
    local column = vim.fn.col(".")
    local line = vim.fn.getline(".")
    if line:sub(column, column) ~= "," then
        return ","
    end
    if line:sub(column + 1):match("^%s*$") then
        return "<Right><CR>"
    end
    return "<Right>"
end, {silent = true, noremap = true, expr = true, replace_keycodes = true})

-- Make <CR> to accept selected completion item or notify coc.nvim to format
-- <C-g>u breaks current undo, please make your own choice
keyset("i", "<cr>", [[coc#pum#visible() ? coc#pum#confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"]], opts)

-- Use <c-j> to trigger snippets
keyset("i", "<c-j>", "<Plug>(coc-snippets-expand-jump)")
-- Use <c-space> to trigger completion
keyset("i", "<c-space>", "coc#refresh()", {silent = true, expr = true})

-- Use `[g` and `]g` to navigate diagnostics
-- Use `:CocDiagnostics` to get all diagnostics of current buffer in location list
keyset("n", "[g", "<Plug>(coc-diagnostic-prev)", {silent = true})
keyset("n", "]g", "<Plug>(coc-diagnostic-next)", {silent = true})

-- GoTo code navigation
keyset("n", "gd", "<Plug>(coc-definition)", {silent = true})
keyset("n", "gy", "<Plug>(coc-type-definition)", {silent = true})
keyset("n", "gi", "<Plug>(coc-implementation)", {silent = true})
keyset("n", "gr", "<Plug>(coc-references)", {silent = true})


-- Use K to show documentation in preview window
function _G.show_docs()
    local cw = vim.fn.expand('<cword>')
    if vim.fn.index({'vim', 'help'}, vim.bo.filetype) >= 0 then
        vim.api.nvim_command('h ' .. cw)
    elseif vim.api.nvim_eval('coc#rpc#ready()') then
        vim.fn.CocActionAsync('doHover')
    else
        vim.api.nvim_command('!' .. vim.o.keywordprg .. ' ' .. cw)
    end
end
keyset("n", "K", '<CMD>lua _G.show_docs()<CR>', {silent = true})


-- Yank the type of the symbol under the cursor (the one K shows) into a register.
-- The LSP only hands back rendered markdown, so pulling out "just the type" is a
-- per-language heuristic; see extract_type below. When it can't tell, nothing is
-- yanked rather than yanking something wrong.

-- Contents of the first fenced code block, else the first non-empty line.
local function hover_code_block(chunks)
    local out, inside, first_line = {}, false, nil
    for _, chunk in ipairs(chunks) do
        -- Each chunk may itself span several lines.
        for line in (chunk .. "\n"):gmatch("([^\n]*)\n") do
            if line:match("^%s*```") then
                if inside then return out end
                inside = true
            elseif inside then
                table.insert(out, line)
            elseif first_line == nil and line:match("%S") then
                first_line = line
            end
        end
    end
    if #out > 0 then return out end
    if first_line then return {first_line} end
    return {}
end

-- Index of the first ':' at bracket depth 0, so generics and parameter lists
-- (`Map<string, number>`, `fn(a: int)`) aren't mistaken for a type ascription.
local function top_level_colon(s)
    local depth = 0
    for i = 1, #s do
        local c = s:sub(i, i)
        if c:match("[%(%[{<]") then
            depth = depth + 1
        elseif c:match("[%)%]}>]") then
            depth = depth - 1
        elseif c == ":" and depth <= 0 then
            return i
        end
    end
    return nil
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function extract_type(lines)
    if #lines == 0 then return nil end

    local head = trim(lines[1])
    -- Drop tsserver/pyright style qualifiers: "(variable) x: string"
    head = head:gsub("^%b()%s*", "")
    -- Drop a leading declaration keyword: "var x string", "let x: String".
    -- Only these words, so a "func Foo(...)" signature is left intact.
    head = head:gsub("^[%w_]+%s+", function(kw)
        local word = kw:match("^[%w_]+")
        if word == "var" or word == "let" or word == "const"
            or word == "val" or word == "field" or word == "type" then
            return ""
        end
        return kw
    end)

    local colon = top_level_colon(head)
    local result
    if colon then
        result = trim(head:sub(colon + 1))
    else
        -- Go/gopls form: "x string", "s []byte"
        result = head:match("^[%w_%.]+%s+(.+)$")
    end
    if not result then return nil end

    -- Keep the rest of the block, for multi-line struct/interface types.
    if #lines > 1 then
        local rest = {result}
        for i = 2, #lines do
            table.insert(rest, lines[i])
        end
        result = table.concat(rest, "\n")
    end

    result = trim(result)
    if result == "" or result == "unknown" then return nil end
    return result
end

local function yank_type()
    -- Captured now: v:register is only valid for the pending mapping.
    local register = vim.v.register
    vim.fn.CocActionAsync("getHover", function(err, hover)
        if err ~= nil and err ~= vim.NIL then
            vim.notify("Type yank: " .. tostring(err), vim.log.levels.WARN)
            return
        end
        if hover == vim.NIL or type(hover) ~= "table" or #hover == 0 then
            vim.notify("Type yank: no hover information", vim.log.levels.WARN)
            return
        end
        local type_text = extract_type(hover_code_block(hover))
        if not type_text then
            vim.notify("Type yank: could not determine type", vim.log.levels.WARN)
            return
        end
        vim.fn.setreg(register, type_text, "c")
        -- A plain yank fills "0 as well; mirror that for the unnamed register.
        if register == '"' then
            vim.fn.setreg("0", type_text, "c")
        end
        vim.notify("Yanked type: " .. type_text)
    end)
end

keyset("n", "gK", yank_type, {silent = true, desc = "Yank type under cursor"})


-- Highlight the symbol and its references on a CursorHold event(cursor is idle)
vim.api.nvim_create_augroup("CocGroup", {})
vim.api.nvim_create_autocmd("CursorHold", {
    group = "CocGroup",
    command = "silent call CocActionAsync('highlight')",
    desc = "Highlight symbol under cursor on CursorHold"
})


-- Symbol renaming
-- Coc's rename prompt normally opens in insert mode with the cursor at the end
-- (see coc#dialog#_create_prompt_nvim). We want it in normal mode with the
-- cursor at the start of the symbol instead. The prompt window is shared with
-- CocList (where insert-mode filtering is wanted), so scope this to rename only.
local pending_rename = false

keyset("n", "<leader>rn", function()
    pending_rename = true
    -- Safety net: clear the flag if no prompt shows up (e.g. invalid position).
    vim.defer_fn(function() pending_rename = false end, 2000)
    vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<Plug>(coc-rename)", true, false, true), "m", false)
end, {silent = true, desc = "Rename symbol"})

vim.api.nvim_create_autocmd("User", {
    group = "CocGroup",
    pattern = "CocOpenFloatPrompt",
    desc = "Start coc rename prompt in normal mode at start of symbol",
    callback = function()
        if not pending_rename then return end
        pending_rename = false

        local winid = vim.fn['coc#dialog#get_prompt_win']()
        if winid == nil or winid == -1 then return end
        local bufnr = vim.api.nvim_win_get_buf(winid)

        -- <CR> only accepts from insert mode by default; add a normal-mode one.
        keyset("n", "<CR>", "<Cmd>call coc#dialog#prompt_insert()<CR>",
               {buffer = bufnr, silent = true, nowait = true})

        -- Coc queues `feedkeys('A', 'int')` before firing this autocmd, so wait
        -- for the insert to actually happen before backing out of it.
        vim.api.nvim_create_autocmd("InsertEnter", {
            group = "CocGroup",
            buffer = bufnr,
            once = true,
            callback = function()
                vim.schedule(function()
                    if not vim.api.nvim_win_is_valid(winid) then return end
                    vim.cmd("stopinsert")
                    pcall(vim.api.nvim_win_set_cursor, winid, {1, 0})
                end)
            end,
        })
    end,
})

-- File renaming (updates imports/references via LSP workspace edits)
keyset("n", "<leader>rf", "<Cmd>CocCommand workspace.renameCurrentFile<CR>",
       { silent = false, desc = "Rename current file" })


-- Formatting selected code
-- keyset("x", "<leader>f", "<Plug>(coc-format-selected)", {silent = true})
-- keyset("n", "<leader>f", "<Plug>(coc-format-selected)", {silent = true})


-- Setup formatexpr specified filetype(s)
vim.api.nvim_create_autocmd("FileType", {
    group = "CocGroup",
    pattern = "typescript,json",
    command = "setl formatexpr=CocAction('formatSelected')",
    desc = "Setup formatexpr specified filetype(s)."
})

-- Apply codeAction to the selected region
-- Example: `<leader>aap` for current paragraph
local opts = {silent = true, nowait = true}
keyset("x", "<leader>a", "<Plug>(coc-codeaction-selected)", opts)
keyset("n", "<leader>a", "<Plug>(coc-codeaction-selected)", opts)

-- Remap keys for apply code actions at the cursor position.
keyset("n", "<leader>ac", "<Plug>(coc-codeaction-cursor)", opts)
-- Remap keys for apply source code actions for current file.
keyset("n", "<leader>as", "<Plug>(coc-codeaction-source)", opts)
-- Apply the most preferred quickfix action on the current line.
keyset("n", "<leader>al", "<Plug>(coc-fix-current)", opts)

-- Remap keys for apply refactor code actions.
keyset("n", "<leader>re", "<Plug>(coc-codeaction-refactor)", { silent = true })
keyset("x", "<leader>r", "<Plug>(coc-codeaction-refactor-selected)", { silent = true })
keyset("n", "<leader>r", "<Plug>(coc-codeaction-refactor-selected)", { silent = true })

-- Run the Code Lens actions on the current line
keyset("n", "<leader>cl", "<Plug>(coc-codelens-action)", opts)


-- Map function and class text objects
-- NOTE: Requires 'textDocument.documentSymbol' support from the language server
keyset("x", "if", "<Plug>(coc-funcobj-i)", opts)
keyset("o", "if", "<Plug>(coc-funcobj-i)", opts)
keyset("x", "af", "<Plug>(coc-funcobj-a)", opts)
keyset("o", "af", "<Plug>(coc-funcobj-a)", opts)
keyset("x", "ic", "<Plug>(coc-classobj-i)", opts)
keyset("o", "ic", "<Plug>(coc-classobj-i)", opts)
keyset("x", "ac", "<Plug>(coc-classobj-a)", opts)
keyset("o", "ac", "<Plug>(coc-classobj-a)", opts)


-- Remap <C-f> and <C-b> to scroll float windows/popups
---@diagnostic disable-next-line: redefined-local
local opts = {silent = true, nowait = true, expr = true}
keyset("n", "<C-f>", 'coc#float#has_scroll() ? coc#float#scroll(1) : "<C-f>"', opts)
keyset("n", "<C-b>", 'coc#float#has_scroll() ? coc#float#scroll(0) : "<C-b>"', opts)
keyset("i", "<C-f>",
       'coc#float#has_scroll() ? "<c-r>=coc#float#scroll(1)<cr>" : "<Right>"', opts)
keyset("i", "<C-b>",
       'coc#float#has_scroll() ? "<c-r>=coc#float#scroll(0)<cr>" : "<Left>"', opts)
keyset("v", "<C-f>", 'coc#float#has_scroll() ? coc#float#scroll(1) : "<C-f>"', opts)
keyset("v", "<C-b>", 'coc#float#has_scroll() ? coc#float#scroll(0) : "<C-b>"', opts)


-- Use CTRL-S for selections ranges
-- Requires 'textDocument/selectionRange' support of language server
keyset("n", "<C-s>", "<Plug>(coc-range-select)", {silent = true})
keyset("x", "<C-s>", "<Plug>(coc-range-select)", {silent = true})


-- Add `:Format` command to format current buffer
vim.api.nvim_create_user_command("Format", "call CocAction('format')", {})

-- " Add `:Fold` command to fold current buffer
vim.api.nvim_create_user_command("Fold", "call CocAction('fold', <f-args>)", {nargs = '?'})

-- Add `:OR` command for organize imports of the current buffer
vim.api.nvim_create_user_command("OR", "call CocActionAsync('runCommand', 'editor.action.organizeImport')", {})

-- Add (Neo)Vim's native statusline support
-- NOTE: Please see `:h coc-status` for integrations with external plugins that
-- provide custom statusline: lightline.vim, vim-airline
vim.opt.statusline:prepend("%{coc#status()}%{get(b:,'coc_current_function','')}%{v:lua.coc_diag_status()}")

-- Mappings for CoCList
-- code actions and coc stuff
--@diagnostic disable-next-line: redefined-local
local opts = {silent = true, nowait = true}
-- Show all diagnostics
keyset("n", "<leader>ca", ":<C-u>CocList diagnostics<cr>", opts)
-- Manage extensions
keyset("n", "<leader>ce", ":<C-u>CocList extensions<cr>", opts)
-- Show commands
keyset("n", "<leader>cc", ":<C-u>CocList commands<cr>", opts)
-- Find symbol of current document
keyset("n", "<leader>co", ":<C-u>CocList outline<cr>", opts)
-- Search workspace symbols
keyset("n", "<leader>cs", ":<C-u>CocList -I symbols<cr>", opts)
-- Do default action for next item
keyset("n", "<leader>cj", ":<C-u>CocNext<cr>", opts)
-- Do default action for previous item
keyset("n", "<leader>ck", ":<C-u>CocPrev<cr>", opts)
-- Resume latest coc list
keyset("n", "<leader>cp", ":<C-u>CocListResume<cr>", opts)

-- other stuff
keyset("n", "<leader>hi", "<Cmd>CocCommand document.toggleInlayHint<CR>", opts)
keyset("x", "<leader>hi", "<Cmd>CocCommand document.toggleInlayHint<CR>", opts)

keyset("n", "<leader>ho", "<Cmd>CocCommand document.showOutgoingCalls<CR>", opts)
keyset("x", "<leader>ho", "<Cmd>CocCommand document.showOutgoingCalls<CR>", opts)

keyset("n", "<leader>hc", "<Cmd>CocCommand document.showIncomingCalls<CR>", opts)
keyset("x", "<leader>hc", "<Cmd>CocCommand document.showIncomingCalls<CR>", opts)


-- Toggle diagnostics (signs, underline and virtual text all at once).
-- NOTE: the global and the buffer toggle are independent in coc: if diagnostics
-- are globally off, <leader>hq will not bring them back for the current buffer.
-- The notification and the statusline marker below make the current state visible.
-- NOTE: coc exposes no way to query whether diagnostics are currently enabled,
-- so the state below is mirrored rather than read back. It can drift if
-- diagnostics get toggled through some other path; toggling twice resyncs it.
local diag_global_on = true
local diag_buffer_on = {}

-- Statusline marker, shown just left of the file name while diagnostics are off.
-- Inside a `%{}` expression Vim evaluates with the drawn window's buffer as the
-- current one, so per-buffer state resolves correctly in every split.
-- When diagnostics are off globally the marker gets a globe prefix; that case
-- wins over the per-buffer one, since the globe already means "off everywhere".
local DIAG_OFF_MARKER = "\u{F0209} " -- Nerd Font nf-md-eye_off
local DIAG_GLOBAL_MARKER = "\u{F059F}" -- Nerd Font nf-md-web

function _G.coc_diag_status()
    if not diag_global_on then
        return DIAG_GLOBAL_MARKER .. DIAG_OFF_MARKER
    end
    local bufnr = vim.api.nvim_get_current_buf()
    if diag_buffer_on[bufnr] == false then
        return DIAG_OFF_MARKER
    end
    return ""
end

local function diag_toggle_global()
    diag_global_on = not diag_global_on
    vim.fn.CocActionAsync("diagnosticToggle")
    vim.notify("diagnostics (all buffers): " .. (diag_global_on and "on" or "off"))
    vim.cmd("redrawstatus!")
end

local function diag_toggle_buffer()
    local bufnr = vim.api.nvim_get_current_buf()
    local on = diag_buffer_on[bufnr]
    if on == nil then on = true end
    diag_buffer_on[bufnr] = not on
    vim.fn.CocActionAsync("diagnosticToggleBuffer")
    vim.notify("diagnostics (this buffer): " .. (diag_buffer_on[bufnr] and "on" or "off"))
    vim.cmd("redrawstatus!")
end

vim.api.nvim_create_autocmd("BufDelete", {
    group = "CocGroup",
    desc = "Forget per-buffer diagnostic toggle state",
    callback = function(args) diag_buffer_on[args.buf] = nil end,
})

keyset("n", "<leader>ha", diag_toggle_global,
       {silent = true, nowait = true, desc = "Toggle diagnostics (all buffers)"})
keyset("x", "<leader>ha", diag_toggle_global,
       {silent = true, nowait = true, desc = "Toggle diagnostics (all buffers)"})

keyset("n", "<leader>hq", diag_toggle_buffer,
       {silent = true, nowait = true, desc = "Toggle diagnostics (current buffer)"})
keyset("x", "<leader>hq", diag_toggle_buffer,
       {silent = true, nowait = true, desc = "Toggle diagnostics (current buffer)"})

