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


" output functions
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
        silent noautocmd split __gpt__
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
    endif
        
    call win_execute(l:winid, 'setlocal nomodifiable nomodified', 1)
endfunction

function! s:nvim_stdproxy(ch, msg, event) abort
    try
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
    call s:print(json_encode({'eof': 0, 'error': '', 'text': printf('[ERROR]>>> %s\n', a:msg)}))
endfunction

function! s:stdexit(ch, msg) abort
    call s:print(json_encode({'eof': 0, 'error': '', 'text': printf('[EXIT]>>> %s\n', a:msg)}))
endfunction


" ------------



" vim interface
" ---------------

function! gpt#send(text, model) abort
    call s:print(json_encode({'eof': 0, 'error': '', 'text': printf(">>> %s\n", a:text) }))


    let l:yanked_text = s:get_visual_selection()
    let l:lines = join([a:text, l:yanked_text], "")
    
    
    if !exists('s:job') || s:job_status(s:job) !=# 'run'
        let l:ch = s:start_job(get(g:, 'chatgpt_bin', ['python3.11', '/usr/local/bin/chatgpt']), {})
    else
        let l:ch = s:ch
    end

    let l:role = get(g:, "chatgpt_role", "")

    call s:send_raw(l:ch, printf("%s\n", json_encode({'model': a:model, 'text': l:lines, 'role': l:role})))
endfunction



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
  call s:print(json_encode({'eof': 0, 'error': '', 'text': printf(">>> Set role to: %s\n", a:text) })) 
endfunction


