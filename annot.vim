if exists("g:loaded_annot")
        finish
endif
let g:loaded_annot = 1

let s:save_cpo = &cpo
set cpo&vim

" parse string as 'filename:lineno:message'
function s:parseline(line)
        let firstidx = stridx(a:line, ":")
        let secondidx = stridx(a:line, ":", firstidx + 1)
        let filename = a:line[0:(firstidx - 1)]
        let lineno = a:line[(firstidx + 1):(secondidx - 1)]
        let message = a:line[(secondidx + 1):]
        return [filename, lineno, message]
endfunction

function Annot()
        let currentfile = expand("%:p")
        let dir = expand("%:p:h")
        let commandline = "annot -C " . dir .  " list " . currentfile
        let list = split(system(commandline), "\n")
        lgetexpr list
        lopen
        sign define annot text=>> texthl=Search
        for line in list
                let [filename, lineno, message] = s:parseline(line)
                execute ":sign place " . lineno . " line=" . lineno . " name=annot file=" . currentfile
        endfor
endfunction

if !exists(":Annot")
        command Annot :call Annot()
endif

let &cpo = s:save_cpo
unlet s:save_cpo
