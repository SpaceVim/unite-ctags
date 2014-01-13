let s:save_cpo = &cpo
set cpo&vim

"""""""""""""""""""""""""""""""""""""""""""""""""""
" ctags default supported language list {{{
let s:supported_langs = {}

let s:supported_langs.ant = [ 'ant', 'pt' ]
let s:supported_langs.asm = [ 'asm', 'dlmt' ]
let s:supported_langs.asp = [ 'asp', 'dcfsv' ]
let s:supported_langs.awk = [ 'awk', 'f' ]
let s:supported_langs.basic = [ 'basic', 'cfltvg' ]
let s:supported_langs.beta = [ 'beta', 'fpsv' ]
let s:supported_langs.c = [ 'c', 'cdefglmnpstuvx' ]
let s:supported_langs.cpp = [ 'c++', 'cdefglmnpstuvx' ]
let s:supported_langs.cs = [ 'c#', 'cdeEfgilmnpst' ]
let s:supported_langs.cobol = [ 'cobol', 'dfgpPs' ]
let s:supported_langs.dosbatch = [ 'dosbatch', 'lv' ]
let s:supported_langs.eiffel = [ 'eiffel', 'cfl' ]
let s:supported_langs.erlang = [ 'erlang', 'dfmr' ]
let s:supported_langs.flex = [ 'flex', 'fcmpvx' ]
let s:supported_langs.fortran = [ 'fortran', 'bcefiklLmnpstv' ]
let s:supported_langs.html = [ 'html', 'af' ]
let s:supported_langs.java = [ 'java', 'cefgilmp' ]
let s:supported_langs.javascript = [ 'javascript', 'fcmpv' ]
let s:supported_langs.lisp = [ 'lisp', 'f' ]
let s:supported_langs.lua = [ 'lua', 'f' ]
let s:supported_langs.make = [ 'make', 'm' ]
let s:supported_langs.matlab = [ 'matlab', 'f' ]
let s:supported_langs.ocaml = [ 'ocaml', 'cmMvtfCre' ]
let s:supported_langs.pascal = [ 'pascal', 'fp' ]
let s:supported_langs.perl = [ 'perl', 'cflpsd' ]
let s:supported_langs.php = [ 'php', 'cidfvj' ]
let s:supported_langs.python = [ 'python', 'cfmvi' ]
let s:supported_langs.rexx = [ 'rexx', 's' ]
let s:supported_langs.ruby = [ 'ruby', 'cfmF' ]
let s:supported_langs.scheme = [ 'scheme', 'fs' ]
let s:supported_langs.sh = [ 'sh', 'f' ]
let s:supported_langs.slang = [ 'slang', 'fn' ]
let s:supported_langs.sml = [ 'sml', 'efcsrtv' ]
let s:supported_langs.sql = [ 'sql', 'cdfFlLPprstTvieURDVnxy' ]
let s:supported_langs.tcl = [ 'tcl', 'cmp' ]
let s:supported_langs.tex = [ 'tex', 'csubpPG' ]
let s:supported_langs.vera = [ 'vera', 'cdefglmpPtTvx' ]
let s:supported_langs.verilog = [ 'verilog', 'cefmnprt' ]
let s:supported_langs.vhdl = [ 'vhdl', 'ctTreCdfpPl' ]
let s:supported_langs.vim = [ 'vim', 'acfmv' ]
let s:supported_langs.yacc = [ 'yacc', 'l' ]
" }}}

let s:scope_sep = { 'c': '::', 'cpp': '::' }

function! s:ctags_cmdline(options, file) "{{{
  let l:cmd = get(g:, 'ctags_util#ctags_command', 'ctags')

  return printf('%s %s --fields=kSs --verbose=no -u -n -f - %s', l:cmd, a:options, a:file)
endfunction "}}}

function! s:user_kinds() "{{{
  return get(g:, 'ctags_util#ctags_user_kinds', {})
endfunction "}}}

function! s:user_language() "{{{
  return get(g:, 'ctags_util#ctags_user_language', {})
endfunction "}}}


" **************************************************
function! s:is_supported_type(filetype) "{{{
  return has_key(s:supported_langs, a:filetype) ||
        \ has_key(s:user_kinds(), a:filetype)
endfunction "}}}

function! s:get_user_kinds(typename, def_kind) "{{{
  let l:kind = get(s:user_kinds(), a:typename, a:def_kind)

  return printf(' --language-force=%s --%s-kinds=%s ', a:typename, a:typename, l:kind)
endfunction "}}}

function! s:get_user_language(filetype) "{{{
  return get(s:user_language(), a:filetype, '')
endfunction "}}}

function! s:get_type_option(filetype) "{{{
  if has_key(s:supported_langs, a:filetype)
    let l:lang = s:supported_langs[a:filetype]

    return s:get_user_kinds(l:lang[0], l:lang[1])
  else
    return s:get_user_language(a:filetype)
  endif
endfunction "}}}


" **************************************************
function! s:add_tree_node(node, taginfo, tokens) "{{{
  if empty(a:tokens) | return | endif

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


" **************************************************
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

function! s:get_buff_file(filename) "{{{
  let l:fname = tempname()

  if has('iconv') && (&encoding !=# &termencoding)
    let l:buflines = map(getbufline(a:filename, 1, '$'), 'iconv(v:val, &encoding, &termencoding)')
  else
    let l:buflines = extend(l:buflines, getbufline(a:filename, 1, '$'))
  endif

  call writefile(l:buflines, l:fname)

  return l:fname
endfunction "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""
function! ctags_util#get_tags(filename, filetype) "{{{
  if !s:is_supported_type(a:filetype)
    return []
  endif

  let l:buf_name = s:get_buff_file(a:filename)
  " --fields  k  tag type (short)
  "           K  tag type (full)
  "           S  signature
  "           s  tag definition scope (namespace)
  let l:tagcmd = s:ctags_cmdline(s:get_type_option(a:filetype), l:buf_name)

  if has('iconv') && (&encoding !=# &termencoding)
    let l:tagcmd = iconv(l:tagcmd, &encoding, &termencoding)
  endif

  return s:parse_taglines(system(l:tagcmd), get(s:scope_sep, a:filetype, '.'))
endfunction "}}}

function! ctags_util#get_tag_tree(filename, filetype) "{{{
  let l:tree = {}
  let l:scope_sep = get(s:scope_sep, a:filetype, '.')
  let l:infos = ctags_util#get_tags(a:filename, a:filetype)

  for l:taginfo in l:infos
    call s:build_tree(l:tree, l:taginfo, l:scope_sep)
  endfor

  return l:tree
endfunction "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""
let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
