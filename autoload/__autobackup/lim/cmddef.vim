if exists('s:save_cpo')| finish| endif
let s:save_cpo = &cpo| set cpo&vim
scriptencoding utf-8
"=============================================================================
let s:TYPE_LIST = type([])
let s:TYPE_STR = type('')
let s:TYPE_NUM = type(0)
let s:TYPE_FLOAT = type(0.0)

function! s:remove_cmdrange(cmdline) "{{{
  return substitute(a:cmdline, '^[,; ]*\%(\%(\d\+\|[.$%]\|\\[/?&]\|/.\{-}/\|?.\{-}?\|''[''`"^.<>()[\]{}[:alnum:]]\)\s*\%([+-]\d*\s*\)\?[,; ]*\)*', '', '')
endfunction
"}}}
function! s:_matches(pat, list) "{{{
  if type(a:pat)==s:TYPE_LIST
    return filter(a:list, 'index(a:pat, v:val)!=-1')
  end
  return filter(a:list, 'v:val =~ a:pat')
endfunction
"}}}
function! s:divisionholder(holder, divisions) "{{{
  for division in a:divisions
    let type = type(division)
    if type==s:TYPE_LIST
      call s:divisionholder(a:holder, division)
    elseif type==s:TYPE_STR
      if division!=''
        let a:holder[division] = 1
      end
    elseif type==s:TYPE_NUM || type==s:TYPE_FLOAT
      let a:holder[string(division)] = 1
    end
    unlet division
  endfor
  return a:holder
endfunction
"}}}
let s:Assorter = {}
function! s:newAssorter(inputs) "{{{
  let obj = copy(s:Assorter)
  let obj.inputs = a:inputs
  let obj.should_del_groups = {}
  let obj.candidates = []
  let obj.divisions = []
  return obj
endfunction
"}}}
function! s:Assorter.assort_candidates(candidates) "{{{
  for cand in a:candidates
    let type = type(cand)
    if type!=s:TYPE_LIST
      let cnd = type==s:TYPE_STR ? cand : string(cand)
      if cnd!='' && index(self.inputs, cnd)==-1
        call self._add([cnd], [{}])
      end
    elseif cand!=[]
      call self._assort_listcand(cand)
    end
    unlet cand
  endfor
endfunction
"}}}
function! s:Assorter._assort_listcand(cand) "{{{
  let type = type(a:cand[0])
  if !(type==s:TYPE_NUM || type==s:TYPE_FLOAT || type==s:TYPE_STR && a:cand[0]!='')
    return
  end
  let cnd = type==s:TYPE_STR ? a:cand[0] : string(a:cand[0])
  let division = s:divisionholder({}, a:cand[1:])
  if cnd!='' && index(self.inputs, cnd)==-1
    call self._add([cnd], [division])
    return
  end
  call extend(self.should_del_groups, division)
  if has_key(division, '__PARM')
    call self._add([cnd], [division])
  end
endfunction
"}}}
function! s:Assorter._add(cand, division) "{{{
  let self.candidates += a:cand
  let self.divisions += a:division
endfunction
"}}}
function! s:Assorter.remove_del_grouped_candidates() "{{{
  if has_key(self.should_del_groups, '__PARM')
    unlet self.should_del_groups.__PARM
  end
  if self.should_del_groups!={}
    let divisions = self.divisions
    call filter(self.candidates, 'has_key(divisions[v:key], "__PARM") || !('. join(map(keys(self.should_del_groups), '"has_key(divisions[v:key], ''". v:val. "'')"'), '||'). ')')
  end
  return self.candidates
endfunction
"}}}

let s:func = {}
function! s:func._get_optignorepat() "{{{
  return '^\%('.self._shortoptbgn.'\|'.self._longoptbgn.'\)\S'
endfunction
"}}}
function! s:func._get_arg(pat, variadic, list) "{{{
  let type = type(a:pat)
  if type==s:TYPE_STR
    let default = get(a:variadic, 0, '')
    let idx = match(a:list, a:pat)
    return idx==-1 ? default : matchstr(a:list[idx], a:pat)
  elseif type==s:TYPE_LIST
    let [idx, default] = s:_solve_variadic_for_set_default(a:variadic, [0, ''])
    return get(filter(copy(a:list), 'index(a:pat, v:val)!=-1'), idx, default)
  end
  let [is_ignoreopt, default] = s:_solve_variadic_for_set_default(a:variadic, [0, ''])
  let list = copy(a:list)
  if is_ignoreopt
    let ignorepat = self._get_optignorepat()
    call filter(list, 'v:val !~# ignorepat')
  end
  return get(list, a:pat, default)
