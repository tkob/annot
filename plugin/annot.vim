if exists("g:loaded_annot")
        finish
endif
let g:loaded_annot = 1

let s:save_cpo = &cpo
set cpo&vim

let s:annots = {}

function s:has_annotation(file, lnum)
        if has_key(s:annots, a:file)
                let lines = s:annots[a:file]
                if has_key(lines, a:lnum)
                        return 1
                endif
        endif
        return 0
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
        if s:has_annotation(currentfile, lnum)
                let message = s:annots[currentfile][lnum]
                let messagelines = split(message, "\n")
                if len(messagelines) != 0
                        let firstline = messagelines[0]
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

function s:makelocations(lines)
        let list = []
        for line in a:lines
                let [filename, lineno, message] = line
                call add(list, join(line, ":"))
        endfor
        lgetexpr list
endfunction

function Annot()
        let currentfile = expand("%:p")
        let dir = expand("%:p:h")
        let commandline = "annot -C " . dir .  " list -p vim " . currentfile
        let result = system(commandline)
        if v:shell_error
                echo 'annot failed.'
                return
        endif
        let lines = eval(result)

        augroup annot
                autocmd!
                autocmd CursorMoved <buffer> call s:cursormoved()
        augroup END

        call s:makelocations(lines)

        let lineDict = {}
        sign define annot text=>> texthl=Search
        for line in lines
                let [filename, lineno, message] = line
                let lineDict[lineno] = message
                execute ":sign place " . lineno . " line=" . lineno . " name=annot file=" . currentfile
        endfor
        let s:annots[currentfile] = lineDict
endfunction

if !exists(":Annot")
        command Annot :call Annot()
endif

let &cpo = s:save_cpo
unlet s:save_cpo
