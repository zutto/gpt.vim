scriptencoding utf-8


" job related stuff
" -------------------------
function! s:start_job(cmd, options)
    if has('nvim')
        let options = extend(a:options, {'on_stdout': function('s:nvim_stdproxy'), 'on_stderr': function('s:nvim_stdproxy'), 'on_exit': function('s:nvim_stdproxy')})
        let s:job = jobstart(a:cmd, options)
        let s:ch = s:job
	    return s:job
    endif


    let options = {'in_mode': 'json', 'out_mode': 'nl', 'noblock': 1}
    let s:job = job_start(a:cmd, options)
    let s:ch = s:get_channel(s:job)
    call ch_setoptions(s:ch, {'out_cb': function('s:stdout'), 'err_cb': function('s:stderr'), 'close_cb': function('s:stdexit')})
    return s:ch
endfunction


function! s:start_completion(cmd, options)
    if has('nvim')
        let options = extend(a:options, {'on_stdout': function('s:nvim_completionproxy'), 'on_stderr': function('s:nvim_completionproxy'), 'on_exit': function('s:nvim_completionproxy')})
        let s:completion = jobstart(a:cmd, options)
        let s:ch_completion = s:completion
	    return s:completion
    endif


    let options = {'in_mode': 'json', 'out_mode': 'nl', 'noblock': 1}
    let s:job = job_start(a:cmd, options)
    let s:ch_completion = s:get_channel(s:job)
    call ch_setoptions(s:ch_completion, {'out_cb': function('s:streamPrinter'), 'err_cb': function('s:stderr'), 'close_cb': function('s:stdexit')})
    return s:ch_completion
endfunction


function! s:get_channel(job) abort
    if has('nvim')
        return a:job
    endif 
    return job_getchannel(a:job)
endfunction

function! s:send_raw(ch, msg) abort
    if has('nvim')
        call chansend(a:ch, a:msg)
    else
        call ch_sendraw(a:ch, a:msg)
    endif
endfunction

function! s:job_status(job) abort
    if has('nvim')
        " emulate vim
        return jobpid(a:job) > 0 ? 'run' : 'dead' 
    endif
    return job_status(a:job)
endfunction

" ----------------------------------------


" chat output functions
" --------------------------

function! s:print(msg) abort
   if empty(a:msg) || a:msg == "None"
        return
    endif
            
    try
        let l:msg = json_decode(a:msg)
        if empty(l:msg)
            return
        endif
    catch " json is sometimes empty or corrupted..
        call s:stderr(printf('Failed to decode json!\n%s', a:msg))
        return
    endtry
       

    let l:winid = bufwinid('__gpt__')
    if l:winid < 1
        silent noautocmd vsplit __gpt__
        setlocal buftype=nofile bufhidden=wipe noswapfile wrap nonumber signcolumn=no filetype=markdown
        wincmd p
        let l:winid = bufwinid('__gpt__')
    endif
        
    call win_execute(l:winid, 'setlocal modifiable', 1)
    call win_execute(l:winid, 'silent normal! GA' .. l:msg['text'], 1)
      
    if !empty(l:msg['error'])
        call win_execute(l:winid, 'silent normal! Go' .. l:msg['error'], 1)
    elseif l:msg['eof']
        call win_execute(l:winid, 'silent normal! Go', 1)
    elseif !empty(l:msg['notification'])
        echom printf('notification: %s', l:msg['notification'])
    fi

 
    endif
        
    call win_execute(l:winid, 'setlocal nomodifiable nomodified', 1)
endfunction

function! s:nvim_stdproxy(ch, msg, event) abort
    try
        "echo a:msg
        for msg in a:msg
            if a:event ==# 'stdout'
                call s:stdout("", msg)
            elseif a:event ==# 'stderr'
                call s:stderr(msg)
            else
                call s:stdexit("", msg)
            endif
        endfor
    catch
        return
    endtry
endfunction

function! s:stdout(ch, msg) abort
    call s:print(a:msg)
endfunction

function! s:stderr(msg) abort
    call s:print(json_encode({'eof': 0, 'error': '', 'text': printf('[ERROR]>>> %s\n', a:msg), 'notification': ''}))
endfunction

function! s:stdexit(ch, msg) abort
    call s:print(json_encode({'eof': 0, 'error': '', 'text': printf('[EXIT]>>> %s\n', a:msg), 'notification': ''}))
endfunction


" ------------

" streaming completion output
" -------------------

let s:printjob = -1 " printing job active
let s:startline = -1 
let s:startcol = -1
let s:jobcontents = []
let s:winid = -1


function! s:posTracker() abort
    let l:ret = {}
    let l:lines = count(join(s:jobcontents, ""), "\n")
    "call substitute(join(s:jobcontents, ""), "\\n", '\=execute("let s:lines = s:lines + 1")', 'g')
    let l:ret.line = (l:lines + s:startline)
    echom l:lines
    let l:ret.column = ((len(split(join(s:jobcontents, "").".", "\n")[-1]) - 1) + s:startcol) - 1
    if l:ret.column < 0
        let l:ret.column = 1
    endif

    echom s:jobcontents
    echom l:ret
    return l:ret
endfunction


