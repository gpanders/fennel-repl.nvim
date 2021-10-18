; Replace this with a Lua function when Lua funcrefs can be used in callbacks
; (see neovim/neovim#14909)
(vim.cmd "
function! FennelReplCallback(text)
    call luaeval('require(\"fennel-repl\").callback(_A[1], _A[2])', [bufnr(), a:text])
endfunction")

(fn create-window [mods]
  (let [bufnr (vim.api.nvim_create_buf false true)]
    (vim.api.nvim_command (.. mods " new"))
    (vim.api.nvim_win_set_buf 0 bufnr)
    (vim.api.nvim_buf_set_option bufnr :buftype :prompt)
    (vim.api.nvim_buf_set_option bufnr :filetype :fennel)
    (vim.fn.prompt_setcallback bufnr :FennelReplCallback)
    (vim.fn.prompt_setprompt bufnr ">> ")
    (vim.api.nvim_command "startinsert")
    bufnr))

(fn read-chunk []
  (coroutine.yield))

(fn on-values [vals]
  (coroutine.yield (table.concat vals "\t")))

(fn on-error [err-type err lua-src]
  (coroutine.yield (tostring err)))

(fn write [bufnr ...]
  (vim.api.nvim_buf_set_lines bufnr -1 -1 true (vim.split (table.concat [...] " ") "\n")))

; Need to use module-level reference since it's not possible to use a closure
; with prompt_setcallback
(var coro nil)

(fn start [?mods]
  (let [bufnr (create-window (or ?mods ""))
        env (collect [k v (pairs _G)] (values k v))
        _ (tset env :print #(write bufnr $...))
        fennel (require :fennel)
        co (coroutine.create #(fennel.repl {: env
                                            :readChunk read-chunk
                                            :onValues on-values
                                            :onError on-error}))]
    (set coro co)
    (coroutine.resume co)))

(fn callback [bufnr text]
  (let [(result out) (coroutine.resume coro text)]
    (when result
      (write bufnr out)
      (coroutine.resume coro))))

{: start
 : callback}
