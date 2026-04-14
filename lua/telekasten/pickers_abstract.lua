local M = {}

-- Helper to resolve paths to absolute paths
local function resolve_path(path, cwd)
  if not path or path == '' then return nil end -- Handle nil or empty paths
  cwd = cwd or vim.fn.getcwd()

  -- Check if the path is already absolute (handles Unix and Windows paths)
  -- Unix: starts with /
  -- Windows: starts with C:/ or C:\
  local is_absolute = path:match("^/.*") or path:match("^[A-Za-z]:[/\\]?.*")

  local resolved_path
  if is_absolute then
    resolved_path = vim.fn.fnamemodify(path, ":p")
  else
    -- Join cwd and path, then normalize
    -- Ensure consistent path separators before joining
    local joined_path = cwd .. '/' .. path
    resolved_path = vim.fn.fnamemodify(joined_path, ":p")
  end

  -- For Windows compatibility, ensure forward slashes
  resolved_path = resolved_path:gsub('\\\\', '/')

  return resolved_path
end

-- Mock selection storage for Snacks picker compatibility
M._mock_selection = nil

-- Helper to extract Telescope mappings and convert to Snacks actions
local function adapt_snacks_mappings(opts, snacks_opts)
  if not opts.attach_mappings then return end
  
  local extracted = {}
  -- Mock telescope's map function to extract the keybinds
  opts.attach_mappings(0, function(mode, key, func)
    extracted[key] = func
  end)

  snacks_opts.win = snacks_opts.win or { input = { keys = {} } }
  snacks_opts.actions = snacks_opts.actions or {}

  for key, func in pairs(extracted) do
    local action_name = "tk_action_" .. key:gsub("[%<%>%-]", "")
    -- Map the key in snacks
    snacks_opts.win.input.keys[key] = { action_name, mode = { "i", "n" } }
    -- Define the action to update mock state and call Telekasten's function
    snacks_opts.actions[action_name] = function(picker, item)
      if item then
        local rel_path = item.file or item.text

        M._mock_selection = {
          [1] = rel_path,
          value = rel_path,
          path = resolve_path(rel_path, snacks_opts.cwd),
          -- We explicitly do NOT set 'filename' here. 
          -- This forces Telekasten to fall back to 'value', 
          -- which perfectly mimics Telescope's default behavior.
          tag = item.text,
        }
      end
      func(0) -- Execute the original Telekasten closure
      picker:close()
    end
  end
end

-- declare locals for the nvim api stuff to avoid more lsp warnings
local vim = vim or {
  notify = function(msg, level) print("Notify:", msg) end,
  log = { levels = { ERROR = 1 } }
}

-- Picker abstraction layer for fzf-lua, telescope, and snacks.nvim
-- Provides a unified interface for Telekasten pickers

-- Configuration
M.config = {
  -- Default picker to use: "telescope", "fzf", or "snacks"
  default = "telescope",
  
  -- Picker-specific configurations
  telescope = {
    -- Telescope-specific options
  },
  
  fzf = {
    -- Fzf-lua specific options
  },
  
  snacks = {
    -- Snacks.nvim specific options
  }
}

-- Initialize the picker abstraction
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Get the currently configured picker backend
function M.get_picker()
  return M.config.default
end

-- Set the picker backend
function M.set_picker(backend)
  if backend ~= "telescope" and backend ~= "fzf" and backend ~= "snacks" then
    vim.notify("Invalid picker backend: " .. backend, vim.log.levels.ERROR)
    return
  end
  M.config.default = backend
end

-- Core picker functions that work across all backends

-- Find files picker
function M.find_files(opts)
  opts = opts or {}
  local picker = M.get_picker()
  
  if picker == "telescope" then
    return M._telescope_find_files(opts)
  elseif picker == "fzf" then
    return M._fzf_find_files(opts)
  elseif picker == "snacks" then
    return M._snacks_find_files(opts)
  end
end

