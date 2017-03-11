#autobackup.vim
ファイルを保存する度に指定ディレクトリにバックアップを残す。

###概要
*autobackup* はファイルを保存する度に過去のファイルをナンバリングして指定したディレクトリに自動保存するプラグインです。`savevers.vim`をリスペクトして作成されましたが、オリジナルより軽量です。  


##使い方
このプラグインは 'patchmode' で作成されたファイルを`g:autobackup_backup_dir`で指定されたディレクトリにリネームしています。オプション 'patchmode' に空でない文字列を指定してください。'backupdir' も忘れずに設定してください。  

```vim
set patchmode=.vabk
```

'patchmode' の文字列はバックアップファイルの拡張子として使われます。この例ですと、"test.txt" は例えば "test.txt.0001.vabk" や "test.txt.0002.vabk" のような名前でバックアップされます。  

`g:autobackup_mode`を "time" にすれば、通し番号でなく、作成した時間でバックアップを作ることができます。  

```vim
let g:autobackup_mode = "time"
```


バックアップファイル自体をバックアップ対象やファイル名補完から除外するために、 'backupskip' 'wildignore' を設定することができます。  

```vim
exe "set backupskip+=*". &patchmode
exe "set wildignore+=". &patchmode
```
