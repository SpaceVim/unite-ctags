let s:save_cpo = &cpo
set cpo&vim

"""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:order_by_line(lhe, rhe) "{{{
  return ( ( a:lhe[1].line == a:rhe[1].line ) ? 0 : ( ( a:lhe[1].line > a:rhe[1].line ) ? 1 : -1 ) )
endfunction "}}}

function! s:node2candidate(name, node, path, indent) "{{{
  let l:candidate = { 'kind': 'jump_list' }

  let l:candidate.action__path = a:path
  let l:candidate.action__line = a:node.line
  let l:candidate.is_dummy = !has_key(a:node, 'info')

  if l:candidate.is_dummy
    let l:candidate.word = printf('%s[ ] %s', a:indent, a:name)
  else
    let l:info = a:node.info

    let l:candidate.word = printf('%s[%s] %s', a:indent, l:info.kind_mark, a:name)
  endif

  return l:candidate
endfunction "}}}

function! s:flatton(nodes, path, depth, candidates) "{{{
  let l:indent = printf(printf('%%%ds', a:depth * 2), ' ')

  for [l:name, l:node] in sort(items(a:nodes), 's:order_by_line')

    call add(a:candidates, s:node2candidate(l:name, l:node, a:path, l:indent))

    if has_key(l:node, 'children')
      call s:flatton(l:node.children, a:path, a:depth + 1, a:candidates)
    endif
  endfor
endfunction "}}}

function! s:tree2candidates(tree, path) "{{{
  let l:candidates = []

  for [l:name, l:node] in sort(items(a:tree), 's:order_by_line')

    call add(l:candidates, s:node2candidate(l:name, l:node, a:path, ''))

    if has_key(l:node, 'children')
      call s:flatton(l:node.children, a:path, 1, l:candidates)
    endif
  endfor

  return l:candidates
endfunction "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""
let s:unite_source = { 'name': 'ctags', 'hooks': {} }

function! s:unite_source.hooks.on_init(args, context) "{{{
  let a:context['source__fileinfo'] = { 'path': fnamemodify(expand('%'), ':p'), 'type': &filetype }
endfunction "}}}

function! s:unite_source.gather_candidates(args, context) "{{{
  let l:fileinfo = get(a:context, 'source__fileinfo', { 'path': '', 'type': '' })
  let l:tree = ctags_util#get_tag_tree(l:fileinfo.path, l:fileinfo.type)

  return s:tree2candidates(l:tree, l:fileinfo.path)
endfunction "}}}

function! unite#sources#ctags#define() "{{{
  return [ s:unite_source ]
endfunction "}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
