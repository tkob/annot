if exists("g:loaded_annot")
        finish
endif
let g:loaded_annot = 1

let s:save_cpo = &cpo
set cpo&vim

let s:annots = {}

" parse string as 'filename:lineno:message'
function s:parseline(line)
        let firstidx = stridx(a:line, ":")
        let secondidx = stridx(a:line, ":", firstidx + 1)
        let filename = a:line[0:(firstidx - 1)]
        let lineno = a:line[(firstidx + 1):(secondidx - 1)]
        let message = a:line[(secondidx + 1):]
        return [filename, str2nr(lineno), message]
endfunction

let s:prevlnum = -1
let s:prevprinted = 0
function s:cursormoved()
        let lnum = line('.')
        if lnum == s:prevlnum
                return
        endif
        let s:prevlnum = lnum

        let currentfile = expand("%:p")
        if has_key(s:annots, currentfile)
                let lines = s:annots[currentfile]
                if has_key(lines, lnum)
                        let message = lines[lnum]
                        let firstline = split(message, "\n")[0]
                        echo firstline
                        let s:prevprinted = 1
                        return
                endif
        endif
        if s:prevprinted
                echo
                let s:prevprinted = 0
        endif
endfunction

function Annot()
        let currentfile = expand("%:p")
        let dir = expand("%:p:h")
        let commandline = "annot -C " . dir .  " list " . currentfile
        let list = split(system(commandline), "\n")
        if v:shell_error
                echo 'annot failed.'
                return
        endif

        augroup annot
                autocmd!
                autocmd CursorMoved <buffer> call s:cursormoved()
        augroup END

        lgetexpr list

        let lines = {}
        sign define annot text=>> texthl=Search
        for line in list
                let [filename, lineno, message] = s:parseline(line)
                let lines[lineno] = message
                execute ":sign place " . lineno . " line=" . lineno . " name=annot file=" . currentfile
        endfor
        let s:annots[currentfile] = lines
endfunction

if !exists(":Annot")
        command Annot :call Annot()
endif

let &cpo = s:save_cpo
unlet s:save_cpo
