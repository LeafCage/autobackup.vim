if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
function! autobackup#pre() "{{{
  if &patchmode == '' || &backupdir == '' || g:autobackup_backup_dir == ''
    return
  end
  let s:bcudir = fnamemodify(g:autobackup_backup_dir, ':p')
  if !isdirectory(s:bcudir) && s:make_bcudir()
    return
  end
  let filename = expand('<afile>:t')
  let dir = fnamemodify(g:autobackup_config_dir, ':p')
  if !(isdirectory(dir) && isdirectory(dir. 'numbers/'))
    call mkdir(dir. '/numbers', 'p')
  end
  let path = dir. '/numbers/'. filename
  let s:num = (filereadable(path) ? get(readfile(path), 0, 0) : 0) + 1
  let s:save_patchmode = &patchmode
  let &patchmode = printf('.%04s%s', s:num, &patchmode)
endfunction
"}}}
function! s:make_bcudir() "{{{
  if mkdir(s:bcudir, 'p')
    let s:bcudir .= '/'
  else
    let g:autobackup_backup_dir = ''
    return 1
  end
endfunction
"}}}
function! autobackup#post() "{{{
  if !exists('s:save_patchmode')
    return
  end
  let base = expand('<afile>:p')
  let patchmodepath = base. &patchmode
  let filename = fnamemodify(base, ':t')
  let bcupath = s:bcudir. filename. &patchmode
  let &patchmode = s:save_patchmode
  if filereadable(bcupath)
    let s:num = s:get_nextnum(filename, s:num+1)
    let bcupath = printf('%s%s.%04s%s', s:bcudir, filename, s:num, &patchmode)
  end
  if filereadable(patchmodepath)
    call rename(patchmodepath, bcupath)
    call writefile([s:num], fnamemodify(g:autobackup_config_dir, ':p'). '/numbers/'. filename)
  end
  unlet! s:save_patchmode s:num
endfunction
"}}}
function! s:get_nextnum(filename, num) "{{{
  let i = a:num
  while filereadable(printf('%s%s.%04s%s', s:bcudir, a:filename, i, &patchmode))
    let i += 1
  endwhile
  return i
endfunction
"}}}

function! autobackup#cmpl_reset_number(arglead, cmdline, csrpos) "{{{
  let cmpl = __autobackup#lim#cmddef#newCmpl(substitute(a:cmdline, '\t', ' ', 'g'), a:csrpos)
  return cmpl.filtered(map(split(globpath(g:autobackup_config_dir. '/numbers/', '*'), '\n'), 'fnamemodify(v:val, ":t")'))
endfunction
"}}}
function! autobackup#reset_number(...) "{{{
  let dir = fnamemodify(g:autobackup_config_dir, ':p'). 'numbers/'
  if a:0 == 1
    for path in split(globpath(dir, a:1), '\n')
      call delete(path)
      echo 'reset: "'. fnamemodify(path, ':t'). '"'
    endfor
    return
  end
  for filename in a:0 ? a:000 : [expand('%:t')]
    if delete(dir. filename)
      echoh WarningMsg | echo 'already reset : "'. filename. '"' | echoh NONE
    else
      echo 'reset: "'. filename. '"'
    end
  endfor
endfunction
"}}}

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
