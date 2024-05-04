-- Only load once
if vim.g.indent_line_loaded == 1 then
	return
end
vim.g.indent_line_loaded = 1

-- Have changing after start up not be something that should be done
-- have it so there's an init function for the indent line structure that will set an update
-- function to be specific on the indent type (key, tab, strict tab) as well as se the rest of the
-- information


-- Refactor for the scope indicator name


-- Have an option for when it couldn't render out the whole function ,
-- in that case it should always update on move

-- Have an indent mode, strict indent mode, and key mode
-- Bases for each
-- indent mode
--	lua
-- strict indent mode
--	python
-- key mode
--	c
--
-- notes
-- key mode
--	if key open and close are on same line , go back one depth

-- Global variables
-- TODO the last start calculation differs based on the indent sequence, find out why
if vim.g.indent_line_indent_sequence == nil then
	vim.g.indent_line_indent_sequence = '\t'
end
if vim.g.indent_line_indent_depth == nil then
	vim.g.indent_line_indent_depth = 1
end
if vim.g.indent_line_line_symbol == nil then
	vim.g.indent_line_line_symbol = '|'
end



-- Shortcuts
local cmd = vim.cmd


-- Utilities
local function getLine(row)
	if row < 0 then
		return ''
	end
	return vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
end


-- State
IndentLines = { last_indent = 0, last_row = -2 }

namespace = vim.api.nvim_create_namespace('custom_indent_line')

-- Create function, force update, that sets last indent to 0 and then calls update. call force
-- update on insert move


-- Global Functions
function IndentLines:Update()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = getLine(row)
	local indent = IndentLines:getIndent(line)


	if indent == 0 then
		-- Prevent disappearing when going over a clear line in a function. This is going to be
		-- language specific, unfortunately
		if #line == 0 then
			self.last_row = row
			return
		end

		-- change to only clearing when need to
		vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
	elseif indent ~= self.last_indent or math.abs(row - self.last_row) > 1 then
		-- clear virtual text and redraw virtual text
		vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
		local count = 0
		
		local current_indent = indent
		local current_row = row
		while count < 200 and current_indent >= indent or current_indent == 0
				and #getLine(current_row) == 0 do
			-- render text
			self:drawIndentLine(current_row, indent)

			-- shift up
			current_row = current_row - 1
			current_indent = IndentLines:getIndent(getLine(current_row))

			count = count + 1
		end

		current_row = row + 1
		current_indent = IndentLines:getIndent(getLine(current_row))
		while count < 200 and current_indent >= indent or current_indent == 0
				and #getLine(current_row) == 0 do
			-- render text
			self:drawIndentLine(current_row, indent)

			-- shift up
			current_row = current_row + 1
			current_indent = IndentLines:getIndent(getLine(current_row))

			count = count + 1
		end


		if count == 200 then
			print('COUNT EXCEEDED', 'row', current_row, 'val', getLine(current_row), 'indent',
				IndentLines:getIndent(getLine(current_row)), 'set cindent', current_indent,
				'set indent', indent)
			return
		end
	end



	self.last_row = row
	self.last_indent = indent
end


function IndentLines:drawIndentLine(row, indent)
	vim.api.nvim_buf_set_extmark(0, namespace, row - 1, 0, {
		virt_text = {{vim.g.indent_line_line_symbol, 'Comment'}},
		virt_text_pos = 'overlay',
		virt_text_win_col = (indent - 1) * self.sequence_width
	})
end


function IndentLines:setIndentSequence(sequence)
	tab_width = vim.o.shiftwidth or vim.o.tabstop
	self.sequence = sequence
	self.sequence_width = #sequence
	for i=1,self.sequence_width do
		if self.sequence:byte(i) == 9 then
			self.sequence_width = self.sequence_width + tab_width - 1
		end
	end
end
-- Set default indent sequence
IndentLines:setIndentSequence(vim.g.indent_line_indent_sequence)

function IndentLines:getIndent(line)
	indent = -1
	li = 1

	matched = true
	while matched do
		indent = indent + 1
		si = 1
		sc = self.sequence:byte(si)
		while sc ~= nil do
			if line:byte(li) ~= sc then
				matched = false
				break
			end

			li = li + 1
			si = si + 1
			sc = self.sequence:byte(si)
		end
	end

	return indent
end



-- Callbacks
vim.cmd([[
augroup indent_line
	au!
	au CursorMoved,CursorMovedI * lua IndentLines:Update()
augroup END
]])