endfunction
"}}}
function! s:_solve_variadic_for_set_default(variadic, default) "{{{
  let [num, default] = a:default
  for val in a:variadic
    if type(val)==s:TYPE_STR
      let default = val
    else
      let num = val
    end
    unlet val
  endfor
  return [num, default]
endfunction
"}}}

function! s:func._solve_longopt_nomal(pat) "{{{
  let i = match(self.args, '^'.a:pat. self._endpat, self._first)
  if i==-1 || i > self._last
    return ['', 0]
  end
  call self._adjust_ranges()
  let optval = substitute(remove(self.args, i), '^'. a:pat, '', '')
  return optval=='' ?  [1, 1] : [substitute(optval, '^'. self.assign, '', ''), 1]
endfunction
"}}}
function! s:func._solve_shortopt_normal(pat) "{{{
  let shortchr = matchstr(a:pat, '^'.self._shortoptbgn.'\zs.$')
  let i = match(self.args, printf('^\%%(%s\)\@!\&^%s.\{-}%s.\{-}%s', self._longoptbgn, self._shortoptbgn, shortchr, self._endpat), self._first)
  if i==-1 || i > self._last
    return ['', 0]
  end
  let optval = matchstr(self.args[i], shortchr. '\zs'. self.assign.'.*$')
  let self.args[i] = substitute(self.args[i], '^'. self._shortoptbgn.'.\{-}\zs'.shortchr. (optval=='' ? '' : self.assign.'.*'), '', '')
  if self.args[i] ==# self._shortoptbgn
    unlet self.args[i]
    call self._adjust_ranges()
  end
  return optval=='' ? [1, 1] : [substitute(optval, '^'. self.assign, '', ''), 1]
endfunction
"}}}
function! s:func._solve_whitespace(pat) "{{{
  let i = index(self.args, a:pat, self._first)
  if i==-1 || i > self._last
    return ['', 0]
  end
  call self._adjust_ranges()
  if self.__take_val && i <= self._last
    let next = self.args[i+1]
    if next !~ '^\%('. self._longoptbgn. '\|'. self._shortoptbgn. '\)'
      let optval = self.args[i+1]
      unlet self.args[i : i+1]
      call self._adjust_ranges()
      return [optval, 1]
    end
  end
  unlet self.args[i]
  return [1, 1]
endfunction
"}}}


"=============================================================================
"Main:
function! __autobackup#lim#cmddef#split_into_words(cmdline) "{{{
  return split(a:cmdline, '\%(\%([^\\]\|^\)\\\)\@<!\s\+')
endfunction
"}}}
function! __autobackup#lim#cmddef#continuable() "{{{
  return exists('s:save_context')
endfunction
"}}}
function! __autobackup#lim#cmddef#continue() "{{{
  if !exists('s:save_context')
    return
  end
  let context = s:save_context
  unlet s:save_context
  let &wcm = context.wcm
  return context.candidates
endfunction
"}}}

