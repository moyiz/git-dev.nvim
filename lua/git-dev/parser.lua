---The Git URI parsing engine.

-- Trims trailing slashes and adds `.git` suffix.
local function git_suffix(text)
  -- Trim trailing slashes
  text = text:gsub("/+$", "")

  -- Ensure `.git` suffix.
  -- It is optional for many (all?) git vendors.
  if text:sub(-4, -1) ~= ".git" then
    text = text .. ".git"
  end
  return text
end

-- Escape non alphanumeric characters for lua pattern matching purposes.
local function pattern_esc(text)
  return text:gsub("([^%w])", "%%%1")
end

-- Checks if given file is a valid git bundle.
local function is_git_bundle(file_path)
  local file = io.open(file_path, "rb")
  if not file then
    return false
  end
  local sig = file:read(6)
  file:close()
  return sig == "git\001\n"
end

---@class Parser
---@field gitcmd table
---@field base_uri_format string
---@field default_org? string
---@field extra_domain_to_parser? table
---@field parse function
local Parser = {}

---@param o Parser
function Parser:init(o)
  o = vim.tbl_deep_extend(
    "force",
    { base_uri_format = "%s", extra_domain_to_parser = {} },
    o
  )
  setmetatable(o, self)
  self.__index = self
  return o
end

---@class GitDevParsedRepo
---@field repo_url string
---@field full_blob? string
---@field commit? string
---@field branch? string
---@field selected_path? string
---@field type "http"|"local"|"bundle"|"raw"|"custom"

-- Since branch / tag might include slashes, it is impossible to determine how
-- to separate it from the optional trailing file path. `git ls-remote` is used
-- to find the longest ref name that can be deducted from `text`. If none is
-- found, it will be tested as a commit ID. If it is invalid as a commit, it
-- will be notated as `full_blob`. Otherwise, it will be separated to `branch`
-- and `selected_path`. If there are no slashes, it can be assumed that the
-- full blob is actually a branch / tag name, and there is no trailed file path.
function Parser:parse_full_blob(text, repo_url)
  if not text or text == "" then
    return {}
  end
  if not text:find "/" then
    return { branch = text }
  end

  local parts = vim.split(text, "/", { trimempty = true })

  -- The first part must be part of the branch / tag name.
  local refs = vim.tbl_map(function(ref)
    return ref.ref
  end, self.gitcmd:list_refs_sync(repo_url, parts[1] .. "*") or {})

  -- Since refs will be scanned by `find`, it is simpler to just concatenate
  -- them instead of iterating.
  local concat_refs = vim.fn.join(refs, "\n")

  local ref
  for i = 1, #parts do
    local new_ref = vim.fn.join(vim.list_slice(parts, 1, i), "/")
    if not concat_refs:find(pattern_esc(new_ref)) then
      break
    end
    ref = new_ref
  end
  -- No such ref, first part might still be a commit ID.
  if not ref then
    -- If the first part looks like a valid commit ID, it probably is.
    -- TODO: Find a better way. The repository is not cloned yet.
    if parts[1]:find("^" .. ("%x"):rep(40) .. "$") then
      return {
        commit = parts[1],
        selected_path = vim.fn.join(vim.list_slice(parts, 2), "/"),
      }
    else
      return { full_blob = text }
    end
  end

  -- Generate a selected path and trim leading slash.
  local selected_path = text:gsub(pattern_esc(ref), ""):sub(2)
  return {
    branch = ref,
    selected_path = selected_path ~= "" and selected_path or nil,
  }
end

function Parser:parse_tree_or_full_blob(text, repo_url)
  local res = {}
  local branch_or_tag = text:match "^/tree/(.*)$"
  if branch_or_tag then
    res.branch = branch_or_tag
  else
    -- Full blob contains both the ref and the file path.
    -- Due to possible branch / tag names that contain `/`, the parser cannot
    -- determine where the ref ends and the file name begins at this point.
    local _, sep_end = text:find "^/blob/"
    if sep_end then
      res = vim.tbl_deep_extend(
        "force",
        res,
        self:parse_full_blob(text:sub(sep_end + 1), repo_url)
      )
    end
  end
  return res
end

function Parser:parse_github_url(url, base_domain)
  local res = {}
  local _, end_ = url:find(pattern_esc(base_domain) .. "/([^/]+/[^/]+)")

  res.repo_url = end_ and git_suffix(url:sub(1, end_)) or url

  -- Parse the rest of the URL
  local tree_or_blob =
    self:parse_tree_or_full_blob(url:sub(end_ + 1), res.repo_url)
  return vim.tbl_deep_extend("force", res, tree_or_blob or {})
end

function Parser:parse_gitlab_url(url)
  local res = {}
  -- Gitlab repositories are not limited to `org/repo` notation, but `/-/`
  -- is used to split repository path from tree / blob.
  local sep_start, sep_end = url:find "/%-/"
  if not sep_end then
    res.repo_url = git_suffix(url)
    return res
  end
  res.repo_url = git_suffix(url:sub(1, sep_start))
  -- Parse the rest of the URL
  local tree_or_blob =
    self:parse_tree_or_full_blob(url:sub(sep_end), res.repo_url)
  return vim.tbl_deep_extend("force", res, tree_or_blob or {})
end

