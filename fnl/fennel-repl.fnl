(local fennel (require :fennel))

; Need to use module-level reference since it's not possible to use a closure
; with prompt_setcallback
(var coro nil)

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

(fn close [bufnr]
  (vim.api.nvim_buf_set_option bufnr :buftype "")
  (vim.api.nvim_buf_set_lines bufnr -1 -1 true ["[Process exited]"]))

(fn read-chunk []
  (let [input (coroutine.yield true)]
    (and input (.. input "\n"))))

(fn on-values [vals]
  (coroutine.yield false (.. (table.concat vals "\t") "\n")))

(fn on-error [errtype err lua-source]
  (coroutine.yield
    false
    (match errtype
      "Runtime" (.. (fennel.traceback (tostring err) 4) "\n")
      _ (: "%s error: %s\n" :format errtype (tostring err)))))

(fn write [bufnr ...]
  (let [text (-> (table.concat [...] " ") (string.gsub "\\n" "\n"))
        lines (vim.split text "\n")]
    (vim.api.nvim_buf_set_lines bufnr -2 -1 true lines)))

; Coroutines cannot yield across pcall boundaries in Lua 5.1, so we must
; reimplement xpcall for use inside of fennel.repl
(fn xpcall* [f err ...]
  (let [res (vim.F.pack_len (pcall f))]
    (when (not (. res 1))
      (tset res 2 (err (. res 2))))
    (vim.F.unpack_len res)))

(fn callback [bufnr text]
  (let [(ok? reading? out) (coroutine.resume coro text)]
    (if (and ok? (= (coroutine.status coro) "suspended"))
        (do
          (->> (if reading? ".." ">> ")
               (vim.fn.prompt_setprompt bufnr))
          (when (not reading?)
            (write bufnr out)
            (coroutine.resume coro)))
        (close bufnr))))

(fn start [?mods]
  (let [bufnr (create-window (or ?mods ""))
        env {}
        fenv {}]
    ; We need two modified environments: one with a modified xpcall for
    ; fennel.repl and another for the actual code executed inside the REPL. The
    ; latter lets us redirect "print" to the REPL buffer
    (each [k v (pairs (getfenv 0))]
      ; Start by making two copies of the global environment...
      (tset env k v)
      (tset fenv k v))
    ; ...and then modifying each one appropriately
    (tset env :print #(write bufnr $... "\n"))
    (tset fenv :xpcall xpcall*)
    (let [repl (setfenv fennel.repl fenv)]
      (set coro (coroutine.create #(repl {: env
                                          :allowedGlobals false
                                          :readChunk read-chunk
                                          :onValues on-values
                                          :onError on-error})))
      (coroutine.resume coro))))

{: start
 : callback}
