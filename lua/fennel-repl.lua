local fennel = require("fennel")
local state = {n = 1}
local function create_buf()
  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_create_autocmd("BufEnter", {buffer = bufnr, command = "startinsert"})
  do
    vim.api.nvim_buf_set_name(bufnr, ("fennel-repl.%d"):format(state.n))
    vim.api.nvim_buf_set_option(bufnr, "buftype", "prompt")
    vim.api.nvim_buf_set_option(bufnr, "complete", ".")
    vim.api.nvim_buf_set_keymap(bufnr, "i", "<C-P>", "pumvisible() ? '<C-P>' : '<C-X><C-L>'", {expr = true, noremap = true})
    vim.api.nvim_buf_set_keymap(bufnr, "i", "<Up>", "pumvisible() ? '<C-P>' : '<C-X><C-L>'", {expr = true, noremap = true})
    vim.api.nvim_buf_set_keymap(bufnr, "i", "<C-N>", "pumvisible() ? '<C-N>' : '<C-X><C-L>'", {expr = true, noremap = true})
    vim.api.nvim_buf_set_keymap(bufnr, "i", "<Down>", "pumvisible() ? '<C-N>' : '<C-X><C-L>'", {expr = true, noremap = true})
    local function _1_(_241)
      return callback(bufnr, _241)
    end
    vim.fn.prompt_setcallback(bufnr, _1_)
    vim.fn.prompt_setprompt(bufnr, ">> ")
    vim.api.nvim_buf_set_option(bufnr, "filetype", "fennel")
  end
  return bufnr
end
local function create_win(bufnr, opts)
  local mods = (opts.mods or "")
  vim.api.nvim_command(("%s sbuffer %d"):format(mods, bufnr))
  if opts.height then
    vim.api.nvim_win_set_height(0, opts.height)
  else
  end
  if opts.width then
    vim.api.nvim_win_set_width(0, opts.width)
  else
  end
  return vim.api.nvim_get_current_win()
end
local function find_repl_win(bufnr)
  local _4_
  do
    local tbl_18_auto = {}
    local i_19_auto = 0
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local val_20_auto
      if (vim.api.nvim_win_get_buf(win) == bufnr) then
        val_20_auto = win
      else
        val_20_auto = nil
      end
      if (nil ~= val_20_auto) then
        i_19_auto = (i_19_auto + 1)
        do end (tbl_18_auto)[i_19_auto] = val_20_auto
      else
      end
    end
    _4_ = tbl_18_auto
  end
  return _4_[1]
end
local function close(bufnr)
  local win = find_repl_win(bufnr)
  do
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, true, {"[Process exited]"})
    vim.api.nvim_buf_set_option(bufnr, "buftype", "")
    vim.api.nvim_buf_set_option(bufnr, "modified", false)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  end
  vim.api.nvim_win_close(win, false)
  state.n = (state.n + 1)
  state.bufnr = nil
  return nil
end
local function read_chunk(parser_state)
  local input = coroutine.yield(parser_state["stack-size"])
  return (input and (input .. "\n"))
end
local function on_values(vals)
  return coroutine.yield(-1, (table.concat(vals, "\9") .. "\n"))
end
local function on_error(errtype, err, lua_source)
  local function _7_()
    if (errtype == "Runtime") then
      return (fennel.traceback(tostring(err), 4) .. "\n")
    else
      local _ = errtype
      return ("%s error: %s\n"):format(errtype, tostring(err))
    end
  end
  return coroutine.yield(-1, _7_())
end
local function write(bufnr, ...)
  local text = string.gsub(table.concat({...}, " "), "\\n", "\n")
  local lines = vim.split(text, "\n")
  return vim.api.nvim_buf_set_lines(bufnr, -2, -1, true, lines)
end
local function xpcall_2a(f, err, ...)
  local res = vim.F.pack_len(pcall(f))
  if not res[1] then
    res[2] = err(res[2])
  else
  end
  return vim.F.unpack_len(res)
end
local function callback(bufnr, text)
  local ok_3f, stack_size, out = coroutine.resume(state.coro, text)
  if (ok_3f and (coroutine.status(state.coro) == "suspended")) then
    local function _9_()
      if (0 < stack_size) then
        return ".."
      else
        return ">> "
      end
    end
    vim.fn.prompt_setprompt(bufnr, _9_())
    if (0 > stack_size) then
      write(bufnr, out)
      return coroutine.resume(state.coro)
    else
      return nil
    end
  else
    return close(bufnr)
  end
end
local function open(_3fopts)
  local opts = (_3fopts or {})
  local init_repl_3f = (nil == state.bufnr)
  local bufnr = (state.bufnr or create_buf())
  local win = (find_repl_win(bufnr) or create_win(bufnr, opts))
  local env = {}
  local fenv = {}
  state.bufnr = bufnr
  vim.api.nvim_set_current_win(win)
  if init_repl_3f then
    for k, v in pairs(getfenv(0)) do
      env[k] = v
      fenv[k] = v
    end
    local function _12_(...)
      return write(bufnr, ..., "\n")
    end
    env["print"] = _12_
    fenv["xpcall"] = xpcall_2a
    local repl = setfenv(fennel.repl, fenv)
    local function _13_()
      return repl({env = env, pp = fennel.view, readChunk = read_chunk, onValues = on_values, onError = on_error, allowedGlobals = false})
    end
    state.coro = coroutine.create(_13_)
    coroutine.resume(state.coro)
  else
  end
  return bufnr
end
local function start(...)
  vim.notify_once(debug.traceback("fennel-repl.nvim: start() is deprecated in favor of open() and will soon be removed", 2), vim.log.levels.WARN)
  return open(...)
end
return {start = start, open = open}
