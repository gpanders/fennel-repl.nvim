local fennel = require("fennel")
local coro = nil
vim.cmd("\nfunction! FennelReplCallback(text)\n    call luaeval('require(\"fennel-repl\").callback(_A[1], _A[2])', [bufnr(), a:text])\nendfunction")
local function create_window(mods)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_command((mods .. " new"))
  vim.api.nvim_win_set_buf(0, bufnr)
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
  vim.api.nvim_command("startinsert")
  return bufnr
end
local function close(bufnr)
  local function _2_()
    local tbl_12_auto = {}
    for _, v in ipairs(vim.api.nvim_list_wins()) do
      local _3_
      if (vim.api.nvim_win_get_buf(v) == bufnr) then
        _3_ = v
      else
      _3_ = nil
      end
      tbl_12_auto[(#tbl_12_auto + 1)] = _3_
    end
    return tbl_12_auto
  end
  local _let_1_ = _2_()
  local win = _let_1_[1]
  vim.api.nvim_buf_set_option(bufnr, "modified", false)
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, true, {"[Process exited]"})
  return vim.api.nvim_win_close(win, false)
end
local function read_chunk(parser_state)
  local input = coroutine.yield(parser_state["stack-size"])
  return (input and (input .. "\n"))
end
local function on_values(vals)
  return coroutine.yield(-1, (table.concat(vals, "\9") .. "\n"))
end
local function on_error(errtype, err, lua_source)
  local function _6_()
    local _5_ = errtype
    if (_5_ == "Runtime") then
      return (fennel.traceback(tostring(err), 4) .. "\n")
    else
      local _ = _5_
      return ("%s error: %s\n"):format(errtype, tostring(err))
    end
  end
  return coroutine.yield(-1, _6_())
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
  local ok_3f, stack_size, out = coroutine.resume(coro, text)
  if (ok_3f and (coroutine.status(coro) == "suspended")) then
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
      return coroutine.resume(coro)
    end
  else
    return close(bufnr)
  end
end
local function start(_3fmods)
  local bufnr = create_window((_3fmods or ""))
  local env = {}
  local fenv = {}
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
    return repl({allowedGlobals = false, env = env, onError = on_error, onValues = on_values, pp = fennel.view, readChunk = read_chunk})
  end
  coro = coroutine.create(_13_)
  return coroutine.resume(coro)
end
return {callback = callback, start = start}
