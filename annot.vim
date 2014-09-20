if exists("g:loaded_annot")
        finish
endif
let g:loaded_annot = 1

let s:save_cpo = &cpo
set cpo&vim

function Annot()
        let currentfile = expand("%:p")
        let dir = expand("%:p:h")
        let commandline = "annot -C " . dir .  " list " . currentfile
        let list = system(commandline)
        lgetexpr list
        lopen
endfunction

if !exists(":Annot")
        command Annot :call Annot()
endif

let &cpo = s:save_cpo
unlet s:save_cpo
