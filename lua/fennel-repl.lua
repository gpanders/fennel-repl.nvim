local fennel = require("fennel")
local coro = nil
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
  local input = coroutine.yield()
  return (input and (input .. "\n"))
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
local function callback(bufnr, text)
  local result, out = coroutine.resume(coro, text)
  if result then
    write(bufnr, out)
  end
  return coroutine.resume(coro)
end
local function start(_3fmods)
  local bufnr = create_window((_3fmods or ""))
  local env
  do
    local tbl_9_auto = {}
    for k, v in pairs(_G) do
      local _2_, _3_ = k, v
      if ((nil ~= _2_) and (nil ~= _3_)) then
        local k_10_auto = _2_
        local v_11_auto = _3_
        tbl_9_auto[k_10_auto] = v_11_auto
      end
    end
    env = tbl_9_auto
  end
  local function _5_(...)
    return write(bufnr, ...)
  end
  env["print"] = _5_
  local function _6_()
    return fennel.repl({env = env, onError = on_error, onValues = on_values, readChunk = read_chunk})
  end
  coro = coroutine.create(_6_)
  return coroutine.resume(coro)
end
return {callback = callback, start = start}
