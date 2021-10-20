(local fennel (require :fennel))

(local state {:n 1})

; Replace this with a Lua function when Lua funcrefs can be used in callbacks
; (see neovim/neovim#14909)
(vim.cmd "
function! FennelReplCallback(text)
    call luaeval('require(\"fennel-repl\").callback(_A[1], _A[2])', [bufnr(), a:text])
endfunction")

(fn create-buf []
  (let [bufnr (vim.api.nvim_create_buf true true)]
    (vim.api.nvim_buf_set_name bufnr (: "fennel-repl.%d" :format state.n))
    (vim.api.nvim_buf_set_option bufnr :buftype :prompt)
    (vim.api.nvim_buf_set_option bufnr :filetype :fennel)
    (vim.api.nvim_buf_set_option bufnr :complete ".")

    (fn imap [lhs rhs ?opts]
      (let [opts {:noremap true}]
        (each [k v (pairs (or ?opts {}))]
          (tset opts k v))
        (vim.api.nvim_buf_set_keymap bufnr :i lhs rhs opts)))

    (imap "<C-P>" "pumvisible() ? '<C-P>' : '<C-X><C-L>'" {:expr true})
    (imap "<Up>" "pumvisible() ? '<C-P>' : '<C-X><C-L>'" {:expr true})
    (imap "<C-N>" "pumvisible() ? '<C-N>' : '<C-X><C-L>'" {:expr true})
    (imap "<Down>" "pumvisible() ? '<C-N>' : '<C-X><C-L>'" {:expr true})

    (vim.fn.prompt_setcallback bufnr :FennelReplCallback)
    (vim.fn.prompt_setprompt bufnr ">> ")
    (vim.api.nvim_command (: "autocmd BufEnter <buffer=%d> startinsert" :format bufnr))
    bufnr))

(fn create-win [bufnr mods]
  (vim.api.nvim_command (: "%s sbuffer %d" :format mods bufnr))
  (vim.api.nvim_get_current_win))

(fn find-repl-win [bufnr]
  (. (icollect [_ win (ipairs (vim.api.nvim_list_wins))]
       (when (= (vim.api.nvim_win_get_buf win) bufnr)
         win))
     1))

(fn close [bufnr]
  (let [[win] (icollect [_ v (ipairs (vim.api.nvim_list_wins))]
                (when (= (vim.api.nvim_win_get_buf v) bufnr)
                  v))]
    (vim.api.nvim_buf_set_lines bufnr -1 -1 true ["[Process exited]"])
    (vim.api.nvim_buf_set_option bufnr :buftype "")
    (vim.api.nvim_buf_set_option bufnr :modified false)
    (vim.api.nvim_buf_set_option bufnr :modifiable false)
    (vim.api.nvim_win_close win false)
    (set state.n (+ state.n 1))
    (set state.bufnr nil)))

(fn read-chunk [parser-state]
  (let [input (coroutine.yield parser-state.stack-size)]
    (and input (.. input "\n"))))

(fn on-values [vals]
  (coroutine.yield -1 (.. (table.concat vals "\t") "\n")))

(fn on-error [errtype err lua-source]
  (coroutine.yield
    -1
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
  (let [(ok? stack-size out) (coroutine.resume state.coro text)]
    (if (and ok? (= (coroutine.status state.coro) "suspended"))
        (do
          (->> (if (< 0 stack-size) ".." ">> ")
               (vim.fn.prompt_setprompt bufnr))
          (when (> 0 stack-size)
            (write bufnr out)
            (coroutine.resume state.coro)))
        (close bufnr))))

(fn start [?mods]
  (let [bufnr (or state.bufnr (create-buf))
        win (or (find-repl-win bufnr) (create-win bufnr (or ?mods "")))
        env {}
        fenv {}]
    (set state.bufnr bufnr)
    (vim.api.nvim_set_current_win win)
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
      (set state.coro (coroutine.create #(repl {: env
                                                :allowedGlobals false
                                                :pp fennel.view
                                                :readChunk read-chunk
                                                :onValues on-values
                                                :onError on-error})))
      (coroutine.resume state.coro))))

{: start
 : callback}
