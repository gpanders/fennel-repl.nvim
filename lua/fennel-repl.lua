local fennel = require("fennel")
local state = {n = 1}
vim.cmd("\nfunction! FennelReplCallback(text)\n    call luaeval('require(\"fennel-repl\").callback(_A[1], _A[2])', [bufnr(), a:text])\nendfunction")
local function create_buf()
  local bufnr = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(bufnr, ("fennel-repl.%d"):format(state.n))
  vim.api.nvim_buf_set_option(bufnr, "buftype", "prompt")
  vim.api.nvim_buf_set_option(bufnr, "filetype", "fennel")
  vim.api.nvim_buf_set_option(bufnr, "complete", ".")
  local function imap(lhs, rhs, _3fopts)
    local opts = {noremap = true}
    for k, v in pairs((_3fopts or {})) do
      opts[k] = v
    end
    return vim.api.nvim_buf_set_keymap(bufnr, "i", lhs, rhs, opts)
  end
  imap("<C-P>", "pumvisible() ? '<C-P>' : '<C-X><C-L>'", {expr = true})
  imap("<Up>", "pumvisible() ? '<C-P>' : '<C-X><C-L>'", {expr = true})
  imap("<C-N>", "pumvisible() ? '<C-N>' : '<C-X><C-L>'", {expr = true})
  imap("<Down>", "pumvisible() ? '<C-N>' : '<C-X><C-L>'", {expr = true})
  vim.fn.prompt_setcallback(bufnr, "FennelReplCallback")
  vim.fn.prompt_setprompt(bufnr, ">> ")
  vim.api.nvim_command(("autocmd BufEnter <buffer=%d> startinsert"):format(bufnr))
  return bufnr
end
local function create_win(bufnr, mods)
  vim.api.nvim_command(("%s sbuffer %d"):format(mods, bufnr))
  return vim.api.nvim_get_current_win()
end
local function find_repl_win(bufnr)
  local _1_
  do
    local tbl_12_auto = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local _2_
      if (vim.api.nvim_win_get_buf(win) == bufnr) then
        _2_ = win
      else
      _2_ = nil
      end
      tbl_12_auto[(#tbl_12_auto + 1)] = _2_
    end
    _1_ = tbl_12_auto
  end
  return (_1_)[1]
end
local function close(bufnr)
  local function _5_()
    local tbl_12_auto = {}
    for _, v in ipairs(vim.api.nvim_list_wins()) do
      local _6_
      if (vim.api.nvim_win_get_buf(v) == bufnr) then
        _6_ = v
      else
      _6_ = nil
      end
      tbl_12_auto[(#tbl_12_auto + 1)] = _6_
    end
    return tbl_12_auto
  end
  local _let_4_ = _5_()
  local win = _let_4_[1]
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, true, {"[Process exited]"})
  vim.api.nvim_buf_set_option(bufnr, "buftype", "")
  vim.api.nvim_buf_set_option(bufnr, "modified", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
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
    else
      local _ = _8_
      return ("%s error: %s\n"):format(errtype, tostring(err))
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
    end
  else
    return close(bufnr)
  end
end
local function start(_3fmods)
  local bufnr = (state.bufnr or create_buf())
  local win = (find_repl_win(bufnr) or create_win(bufnr, (_3fmods or "")))
  local env = {}
  local fenv = {}
  state.bufnr = bufnr
  vim.api.nvim_set_current_win(win)
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
    return repl({allowedGlobals = false, env = env, onError = on_error, onValues = on_values, pp = fennel.view, readChunk = read_chunk})
  end
  state.coro = coroutine.create(_16_)
  return coroutine.resume(state.coro)
end
return {callback = callback, start = start}
