let s:save_cpo = &cpo
set cpo&vim

" Various {{{
" ctags default supported language list {{{
let s:supported_langs = {
      \ 'ant':        [ 'ant', 'pt' ],
      \ 'asm':        [ 'asm', 'dlmt' ],
      \ 'asp':        [ 'asp', 'dcfsv' ],
      \ 'awk':        [ 'awk', 'f' ],
      \ 'basic':      [ 'basic', 'cfltvg' ],
      \ 'beta':       [ 'beta', 'fpsv' ],
      \ 'c':          [ 'c', 'cdefglmnpstuvx' ],
      \ 'cpp':        [ 'c++', 'cdefglmnpstuvx' ],
      \ 'cs':         [ 'c#', 'cdeEfgilmnpst' ],
      \ 'cobol':      [ 'cobol', 'dfgpPs' ],
      \ 'dosbatch':   [ 'dosbatch', 'lv' ],
      \ 'eiffel':     [ 'eiffel', 'cfl' ],
      \ 'erlang':     [ 'erlang', 'dfmr' ],
      \ 'flex':       [ 'flex', 'fcmpvx' ],
      \ 'fortran':    [ 'fortran', 'bcefiklLmnpstv' ],
      \ 'html':       [ 'html', 'af' ],
      \ 'java':       [ 'java', 'cefgilmp' ],
      \ 'javascript': [ 'javascript', 'fcmpv' ],
      \ 'lisp':       [ 'lisp', 'f' ],
      \ 'lua':        [ 'lua', 'f' ],
      \ 'make':       [ 'make', 'm' ],
      \ 'matlab':     [ 'matlab', 'f' ],
      \ 'ocaml':      [ 'ocaml', 'cmMvtfCre' ],
      \ 'pascal':     [ 'pascal', 'fp' ],
      \ 'perl':       [ 'perl', 'cflpsd' ],
      \ 'php':        [ 'php', 'cidfvj' ],
      \ 'python':     [ 'python', 'cfmvi' ],
      \ 'rexx':       [ 'rexx', 's' ],
      \ 'ruby':       [ 'ruby', 'cfmF' ],
      \ 'scheme':     [ 'scheme', 'fs' ],
      \ 'sh':         [ 'sh', 'f' ],
      \ 'slang':      [ 'slang', 'fn' ],
      \ 'sml':        [ 'sml', 'efcsrtv' ],
      \ 'sql':        [ 'sql', 'cdfFlLPprstTvieURDVnxy' ],
      \ 'tcl':        [ 'tcl', 'cmp' ],
      \ 'tex':        [ 'tex', 'csubpPG' ],
      \ 'vera':       [ 'vera', 'cdefglmpPtTvx' ],
      \ 'verilog':    [ 'verilog', 'cefmnprt' ],
      \ 'vhdl':       [ 'vhdl', 'ctTreCdfpPl' ],
      \ 'vim':        [ 'vim', 'acfmv' ],
      \ 'yacc':       [ 'yacc', 'l' ],
      \ }
" }}}

let s:scope_sep = { 'c': '::', 'cpp': '::' }
" }}}

" Global Various {{{
function! s:ctags_cmdline(options, file) "{{{
  let l:cmd = get(g:, 'ctags_util#ctags_command', 'ctags')

  " --fields  k  tag type (short)
  "           K  tag type (full)
  "           S  signature
  "           s  tag definition scope (namespace)
  return printf('%s %s --fields=kSs --verbose=no -u -n -f - %s', l:cmd, a:options, a:file)
endfunction "}}}

function! s:user_kinds() "{{{
  return get(g:, 'ctags_util#ctags_user_kinds', {})
endfunction "}}}

function! s:user_language() "{{{
  return get(g:, 'ctags_util#ctags_user_language', {})
endfunction "}}}
" }}}

" Function {{{
function! s:is_supported_type(filetype) "{{{
  return has_key(s:supported_langs, a:filetype) ||
        \ has_key(s:user_language(), a:filetype)
endfunction "}}}

function! s:get_lang_option(filetype) "{{{
  if has_key(s:supported_langs, a:filetype)
    let [l:lang, l:kind] = s:supported_langs[a:filetype]
    " lang = [ language-name, kinds ]
    let l:kind = get(s:user_kinds(), l:lang, l:kind)

    return printf(' --language-force=%s --%s-kinds=%s ', l:lang, l:lang, l:kind)
  else
    return get(s:user_language(), a:filetype, '')
  endif
