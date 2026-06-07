vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex, {desc='Open netrw'})
vim.keymap.set({'n', 'x'}, '<leader>py', '"+y', {desc = 'Copy to clipboard'})
vim.keymap.set({'n', 'x'}, '<leader>pp', '"+p', {desc = 'Paste clipboard text'})

local launch_cwd = vim.fn.getcwd() -- Captured once at startup

local function display_path()
    local abspath = vim.fn.expand('%:p')
    local root = launch_cwd:gsub('/$', '')
    if abspath:sub(1, #root + 1) == root .. '/' then
        return './' .. abspath:sub(#root + 2)
    end
    return abspath
end

vim.keymap.set({"n", "x"}, "<leader>pf", function()
    local path = display_path()
    vim.fn.setreg('+', path)
    vim.notify('Copied: ' .. path, vim.log.levels.INFO)
end, {desc = 'Yank file path to clipboard'})
vim.keymap.set("n", "<leader>pF", function()
    local path = display_path()
    local line = vim.fn.line('.')
    local location = path .. ':' .. line
    vim.fn.setreg('+', location)
    vim.notify('Copied: ' .. location, vim.log.levels.INFO)
end, {desc = 'Yank file path:line to clipboard'})
vim.keymap.set("x", "<leader>pF", function()
    local path = display_path()
    local line1 = vim.fn.line('v')
    local line2 = vim.fn.line('.')
    -- Ensure line1 is always the smaller number
    if line1 > line2 then
        line1, line2 = line2, line1
    end
    local location = path .. ':' .. line1 .. '-' .. line2
    vim.fn.setreg('+', location)
    vim.notify('Copied: ' .. location, vim.log.levels.INFO)
end, {desc = 'Yank file path:line1-line2 to clipboard'})
vim.keymap.set("n", "<leader>o", ':put _<cr>', {desc = "'o' without insert mode"})
vim.keymap.set("n", "<leader>O", '-:put _<cr>', {desc = "'O' without insert mode"})

-- Insert N characters and auto-return to normal mode
local function insert_n_chars(count)
    -- Store initial state
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local start_row = cursor_pos[1] - 1  -- 0-indexed for API
    local start_col = cursor_pos[2]

    -- Get initial line content up to cursor
    local start_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""
    local start_text_before = string.sub(start_line, 1, start_col)
    local start_text_after = string.sub(start_line, start_col + 1)

    -- Track initial character count at cursor position
    local start_char_count = vim.fn.strcharlen(start_text_before)

    -- Create autocommand group for this insertion
    local group = vim.api.nvim_create_augroup('InsertNChars', { clear = true })

    -- Prevent backspace from deleting text before the insert point
    vim.keymap.set('i', '<BS>', function()
        local current_cursor = vim.api.nvim_win_get_cursor(0)
        local current_row = current_cursor[1] - 1  -- 0-indexed
        local current_col = current_cursor[2]

        -- Case 1: Still on the original line
        if current_row == start_row then
            -- Don't allow backspace if at or before the insert start position
            if current_col <= start_col then
                return ''  -- Do nothing
            else
                return '<BS>'  -- Allow normal backspace
            end
        -- Case 2: On a line after the original line
        elseif current_row > start_row then
            -- Check if backspace would delete the newline and take us back to original line
            if current_col == 0 then
                -- At the beginning of a new line - check if this is the first line after start
                if current_row == start_row + 1 then
                    -- Backspace would take us back to the original line
                    -- Check if we're at the exact insert point (no chars added on original line after start_col)
                    local original_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""
                    local chars_after_start = string.sub(original_line, start_col + 1)

                    if vim.fn.strcharlen(chars_after_start) == 0 then
                        -- Would merge back to original line at insert point - prevent
                        return ''
                    else
                        -- There are chars on original line after insert point - allow
                        return '<BS>'
                    end
                else
                    -- Not the immediate next line - allow backspace
                    return '<BS>'
                end
            else
                -- Not at beginning of line - allow normal backspace
                return '<BS>'
            end
        else
            -- Somehow on a line before start (shouldn't happen normally)
            return ''
        end
    end, {buffer = bufnr, expr = true, noremap = true})

    -- Monitor text changes in insert mode
    vim.api.nvim_create_autocmd({'TextChangedI', 'TextChangedP'}, {
        group = group,
        buffer = bufnr,
        callback = function()
            -- Get current cursor position and line
            local current_cursor = vim.api.nvim_win_get_cursor(0)
            local current_row = current_cursor[1] - 1
            local current_col = current_cursor[2]

            -- Only count characters on the same line where we started
            if current_row == start_row then
                local current_line = vim.api.nvim_buf_get_lines(bufnr, current_row, current_row + 1, false)[1] or ""
                local current_text_before = string.sub(current_line, 1, current_col)

                -- Calculate how many characters have been added since start
                local current_char_count = vim.fn.strcharlen(current_text_before)
                local chars_added = current_char_count - start_char_count

                -- Exit insert mode when we've added N characters
                if chars_added >= count then
                    -- Clean up the backspace keymap
                    pcall(vim.keymap.del, 'i', '<BS>', {buffer = bufnr})
                    -- Clean up the autocmd
                    vim.api.nvim_del_augroup_by_id(group)
                    -- Exit insert mode
                    vim.cmd('stopinsert')
                end
            else
                -- If user moved to a different line (e.g., pressed Enter), handle multi-line
                -- For simplicity, we'll count all text added across lines
                local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, current_row + 1, false)
                local all_text = table.concat(lines, '\n')

                -- Calculate total characters from start position to current cursor
                local first_line_portion = string.sub(lines[1] or "", start_col + 1)
                local middle_lines = {}
                for i = 2, #lines - 1 do
                    table.insert(middle_lines, lines[i])
                end
                local last_line_portion = string.sub(lines[#lines] or "", 1, current_col)

                local inserted_parts = {first_line_portion}
                for _, line in ipairs(middle_lines) do
                    table.insert(inserted_parts, line)
                end
                if #lines > 1 then
                    table.insert(inserted_parts, last_line_portion)
                end

                local inserted_text = table.concat(inserted_parts, '\n')
                local chars_added = vim.fn.strcharlen(inserted_text)

                if chars_added >= count then
                    -- Clean up the backspace keymap
                    pcall(vim.keymap.del, 'i', '<BS>', {buffer = bufnr})
                    vim.api.nvim_del_augroup_by_id(group)
                    vim.cmd('stopinsert')
                end
            end
        end
    })

    -- Also clean up if user manually exits insert mode
    vim.api.nvim_create_autocmd('InsertLeave', {
        group = group,
        buffer = bufnr,
        once = true,
        callback = function()
            -- Clean up the backspace keymap
            pcall(vim.keymap.del, 'i', '<BS>', {buffer = bufnr})
            -- Clean up the autocmd group
            pcall(vim.api.nvim_del_augroup_by_id, group)
        end
    })

    -- Enter insert mode
    vim.cmd('startinsert')
end

-- Normal mode: Insert N characters then auto-exit
vim.keymap.set('n', '<leader>s', function()
    local count = vim.v.count1  -- Gets the count prefix, defaults to 1
    insert_n_chars(count)
end, {desc = 'Insert N characters then return to normal mode'})

-- Visual mode: Replace selection with N characters then auto-exit
vim.keymap.set('x', '<leader>s', function()
    local count = vim.v.count1
    -- Delete the selection
    vim.cmd('normal! d')
    -- Insert N characters
    insert_n_chars(count)
end, {desc = 'Replace selection with N characters'})
