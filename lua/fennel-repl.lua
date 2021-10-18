vim.cmd("\nfunction! FennelReplCallback(text)\n    call luaeval('require(\"fennel-repl\").callback(_A[1], _A[2])', [bufnr(), a:text])\nendfunction")
local function create_window(mods)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_command((mods .. " new"))
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "prompt")
  vim.api.nvim_buf_set_option(bufnr, "filetype", "fennel")
  vim.fn.prompt_setcallback(bufnr, "FennelReplCallback")
  vim.fn.prompt_setprompt(bufnr, ">> ")
  vim.api.nvim_command("startinsert")
  return bufnr
end
local function read_chunk()
  return coroutine.yield()
end
local function on_values(vals)
  return coroutine.yield(table.concat(vals, "\9"))
end
local function on_error(err_type, err, lua_src)
  return coroutine.yield(tostring(err))
end
local function write(bufnr, ...)
  return vim.api.nvim_buf_set_lines(bufnr, -1, -1, true, vim.split(table.concat({...}, " "), "\n"))
end
local coro = nil
local function start(_3fmods)
  local bufnr = create_window((_3fmods or ""))
  local env
  do
    local tbl_9_auto = {}
    for k, v in pairs(_G) do
      local _1_, _2_ = k, v
      if ((nil ~= _1_) and (nil ~= _2_)) then
        local k_10_auto = _1_
        local v_11_auto = _2_
        tbl_9_auto[k_10_auto] = v_11_auto
      end
    end
    env = tbl_9_auto
  end
  local _
  local function _4_(...)
    return write(bufnr, ...)
  end
  env["print"] = _4_
  _ = nil
  local fennel = require("fennel")
  local co
  local function _5_()
    return fennel.repl({env = env, onError = on_error, onValues = on_values, readChunk = read_chunk})
  end
  co = coroutine.create(_5_)
  coro = co
  return coroutine.resume(co)
end
local function callback(bufnr, text)
  local result, out = coroutine.resume(coro, text)
  if result then
    write(bufnr, out)
    return coroutine.resume(coro)
  end
end
return {callback = callback, start = start}