-- Grep picker (live grep)
function M.grep_string(opts)
  opts = opts or {}
  local picker = M.get_picker()
  
  if picker == "telescope" then
    return M._telescope_grep_string(opts)
  elseif picker == "fzf" then
    return M._fzf_grep_string(opts)
  elseif picker == "snacks" then
    return M._snacks_grep_string(opts)
  end
end

-- Telekasten-specific find files picker with options
-- Supports Telekasten-specific parameters like search_pattern, filter_extensions, preview_type, etc.
function M.find_files_with_options(opts)
  opts = opts or {}
  local picker = M.get_picker()
  
  if picker == "telescope" then
    return M._telescope_find_files_with_options(opts)
  elseif picker == "fzf" then
    return M._fzf_find_files_with_options(opts)
  elseif picker == "snacks" then
    return M._snacks_find_files_with_options(opts)
  end
end

-- Telekasten-specific live grep picker with options
-- Supports Telekasten-specific parameters like default_text, search_dirs, etc.
function M.live_grep_with_options(opts)
  opts = opts or {}
  local picker = M.get_picker()
  
  if picker == "telescope" then
    return M._telescope_live_grep_with_options(opts)
  elseif picker == "fzf" then
    return M._fzf_live_grep_with_options(opts)
  elseif picker == "snacks" then
    return M._snacks_live_grep_with_options(opts)
  end
end

-- Buffers picker
function M.buffers(opts)
  opts = opts or {}
  local picker = M.get_picker()
  
  if picker == "telescope" then
    return M._telescope_buffers(opts)
  elseif picker == "fzf" then
    return M._fzf_buffers(opts)
  elseif picker == "snacks" then
    return M._snacks_buffers(opts)
  end
end

-- Tags picker
function M.tags(opts)
  opts = opts or {}
  local picker = M.get_picker()
  
  if picker == "telescope" then
    return M._telescope_tags(opts)
  elseif picker == "fzf" then
    return M._fzf_tags(opts)
  elseif picker == "snacks" then
    return M._snacks_tags(opts)
  end
end

-- Telescope implementations
function M._telescope_find_files(opts)
  local builtin = require("telescope.builtin")
  builtin.find_files(opts)
end

function M._telescope_grep_string(opts)
  local builtin = require("telescope.builtin")
  builtin.grep_string(opts)
end

function M._telescope_buffers(opts)
  local builtin = require("telescope.builtin")
  builtin.buffers(opts)
end

function M._telescope_tags(opts)
  local builtin = require("telescope.builtin")
  builtin.tags(opts)
end

-- Fzf-lua implementations
function M._fzf_find_files(opts)
  local fzf = require("fzf-lua")
  fzf.files(opts)
end

function M._fzf_grep_string(opts)
  local fzf = require("fzf-lua")
  fzf.grep(opts)
end

function M._fzf_buffers(opts)
  local fzf = require("fzf-lua")
  fzf.buffers(opts)
end

function M._fzf_tags(opts)
  local fzf = require("fzf-lua")
  fzf.btags(opts)  -- btags for buffer tags
end

-- Snacks.nvim implementations
function M._snacks_find_files(opts)
  local snacks = require("snacks")
  snacks.picker.files(opts)
end

function M._snacks_grep_string(opts)
  local snacks = require("snacks")
  snacks.picker.grep(opts)
end

function M._snacks_buffers(opts)
  local snacks = require("snacks")
  snacks.picker.buffers(opts)
end

function M._snacks_tags(opts)
  local snacks = require("snacks")
  snacks.picker.tags(opts)
end

-- Enhanced picker functions with Telekasten-specific behavior