let s:Cmpl = {}
function! __autobackup#lim#cmddef#newCmpl(cmdline, cursorpos, ...) abort "{{{
  let obj = copy(s:Cmpl)
  let behavior = a:0 ? a:1 : {}
  let obj._longoptbgn = get(behavior, 'longoptbgn', '--')
  let obj._shortoptbgn = get(behavior, 'shortoptbgn', '-')
  let obj.is_cmdwin = exists('*getcmdwintype') ? getcmdwintype()!='' : bufname('%') ==# '[Command Line]'
  if v:version > 703 || v:version==703 && has('patch1260') || !obj.is_cmdwin
    let obj.cmdline = a:cmdline
    let obj.cursorpos = a:cursorpos
  else
    let cursorpos = col('.')-1
    let cmdline = getline('.')
    let obj.cmdline = cmdline[: cursorpos-1]. a:cmdline. cmdline[cursorpos :]
    let obj.cursorpos = cursorpos + len(a:cmdline)
  end
  let obj._is_on_edge = obj.cmdline[obj.cursorpos-1]!=' ' ? 0 : obj.cmdline[obj.cursorpos-2]!='\' || obj.cmdline[obj.cursorpos-3]=='\'
  let [obj.command; obj.inputs] = __autobackup#lim#cmddef#split_into_words(s:remove_cmdrange(obj.cmdline))
  let obj.leftwords = __autobackup#lim#cmddef#split_into_words(obj.cmdline[:(obj.cursorpos-1)])[1:]
  let obj.arglead = obj._is_on_edge ? '' : obj.leftwords[-1]
  let obj.preword = obj._is_on_edge ? get(obj.leftwords, -1, '') : get(obj.leftwords, -2, '')
  let obj._save_leftargscnt = {}
  let obj._save_argscnt = {}
  return obj
endfunction
"}}}
let s:Cmpl._get_optignorepat = s:func._get_optignorepat
let s:Cmpl._get_arg = s:func._get_arg
function! s:Cmpl.has_bang() "{{{
  return self.command =~ '!$'
endfunction
"}}}
function! s:Cmpl.count_lefts(...) "{{{
  let NULL = "\<C-n>"
  let ignorepat = a:0 ? a:1 : self._get_optignorepat()
  let ignorepat = ignorepat=='' ? NULL : ignorepat
  if has_key(self._save_leftargscnt, ignorepat)
    return self._save_leftargscnt[ignorepat]
  end
  let leftwords = copy(self.leftwords)
  if ignorepat != NULL
    call filter(leftwords, 'v:val !~# ignorepat')
  end
  let ret = len(leftwords)
  let self._save_leftargscnt[ignorepat] = self._is_on_edge ? ret : ret-1
  return self._save_leftargscnt[ignorepat]
endfunction
"}}}
function! s:Cmpl.count_inputted(...) "{{{
  let NULL = "\<C-n>"
  let ignorepat = a:0 ? a:1 : self._get_optignorepat()
  let ignorepat = ignorepat=='' ? NULL : ignorepat
  if has_key(self._save_argscnt, ignorepat)
    return self._save_argscnt[ignorepat]
  end
  let inputs = copy(self.inputs)
  if ignorepat != NULL
    call filter(inputs, 'v:val !~# ignorepat')
  end
  let ret = len(inputs)
  let self._save_argscnt[ignorepat] = self._is_on_edge ? ret : ret-1
  return self._save_argscnt[ignorepat]
endfunction
"}}}
function! s:Cmpl.should_optcmpl() "{{{
  let pat = '^'.self._shortoptbgn.'\|^'.self._longoptbgn
  return pat!='^\|^' && self.arglead =~# pat
endfunction
"}}}
function! s:Cmpl.is_matched(pat) "{{{
  return self.arglead =~# a:pat
endfunction
"}}}
function! s:Cmpl.get(pat, ...) "{{{
  return self._get_arg(a:pat, a:000, self.inputs)
endfunction
"}}}
function! s:Cmpl.get_parts(pat, len) "{{{
  if a:len < 1
    return []
  end
  let idx = match(self.inputs, a:pat)
  return idx==-1 ? [] : self.inputs[idx : idx+ a:len-1]
endfunction
"}}}
function! s:Cmpl.matches(pat) "{{{
  return s:_matches(a:pat, copy(self.inputs))
endfunction
"}}}
function! s:Cmpl.get_left(pat, ...) "{{{
  return self._get_arg(a:pat, a:000, self.leftwords)
endfunction
"}}}
function! s:Cmpl.match_lefts(pat) "{{{
  return s:_matches(a:pat, copy(self.leftwords))
endfunction
"}}}
function! s:Cmpl._filtered_by_inputs(candidates) "{{{
  let assorter = s:newAssorter(self.inputs)
  call assorter.assort_candidates(a:candidates)
  return assorter.remove_del_grouped_candidates()
