-- A module for de-cluttering other modules.
local U = {}
local uv = vim.uv

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

function U.load_param(o)
  local ok, res = pcall(function()
    return load("return " .. o)()
  end)
  if ok and res ~= nil then
    return res
  end
  return o
end

---Parses and unpacks command arguments.
function U.parse_cmd_args(cmd_args)
  local parsed = {}
  for _, arg in pairs(cmd_args.fargs) do
    table.insert(parsed, U.load_param(arg))
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

function U.sh_spawn(cmd, callback)
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local handle
  handle = uv.spawn(
    "sh",
    { args = { "-c", cmd }, stdio = { nil, stdout, stderr } },
    function(code)
      if callback then
        callback(code)
      end
      if handle then
        handle:close()
      end
      stdout:read_stop()
      stdout:close()
      stderr:read_stop()
      stderr:close()
    end
  )

  return { handle = handle, stdout = stdout, stderr = stderr }
end

U.o600 = 384
U.o700 = 448

function U.overwrite_if_changed(path, expected_content, perms)
  perms = perms or U.o600
  local current_content
  local stat = uv.fs_stat(path)
  if stat then
    local fd, err = uv.fs_open(path, "r", perms)
    if err or not fd then
      vim.api.nvim_err_writeln(err or "Failed to open")
      return
    end
    current_content = uv.fs_read(fd, stat.size)
    uv.fs_close(fd)
  end
  if current_content ~= expected_content then
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    uv.fs_open(path, "w", perms, function(err1, fd)
      if err1 or not fd then
        vim.api.nvim_err_writeln(err1 or "Failed to open")
        return
      end
      uv.fs_write(fd, expected_content, nil, function(err2, _)
        if err2 then
          vim.api.nvim_err_writeln(err2 or "Failed to write")
        end
        uv.fs_close(fd, function(err3)
          if err3 then
            vim.api.nvim_err_writeln(err3 or "Failed to close")
          end
        end)
      end)
    end)
  end
end
return U
