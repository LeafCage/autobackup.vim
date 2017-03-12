if expand('<sfile>:p')!=#expand('%:p') && exists('g:loaded_autobackup')| finish| endif| let g:loaded_autobackup = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:autobackup_pattern = get(g:, 'autobackup_pattern', '*')
let g:autobackup_backup_dir = get(g:, 'autobackup_backup_dir', '~/.backup/vim-autobackup')
let g:autobackup_config_dir = get(g:, 'autobackup_config_dir', '~/.config/vim/autobackup')

if g:autobackup_pattern==''
  finish
elseif g:autobackup_pattern !~ '^\%(\f\|[,\*]\)\+$'
  echoerr 'invalid pattern g:autobackup_pattern : '. g:autobackup_pattern
  finish
end
augroup autobackup
   autocmd!
   exe 'au BufWritePre,FileWritePre,FileAppendPre' g:autobackup_pattern 'call autobackup#pre()'
   exe 'au BufWritePost,FileWritePost,FileAppendPost' g:autobackup_pattern 'call autobackup#post()'
augroup END

command! -nargs=*  -complete=customlist,autobackup#cmpl_reset_number AbakResetNumber call autobackup#reset_number(<f-args>)
"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