-- Telekasten-specific find files with options
function M._telescope_find_files_with_options(opts)
  local builtin = require("telescope.builtin")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local find_opts = {
    prompt_title = opts.prompt_title,
    cwd = opts.cwd,
    find_command = opts.find_command,
    search_pattern = opts.search_pattern,
    search_depth = opts.search_depth,
    preview_type = opts.preview_type,
    default_text = opts.default_text,
    sort = opts.sort,
  }

  if opts.filter_extensions then
    find_opts.file_ignore_patterns = {}
    for _, ext in ipairs(opts.filter_extensions) do
      table.insert(find_opts.file_ignore_patterns, "*" .. ext)
    end
  end

  -- Handle on_select callback for Telescope
  find_opts.attach_mappings = function(prompt_bufnr, map)
    -- If on_select is provided, replace the default action
    if opts.on_select then
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          local path = selection.filename or selection.value
          opts.on_select(resolve_path(path, find_opts.cwd))
        end
      end)
    end

    -- If attach_mappings is provided, call it to set up additional keys
    if opts.attach_mappings then
      opts.attach_mappings(prompt_bufnr, map)
    end
    return true
  end

  builtin.find_files(find_opts)
end

function M._fzf_find_files_with_options(opts)
  local fzf = require("fzf-lua")

  local fzf_opts = {
    prompt = opts.prompt_title,
    cwd = opts.cwd,
    cmd = opts.find_command,
  }

  -- Handle on_select callback for fzf-lua
  if opts.on_select then
    fzf_opts.actions = {
      ["default"] = function(selected, fzf_opts_passed)
        if selected[1] then
          opts.on_select(resolve_path(selected[1], fzf_opts.cwd))
        end
      end
    }
  elseif opts.attach_mappings then
    -- fzf-lua uses actions instead of attach_mappings
    -- This is a simplification, as Telekasten's attach_mappings is Telescope-specific
    -- We might need a more complex mapping if we want full compatibility
  end

  fzf.files(fzf_opts)
end

function M._snacks_find_files_with_options(opts)
  local snacks = require("snacks")
  local snacks_opts = { prompt = opts.prompt_title, cwd = opts.cwd }
  if opts.search_pattern then snacks_opts.search = opts.search_pattern end

  if opts.on_select then
    snacks_opts.confirm = function(picker, item)
      picker:close()
      if item then opts.on_select(resolve_path(item.file, snacks_opts.cwd)) end
    end
  end

  adapt_snacks_mappings(opts, snacks_opts)
  snacks.picker.files(snacks_opts)
end

-- Telekasten-specific live grep with options
function M._telescope_live_grep_with_options(opts)
  local builtin = require("telescope.builtin")
  
  local grep_opts = {
    prompt_title = opts.prompt_title,
    cwd = opts.cwd,
    find_command = opts.find_command,
    default_text = opts.default_text,
    search_dirs = opts.search_dirs,
    attach_mappings = opts.attach_mappings,
    sort = opts.sort,
  }
  
  builtin.live_grep(grep_opts)
end

function M._fzf_live_grep_with_options(opts)
  local fzf = require("fzf-lua")
  
  local fzf_opts = {
    prompt = opts.prompt_title,
    cwd = opts.cwd,
    search = opts.default_text,
  }
  
  fzf.live_grep(fzf_opts)
end

function M._snacks_live_grep_with_options(opts)
  local snacks = require("snacks")
  local snacks_opts = { prompt = opts.prompt_title, cwd = opts.cwd, search = opts.default_text }

  if opts.on_select then
    snacks_opts.confirm = function(picker, item)
      picker:close()
      if item then opts.on_select(resolve_path(item.file, snacks_opts.cwd)) end
    end
  end

  adapt_snacks_mappings(opts, snacks_opts)
  snacks.picker.grep(snacks_opts)
end

-- Select a file and return just the path (for Telekasten link creation)
function M.select_file_path(prompt, cwd, on_confirm)
  local picker = M.get_picker()
  
  if picker == "telescope" then
    return M._telescope_select_file_path(prompt, cwd, on_confirm)
  elseif picker == "fzf" then
    return M._fzf_select_file_path(prompt, cwd, on_confirm)
  elseif picker == "snacks" then
    return M._snacks_select_file_path(prompt, cwd, on_confirm)
  end
end