function Parser:parse_gitea_like_url(url, base_domain)
  local res = {}
  local _, repo_end = url:find(pattern_esc(base_domain) .. "/([^/]+/[^/]+)")

  res.repo_url = repo_end and git_suffix(url:sub(1, repo_end)) or url

  local url_tail = url:sub(repo_end + 1)
  if url_tail:find "^/raw/" or url_tail:find "^/src/" then
    -- Trim raw / src
    url_tail = url_tail:sub(5)
  end

  local commit, selected_path = url_tail:match "^/commit/([^/]+)/(.*)$"
  if commit then
    res.commit = commit
  end
  if selected_path then
    res.selected_path = selected_path
  end

  if url_tail:find "^/branch" or url_tail:find "^/tag" then
    res = vim.tbl_deep_extend(
      "force",
      res,
      self:parse_full_blob(
        url_tail:gsub("^/branch/?", ""):gsub("^/tag/?", ""),
        res.repo_url
      )
    )
  end

  return res
end

local domain_to_parser = {
  ["github.com"] = Parser.parse_github_url,
  ["gitlab.com"] = Parser.parse_gitlab_url,
  ["gitea.com"] = Parser.parse_gitea_like_url,
  ["codeberg.org"] = Parser.parse_gitea_like_url,
}

---Parses a HTTP repository URL.
---If domain is mapped to a specific parser, use it. Otherwise treat input as
---raw repository URI.
---@param text string
---@return GitDevParsedRepo
function Parser:parse_http(text)
  local domain = text:match "https?://([^/]+)"
  local parser
  if self.extra_domain_to_parser and self.extra_domain_to_parser[domain] then
    parser = self.extra_domain_to_parser[domain]
  elseif vim.fn.has_key(domain_to_parser, domain) == 1 then
    parser = domain_to_parser[domain]
  else
    parser = Parser.parse_raw
  end
  return vim.tbl_deep_extend(
    "keep",
    parser(self, text, domain),
    { type = "http" }
  )
end

---Parses a local repository path.
---Determines whether it is a Git Bundle, local repository or a file in a local
---repository.
---@param path string
---@return GitDevParsedRepo?
function Parser:parse_local_path(path)
  -- Trim optional `file://` scheme
  path = path:gsub("file://", "")

  -- Check if `path` is a git bundle
  if is_git_bundle(path) then
    return { repo_url = path, type = "bundle" }
  end

  -- Find local git repository. `path` can be a git repository or a file in a
  -- git repository. If it is a file, split it into a `repo_url` and
  -- `selected_path`.
  -- Unfortunately, `vim.fs.find` does not track paths when traversing upwards.
  -- The result is not relative to given `path`. The following loop will search
  -- for a parent path that contains `.git` and will also keep track of the path
  -- in which the `.git` directory was found (if any).
  local cur_path, tail = path, ""
  while cur_path ~= "/" and cur_path ~= "." do
    if vim.fn.isdirectory(vim.fs.normalize(cur_path .. "/.git")) == 1 then
      return { repo_url = cur_path, selected_path = tail, type = "local" }
    end
    tail = vim.fs.normalize(vim.fs.basename(cur_path) .. "/" .. tail)
    cur_path = vim.fs.dirname(cur_path)
  end

  -- If we got here, no part of the given path contains `.git`, and thus it is
  -- invalid local git repository path.
  -- return { repo_url = path, type = "raw" }
end

-- Parses the short form of ssh
-- [[user][:password]@]<host>[:port]/<repo>
function Parser:parse_ssh_short(text)
  if text:find "^[%w_-.]*:?.*@?[%w_-.]+:.*" then
    return { repo_url = text, type = "ssh" }
  end
end

-- Parses given text as a short notation.
-- It will prefix the text with default organization if given and text does not
-- contain slashes.
function Parser:parse_with_base_uri(text)
  if not text:match "/" and self.default_org and self.default_org ~= "" then
    text = self.default_org .. "/" .. text
  end
  return { repo_url = self.base_uri_format:format(text), type = "base_uri" }
end

-- "Parses" given text as raw repository.
function Parser:parse_raw(text)
  return { repo_url = text, type = "raw" }
end

---Parses text as git repository URL.
---@param text string
---@return GitDevParsedRepo
function Parser:parse(text)
  -- Strip spaces, query parameters and anchors
  text = text
    :gsub("^%s+", "")
    :gsub("%s+$", "")
    :gsub("#[%w-_.]+$", "") -- clean permalink
    :gsub("%?[%w-_.&=+:]+$", "") -- clean query params

  -- Peek at scheme
  local _, _, scheme = text:find "^(%w+)://"
  if scheme == "http" or scheme == "https" then
    return self:parse_http(text)
  elseif scheme == "file" then
    return self:parse_local_path(text) or {}
  elseif not scheme then
    -- Scheme is not given. It can be either SSH (short form), local path or
    -- short repo name (to be applied to `base_uri_format`).
    -- First, check if `text` corresponds with a local repository, and if not,
    -- check if `text` corresponds with short ssh format.
    local parsed = self:parse_local_path(text) or self:parse_ssh_short(text)
    if parsed then
      return parsed
    end
    -- `text` is probably a short notation to be used with `base_uri_format`
    return self:parse_with_base_uri(text)
  end

  return self:parse_raw(text)
end

return Parser