function! s:streamPrinter(ch, contents) abort
      if s:startline < 0 || s:printjob < 0 || s:winid < 0 || s:startcol < 0
          return
      endif
    


    if empty(a:contents) || a:contents == "None"
        return
    endif
            
    try
        let l:msg = json_decode(a:contents)
        if empty(l:msg)
            return
        endif
    catch " json is sometimes empty or corrupted..
        call s:stderr(printf('Failed to decode json!\n%s', a:contents))
        return
    endtry
 

    if l:msg["eof"]
        let s:printjob = -1
        let s:startline = -1
        let s:startcol = -1
        unlet s:jobcontents
        let s:jobcontents = []
        let s:winid = -1
        return
    endif

    if l:msg['notification']
        echom printf('notification: %s', l:msg['notification'])
    fi


    let l:lines = len(split(join(s:jobcontents), "\n"))
   

    let l:pos = s:posTracker()
    call win_execute(s:winid, printf('%dnormal! %d|a%s', l:pos["line"], l:pos["column"], l:msg["text"]), 1)
    call win_execute(s:winid, "redraw", 1)
    
    call add(s:jobcontents, l:msg["text"])
endfunction

function! s:nvim_completionproxy(ch, msg, event) abort
    try
        for msg in a:msg
            if a:event ==# 'stdout'
                call s:streamPrinter("", msg)
            elseif a:event ==# 'stderr'
                call s:stderr(msg)
            else
                call s:stdexit("", msg)
            endif
        endfor
    catch
        return
    endtry
endfunction


" vim interface
" ---------------

function! gpt#send(range, text, model) abort


    if a:range > 0
        let l:yanked_text = s:get_visual_selection()

        if !empty(l:yanked_text)
            let l:yanked_text = join(['Context:', '```', l:yanked_text, "```"], "\n")
            "let l:lines = join([a:text, join(['```', l:yanked_text, "```"], "\n")], "\n")
            let l:lines = join([a:text, join([l:yanked_text], "\n")], "\n")
        else
            let l:lines = a:text
        endif
    else
            let l:lines = a:text
    endif
    
    
    
    if !exists('s:job') || s:job_status(s:job) !=# 'run'
        let l:ch = s:start_job(get(g:, 'chatgpt_bin', ['python3.11', '/usr/local/bin/chatgpt']), {})
    else
        let l:ch = s:ch
    endif

    let l:role = get(g:, "chatgpt_role", "")
    let l:model = empty(a:model) ? g:model : a:model

    call s:print(json_encode({'eof': 0, 'error': '', 'text': printf(">>> %s\n>>>\n", l:lines), 'notification': ''}))
    call s:send_raw(l:ch, printf("%s\n", json_encode({'model': l:model, 'text': l:lines, 'role': l:role, "session": "chat"})))
endfunction

function! gpt#reset() abort
endfunction

function! gpt#complete(text, model) abort
"    call s:print(json_encode({'eof': 0, 'error': '', 'text': printf(">>> %s\n", a:text) }))

    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let l:yanked_text = s:get_visual_selection()
    let l:content = join([a:text, join([l:yanked_text], "\n")], "\n")
    
    "[0] = line [1] = column
    let s:winid = bufwinid('%')
    let s:printjob = 1
    let s:startline = line_start 
    let s:startcol = column_start


    "destroy before beginning
    

    let lines = max([line_start, line_end]) - min([line_start, line_end])
    if lines < 1 
        if column_start != column_end
            call win_execute(s:winid, "normal! gvd", 1)
        endif
        " no auto completion, just insertion
    else
        "call win_execute(s:winid, "'<,'>d | put! =''", 1)
        call win_execute(s:winid, "'<,'>d | put! =''", 1)

    endif
   
    if !exists('s:completion') || s:job_status(s:completion) !=# 'run'
        let l:ch = s:start_completion(get(g:, 'chatgpt_bin', ['python3.11', '/usr/local/bin/chatgpt']), {})
    else
        let l:ch = s:ch_completion
    endif

    let l:role = get(g:, "chatgpt_role_completion", "")

    let l:model = empty(a:model) ? g:model : a:model
    call s:send_raw(l:ch, printf("%s\n", json_encode({'model': l:model, 'text': l:content, 'role': l:role, "session": "completion"})))
endfunction

"vim.api.nvim_buf_set_lines(vim.api.nvim_get_current_buf(), min, max, false, lines);
"call setline(145, join([join(getline(145,145)), "<- test"], ""))
"def render_text_chunks(chunks):
"    generating_text = False
"    full_text = ''
"    for text in chunks:
"        if not text.strip() and not generating_text:
"            continue # trim newlines from the beginning
"        generating_text = True
"        vim.command("normal! a" + text)
"        vim.command("undojoin")
"        vim.command("redraw")
"        full_text += text



function! s:get_visual_selection()
    " Why is this not a built-in Vim script function?!
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]
    return join(lines, "\n")
endfunction


function! gpt#set_role(text) abort
 let g:chatgpt_role = a:text
  call s:print(json_encode({'eof': 0, 'error': '', 'text': printf(">>> Set role to: %s\n", a:text) , 'notification': ''})) 
endfunction