endfunction
"}}}
function! s:Cmpl.filtered(candidates) "{{{
  let candidates = self._filtered_by_inputs(a:candidates)
  let pat = '^\V'. escape(self.arglead, '\')
  if self.arglead=~'\s'
    let pat .= '\|'. escape(substitute(self.arglead, '\\\@<!\\ ', ' ', 'g'), '\')
  end
  return filter(candidates, 'v:val =~ pat')
endfunction
"}}}
function! s:Cmpl.backward_filtered(candidates) "{{{
  let candidates = self._filtered_by_inputs(a:candidates)
  let pat = '\V'. escape(self.arglead, '\'). '\$'
  if self.arglead=~'\s'
    let pat .= '\|'. escape(substitute(self.arglead, '\\\@<!\\ ', ' ', 'g'), '\')
  end
  return filter(candidates, 'v:val =~ pat')
endfunction
"}}}
function! s:Cmpl.partial_filtered(candidates) "{{{
  let candidates = self._filtered_by_inputs(a:candidates)
  let pat = '\V'. escape(self.arglead, '\')
  if self.arglead=~'\s'
    let pat .= '\|'. escape(substitute(self.arglead, '\\\@<!\\ ', ' ', 'g'), '\')
  end
  return filter(candidates, 'v:val =~ pat')
endfunction
"}}}
function! s:Cmpl.exact_filtered(candidates) "{{{
  let candidates = self._filtered_by_inputs(a:candidates)
  return filter(candidates, 'v:val == self.arglead')
endfunction
"}}}
function! s:Cmpl.hail_space(filtered_candidates) "{{{
  if self.arglead !~ '\s' || a:filtered_candidates==[] || v:version > 703 || v:version==703 && has('patch615')
    return a:filtered_candidates
  end
  let s:save_context = {'wcm': &wcm, 'candidates': a:filtered_candidates}
  if len(a:filtered_candidates) > 1 && index(s:save_context.candidates, self.arglead)==-1
    call add(s:save_context.candidates, self.arglead)
  end
  set wcm=<Tab>
  call feedkeys(repeat("\<BS>", len(self.arglead)+1). "\<Tab>", 'n')
  return [matchstr(self.arglead, '\S\+$'). ' ']
endfunction
"}}}


"--------------------------------------
let s:Parser = {}
function! __autobackup#lim#cmddef#newParser(args, ...) "{{{
  if type(a:args) != s:TYPE_LIST
    throw 'a:args must be List: '. string(a:args)
  end
  let obj = copy(s:Parser)
  let behavior = a:0 ? a:1 : {}
  let obj._longoptbgn = get(behavior, 'longoptbgn', '--')
  let obj._shortoptbgn = get(behavior, 'shortoptbgn', '-')
  let obj.assign = get(behavior, 'assign', '=')
  if obj.assign=~'\s'
    let obj._solve_longopt = s:func._solve_whitespace
    let obj._solve_shortopt = s:func._solve_whitespace
  else
    let obj._endpat = '\%('. obj.assign. '\(.*\)\)\?$'
    let obj._solve_longopt = s:func._solve_longopt_nomal
    let obj._solve_shortopt = s:func._solve_shortopt_normal
  end
  let obj.args = copy(a:args)
  return obj
endfunction
"}}}
let s:Parser._get_optignorepat = s:func._get_optignorepat
let s:Parser._get_arg = s:func._get_arg
function! s:Parser.get(pat, ...) "{{{
  return self._get_arg(a:pat, a:000, self.args)
endfunction
"}}}
function! s:Parser.matches(pat) "{{{
  return s:_matches(a:pat, copy(self.args))
endfunction
"}}}
function! s:Parser.divide(pat, ...) "{{{
  let way = a:0 ? a:1 : 'sep'
  let self._len = len(self.args)
  try
    let ret = self['_divide_'. way](a:pat)
  catch /E716/
    echoerr 'Parser: invalid way > "'. way. '"'
    return self.arg
  endtry
  return ret==[[]] ? [] : ret
endfunction
"}}}
function! s:Parser.filter(pat, ...) "{{{
  let __cmpparser_args__ = self.args
  if a:0
    for __cmpparser_key__ in keys(a:1)
      exe printf('let %s = a:1[__cmpparser_key__]', __cmpparser_key__)
    endfor
  end
  return filter(__cmpparser_args__, a:pat)
endfunction
"}}}
function! s:Parser.parse_options(optdict, ...) "{{{
  let [self._first, self._last] = a:0 ? type(a:1)==s:TYPE_LIST ? a:1 : [a:1, a:1] : [0, -1]
  let self._last = self._last < 0 ? len(self.args) + self._last : self._last
  let ret = {}
  for [key, vals] in items(a:optdict)
    let ret[key] = self._get_optval(self._interpret_optdict_elms(vals, self._longoptbgn. key))
    unlet vals
  endfor
  return ret
endfunction
"}}}

function! s:Parser._interpret_optdict_elms(vals, pat) "{{{
  let [default, pats, invertpats, take_val] = [0, [a:pat], [], 1]
  if type(a:vals) != s:TYPE_LIST
    return [a:vals, pats, invertpats, take_val]
  end
  let types = map(copy(a:vals), 'type(v:val)')
  let [len, i, done_pats, done_default] = [len(a:vals), 0, 0, 0]
  while i < len
    if types[i]==s:TYPE_LIST
      let {done_pats ? 'invertpats' : 'pats'} = a:vals[i]
      let done_pats = 1
    elseif types[i]==s:TYPE_STR
      let default = a:vals[i]
      let done_default = 1
    else
      let {done_default ? 'take_val' : 'default'} = a:vals[i]
      let done_default = 1
    end
    let i += 1
  endwhile
  return [default, pats, invertpats, take_val]
endfunction
"}}}
function! s:Parser._get_optval(optdict_elms) "{{{
  let [default, optpats, invertpats, self.__take_val] = a:optdict_elms
  if self._first<0
    return default
  end
  for pat in invertpats
    let [optval, is_matched] = self._solve_optpat(pat)
    if is_matched
      return 0
    end
  endfor
  for pat in optpats
    let [optval, is_matched] = self._solve_optpat(pat)
    if is_matched
      return optval
    end
  endfor
  return default
endfunction
"}}}
function! s:Parser._solve_optpat(pat) "{{{
  if a:pat =~# '^'.self._longoptbgn || a:pat !~# '^'.self._shortoptbgn.'.$'
    return self._solve_longopt(a:pat)
  end
  return self._solve_shortopt(a:pat)
endfunction
"}}}
function! s:Parser._adjust_ranges() "{{{
  if self._first == self._last
    let self._first -= 1
  end
  let self._last -= 1
endfunction
"}}}

function! s:Parser._get_firstmatch_idx(patlist, bgnidx) "{{{
  let i = a:bgnidx
  while i < self._len
    if index(a:patlist, self.args[i])!=-1
      return i
    end
    let i+=1
  endwhile
  return -1
endfunction
"}}}
function! s:Parser._divide_start(pat) "{{{
  let expr = type(a:pat)==s:TYPE_LIST ? 'self._get_firstmatch_idx(a:pat, i+1)' : 'match(self.args, a:pat, i+1)'
  let ret = []
  let i = 0
  let j = eval(expr)
  while j!=-1
    call add(ret, self.args[i :j-1])
    let i = j
    let j = eval(expr)
  endwhile
  call add(ret, self.args[i :-1])
  return ret
endfunction
"}}}
function! s:Parser._divide_sep(pat) "{{{
  let expr = type(a:pat)==s:TYPE_LIST ? 'self._get_firstmatch_idx(a:pat, i)' : 'match(self.args, a:pat, i)'
  let ret = []
  let i = 0
  let j = eval(expr)
  while j!=-1
    if j-i != 0
      call add(ret, self.args[i :j-1])
    end
    let i = j+1
    let j = eval(expr)
  endwhile
  if i < self._len
    call add(ret, self.args[i :-1])
  end
  return ret
endfunction
"}}}
function! s:Parser._divide_stop(pat) "{{{
  let expr = type(a:pat)==s:TYPE_LIST ? 'self._get_firstmatch_idx(a:pat, i)' : 'match(self.args, a:pat, i)'
  let ret = []
  let i = 0
  let j = eval(expr)
  while j!=-1
    call add(ret, self.args[i :j])
    let i = j+1
    let j = eval(expr)
  endwhile
  if i < self._len
    call add(ret, self.args[i :-1])
  end
  return ret
endfunction
"}}}


"=============================================================================
"END "{{{1
let &cpo = s:save_cpo| unlet s:save_cpo
