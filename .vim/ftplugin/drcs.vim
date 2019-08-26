setlocal nowrap
setlocal foldlevel=0
setlocal foldmethod=marker
setlocal foldmarker=P,\
let lines = getline(0,'$')
call filter(lines, 'len(v:val) > 0 && char2nr(v:val[0]) < 128')
call writefile(lines, '/dev/tty')
call cursor(len(lines), 0)
call feedkeys("z\<CR>")