-- Select a file and open it for editing
function M.select_and_edit_file(prompt, cwd)
  local picker = M.get_picker()
  
  if picker == "telescope" then
    return M._telescope_select_and_edit_file(prompt, cwd)
  elseif picker == "fzf" then
    return M._fzf_select_and_edit_file(prompt, cwd)
  elseif picker == "snacks" then
    return M._snacks_select_and_edit_file(prompt, cwd)
  end
end

-- Telescope implementations for enhanced functions
function M._telescope_select_file_path(prompt, cwd, on_confirm)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  
   -- Determine which find command to use
   local find_cmd = "find"  -- default fallback
   if vim.fn.executable("fd") == 1 then
     find_cmd = "fd"
   elseif vim.fn.executable("fdfind") == 1 then
     find_cmd = "fdfind"
   elseif vim.fn.executable("rg") == 1 then
     find_cmd = "rg"
   end
   
   pickers.new({}, {
     prompt_title = prompt,
     finder = finders.new_oneshot_job(find_cmd, {
       "--type", "f", "--hidden", "--exclude", ".git"
     }, {
       cwd = cwd
     }),
      sorter = conf.generic_sorter({}),
     attach_mappings = function(prompt_bufnr, map)
       actions.select_default:replace(function()
         local selection = action_state.get_selected_entry()
         actions.close(prompt_bufnr)
         if on_confirm and selection then
            on_confirm(resolve_path(selection.value, cwd))  -- Return just the path
         end
       end)
       return true
     end,
   }):find()
end

function M._telescope_select_and_edit_file(prompt, cwd)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  
  pickers.new({}, {
      prompt_title = prompt,
      finder = finders.new_oneshot_job(function()
        -- Determine which find command to use
        local find_cmd
        if vim.fn.executable("fd") == 1 then
          find_cmd = "fd"
        elseif vim.fn.executable("fdfind") == 1 then
          find_cmd = "fdfind"
        elseif vim.fn.executable("rg") == 1 then
          find_cmd = "rg"
        else
          find_cmd = "find"
        end
        return {find_cmd, "--type", "f", "--hidden", "--exclude", ".git"}, {cwd = cwd}
      end),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection and selection.value then
          vim.cmd("edit " .. vim.fn.fnameescape(resolve_path(selection.value, cwd)))
        end
      end)
      return true
    end,
  }):find()
end

-- Fzf-lua implementations for enhanced functions
function M._fzf_select_file_path(prompt, cwd, on_confirm)
  local fzf = require("fzf-lua")
  
  fzf.files({
    prompt = prompt,
    cwd = cwd,
    actions = {
      ["default"] = function(selected, opts)
        if on_confirm and selected[1] then
          on_confirm(resolve_path(selected[1], cwd))  -- Return just the path
        end
      end
    }
  })
end

function M._fzf_select_and_edit_file(prompt, cwd)
  local fzf = require("fzf-lua")
  
  fzf.files({
    prompt = prompt,
    cwd = cwd,
    actions = {
      ["default"] = function(selected, opts)
        if selected[1] then
          vim.cmd("edit " .. vim.fn.fnameescape(resolve_path(selected[1], cwd)))
        end
      end
    }
  })
end

-- Snacks.nvim implementations for enhanced functions
function M._snacks_select_file_path(prompt, cwd, on_confirm)
  local snacks = require("snacks")
  
  snacks.picker.files({
    prompt = prompt,
    cwd = cwd,
    confirm = function(selected)
      if on_confirm and selected then
        on_confirm(resolve_path(selected.file, cwd))  -- Return just the path
      end
    end
  })
end

function M._snacks_select_and_edit_file(prompt, cwd)
  local snacks = require("snacks")
  
  snacks.picker.files({
    prompt = prompt,
    cwd = cwd,
    confirm = function(selected)
      if selected then
        vim.cmd("edit " .. vim.fn.fnameescape(resolve_path(selected.file, cwd)))
      end
    end
  })
end

return M