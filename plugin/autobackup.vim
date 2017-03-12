if expand('<sfile>:p')!=#expand('%:p') && exists('g:loaded_autobackup')| finish| endif| let g:loaded_autobackup = 1
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let g:autobackup_backup_dir = get(g:, 'autobackup_backup_dir', '~/.backup/vim-autobackup')
let g:autobackup_backup_limit = get(g:, 'autobackup_backup_limit', 100)
let g:autobackup_config_dir = get(g:, 'autobackup_config_dir', '~/.config/vim/autobackup')

augroup autobackup
   autocmd!
   au BufWritePre,FileWritePre,FileAppendPre * call autobackup#pre()
   au BufWritePost,FileWritePost,FileAppendPost * call autobackup#post()
augroup END

"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
