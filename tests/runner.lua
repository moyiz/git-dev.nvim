local function discover()
  local specs = vim.fs.find(function(name, _)
    return name:match ".*_spec%.lua"
  end, { path = "./tests/", limit = math.huge })
  return vim.tbl_map(function(p)
    return p:gsub("^lua/", ""):gsub(".lua$", ""):gsub("/", ".")
  end, specs)
end

local function run()
  local modules = discover()
  print("# Discovered tests: " .. vim.inspect(modules))

  local failed = false
  for _, spec in ipairs(modules) do
    print("\n# Testing module: " .. spec)
    if require(spec).run() then
      print("# Success in " .. spec)
    else
      print("# Failed in " .. spec)
      failed = true
    end
  end
  print "\n"
  require("os").exit(failed == false)
end

run()
