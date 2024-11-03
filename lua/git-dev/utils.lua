-- A module for de-cluttering other modules.
local U = {}

---Safe `nvim_buf_get_var`.
---@param buf_id? number
---@param name string
function U.buf_get_var(buf_id, name)
  buf_id = buf_id or 0
  local ok, value = pcall(vim.api.nvim_buf_get_var, buf_id, name)
  if not ok or value == "" then
    return nil
  end
  return value
end

---Parses and unpacks command arguments.
function U.parse_cmd_args(cmd_args)
  local load_param = function(o)
    local ok, res = pcall(function()
      return load("return " .. o)()
    end)
    if ok and res ~= nil then
      return res
    end
    return o
  end
  local parsed = {}
  for _, arg in pairs(cmd_args.fargs) do
    table.insert(parsed, load_param(arg))
  end
  return unpack(parsed)
end

-- Generates a directory name from a Git URI.
-- If `branch` is given, it will be suffixed with "#branch"
-- "https://github.com/example/repo.git" => "github.com__example__repo"
function U.git_uri_to_dir_name(uri, branch)
  local dir_name =
    uri:gsub("/+$", ""):gsub(".*://", ""):gsub("[/:]", "__"):gsub(".git$", "")
  if branch and branch ~= "" then
    dir_name = dir_name .. "#" .. branch:gsub("/", "__")
  end
  return dir_name
end

---Generate a function from a command.
---@param cmd string
---@return function(table,boolean)
function U.cmd_to_func(cmd)
  return function(args, silent)
    return vim.api.nvim_cmd(
      { cmd = cmd, args = args, mods = { silent = silent } },
      {}
    )
  end
end

---Removes duplicated items in an array.
---@param arr table
---@return table
function U.uniq(arr)
  local results = {}
  local exists = {}
  for _, item in pairs(arr) do
    if not exists[item] then
      table.insert(results, item)
      exists[item] = true
    end
  end
  return results
end

---Maps a function to each item of an array.
---Notice that if the function returns `nil`, it will be omitted.
---@param f function(any)
---@return table
function U.map(f, arr)
  local results = {}
  for _, item in pairs(arr) do
    local res = f(item)
    if res then
      table.insert(results, res)
    end
  end
  return results
end

return U