endfunction "}}}

function! s:add_tree_node(node, taginfo, tokens) "{{{
  if empty(a:tokens)
    return
  endif

  let l:token = remove(a:tokens, 0)

  if !has_key(a:node, l:token)
    let a:node[l:token] = { 'line': a:taginfo.line }
  endif

  if empty(a:tokens) 
    let a:node[l:token].line = a:taginfo.line
    let a:node[l:token].info = a:taginfo
  else
    if !has_key(a:node[l:token], 'children')
      let a:node[l:token].children = {}
    endif

    call s:add_tree_node(a:node[l:token].children, a:taginfo, a:tokens)
  endif
endfunction "}}}

function! s:build_tree(root, taginfo, scope_sep) "{{{
  let l:tokens = filter(split(a:taginfo.name, escape(a:scope_sep, '.')), 'len(v:val)')

  " for overload function
  if !empty(l:tokens)
    let l:tokens[-1] .= a:taginfo.signature
  endif

  call s:add_tree_node(a:root, a:taginfo, l:tokens)
endfunction "}}}

function! s:tokenize_tagline(tokens, scope_sep) "{{{
  let l:taginfo = { 'kind': '', 'kind_mark': '', 'scope': '', 'signature': '' }

  " [basic-format]
  "   tag_name<TAB>file_name<TAB>ex_cmd;"<TAB>extension_fields 
  let l:taginfo.name = a:tokens[0]
  let l:taginfo.line = str2nr(substitute(a:tokens[2], ';"', '', ''))

  " [extension_fields]
  "    namespace<TAB>scope<TAB>signature
  for l:token in a:tokens[3:]
    if l:token =~ '^signature:'
      let l:taginfo.signature = substitute(l:token, 'signature:', '', '')

    elseif l:token =~ '^[^:]\+:'
      let l:match = matchlist(l:token, '^\([^:]\+\):\(.*\)$')
      let l:taginfo.kind = l:match[1]
      let l:taginfo.scope = l:match[2]

    else
      let l:taginfo.kind_mark = l:token
    endif
  endfor

  " full-scope name
  if len(l:taginfo.scope) > 0
    let l:taginfo.name = l:taginfo.scope . a:scope_sep . l:taginfo.name
  endif

  return l:taginfo
endfunction "}}}

function! s:parse_line(line, scope_sep) "{{{
    let l:tokens = split(a:line, '\t')

    if len(l:tokens) < 4
      return {}
    endif

    return s:tokenize_tagline(l:tokens, a:scope_sep)
endfunction "}}}

function! s:parse_taglines(taglines, scope_sep) "{{{
  let l:lines = split(a:taglines, '\n')

  return filter(map(l:lines, 's:parse_line(v:val, a:scope_sep)'), '!empty(v:val)')
endfunction "}}}

function! s:make_parse_cache(filename) "{{{
  let l:fname = tempname()

  if has('iconv') && (&encoding !=# &termencoding)
    let l:buflines = map(getbufline(a:filename, 1, '$'), 'iconv(v:val, &encoding, &termencoding)')
  else
    let l:buflines = getbufline(a:filename, 1, '$')
  endif

  call writefile(l:buflines, l:fname)

  return l:fname
endfunction "}}}
" }}}

" Global Function {{{
function! ctag_util#get_tag_list(filename, filetype) "{{{
  if !s:is_supported_type(a:filetype)
    return []
  endif

  let l:cache_name = s:make_parse_cache(a:filename)
  let l:option = s:get_lang_option(a:filetype)
  let l:command = s:ctags_cmdline(l:option, l:cache_name)

  if has('iconv') && (&encoding !=# &termencoding)
    let l:command = iconv(l:command, &encoding, &termencoding)
  endif

  let l:tags = system(l:command)
  let l:scope_sep = get(s:scope_sep, a:filetype, '.')

  call delete(l:cache_name)

  return s:parse_taglines(l:tags, l:scope_sep)
endfunction "}}}

function! ctag_util#get_tag_tree(filename, filetype) "{{{
  let l:tree = {}
  let l:scope_sep = get(s:scope_sep, a:filetype, '.')
  let l:list = ctag_util#get_tag_list(a:filename, a:filetype)

  for l:taginfo in l:list
    call s:build_tree(l:tree, l:taginfo, l:scope_sep)
  endfor

  return l:tree
endfunction "}}}
" }}}


let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
