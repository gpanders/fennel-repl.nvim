local fennel = require("fennel")
local state = {n = 1}
vim.cmd("\nfunction! FennelReplCallback(text)\n    call luaeval('require(\"fennel-repl\").callback(_A[1], _A[2])', [bufnr(), a:text])\nendfunction")
local function create_buf()
  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_command(("autocmd BufEnter <buffer=%d> startinsert"):format(bufnr))
  do
    local _1_ = bufnr
    vim.api.nvim_buf_set_name(_1_, ("fennel-repl.%d"):format(state.n))
    vim.api.nvim_buf_set_option(_1_, "buftype", "prompt")
    vim.api.nvim_buf_set_option(_1_, "complete", ".")
    vim.api.nvim_buf_set_keymap(_1_, "i", "<C-P>", "pumvisible() ? '<C-P>' : '<C-X><C-L>'", {expr = true, noremap = true})
    vim.api.nvim_buf_set_keymap(_1_, "i", "<Up>", "pumvisible() ? '<C-P>' : '<C-X><C-L>'", {expr = true, noremap = true})
    vim.api.nvim_buf_set_keymap(_1_, "i", "<C-N>", "pumvisible() ? '<C-N>' : '<C-X><C-L>'", {expr = true, noremap = true})
    vim.api.nvim_buf_set_keymap(_1_, "i", "<Down>", "pumvisible() ? '<C-N>' : '<C-X><C-L>'", {expr = true, noremap = true})
    vim.fn.prompt_setcallback(_1_, "FennelReplCallback")
    vim.fn.prompt_setprompt(_1_, ">> ")
    vim.api.nvim_buf_set_option(_1_, "filetype", "fennel")
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
    local tbl_15_auto = {}
    local i_16_auto = #tbl_15_auto
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local val_17_auto
      if (vim.api.nvim_win_get_buf(win) == bufnr) then
        val_17_auto = win
      else
        val_17_auto = nil
      end
      if (nil ~= val_17_auto) then
        i_16_auto = (i_16_auto + 1)
        do end (tbl_15_auto)[i_16_auto] = val_17_auto
      else
      end
    end
    _4_ = tbl_15_auto
  end
  return (_4_)[1]
end
local function close(bufnr)
  local win = find_repl_win(bufnr)
  do
    local _7_ = bufnr
    vim.api.nvim_buf_set_lines(_7_, -1, -1, true, {"[Process exited]"})
    vim.api.nvim_buf_set_option(_7_, "buftype", "")
    vim.api.nvim_buf_set_option(_7_, "modified", false)
    vim.api.nvim_buf_set_option(_7_, "modifiable", false)
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
  local function _9_()
    local _8_ = errtype
    if (_8_ == "Runtime") then
      return (fennel.traceback(tostring(err), 4) .. "\n")
    elseif true then
      local _ = _8_
      return ("%s error: %s\n"):format(errtype, tostring(err))
    else
      return nil
    end
  end
  return coroutine.yield(-1, _9_())
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
    local function _12_()
      if (0 < stack_size) then
        return ".."
      else
        return ">> "
      end
    end
    vim.fn.prompt_setprompt(bufnr, _12_())
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
    local function _15_(...)
      return write(bufnr, ..., "\n")
    end
    env["print"] = _15_
    fenv["xpcall"] = xpcall_2a
    local repl = setfenv(fennel.repl, fenv)
    local function _16_()
      return repl({env = env, allowedGlobals = false, pp = fennel.view, readChunk = read_chunk, onValues = on_values, onError = on_error})
    end
    state.coro = coroutine.create(_16_)
    coroutine.resume(state.coro)
  else
  end
  return bufnr
end
local function start(...)
  vim.notify_once(debug.traceback("fennel-repl.nvim: start() is deprecated in favor of open() and will soon be removed", 2), vim.log.levels.WARN)
  return open(...)
end
return {start = start, open = open, callback = callback}
