function! perforce#Checkout()                                                                                     " {{{1
  " Description: Confirm with the user, then checkout a file from perforce.
  let l:p4path = substitute(split(system("p4 files " . expand('%:p')), '\s\+')[0], '#\d\+$', '', '')
  if (  ( l:p4path =~ '^//depot' )
  \  && ( confirm("Checkout from Perforce?", "&Yes\n&No", 1) == 1 )
  \  )
    call system("p4 edit " . l:p4path . " > /dev/null")
    if (v:shell_error == 0)
      set noreadonly
      return 1
    endif
  endif
  set readonly
  return 0
endfunction


function! perforce#MergeInit()                                                                                    " {{{1
  " Description: Sets up merge layout and creates keybindings
  call s:SetupMergeLayout()
  call s:CreateMaps()
endfunction


function! s:SetupMergeLayout()                                                                                    " {{{1
  " Description: Setup layout for merges
  "              Tab 1: Main window with all 4 panes (Clockwise from top-left) - Base (Original), Remote (Theirs), Local (Yours) and Merge
  "              Tab 2: Diff of Base v/s Remote
  "              Tab 3: Diff of Base v/s Local
  "              Tab 4: Diff of Remote v/s Local
  "              Tab 5: Diff of Remote v/s Merge
  "              Tab 6: Diff of Local  v/s Merge

  let l:base   = argv(0)
  let l:remote = argv(1)
  let l:local  = argv(2)
  let l:merge  = argv(3)

  " Init
  tabonly|wincmd o

  " Main merging tab
  exec "b " . l:merge
  wincmd s
  wincmd t
  exec "b " . l:base
  wincmd v
  exec "b " . l:remote
  wincmd v
  exec "b " . l:local
  set readonly
  windo diffthis
  let t:guitablabel='Main'

  " Diff - Base vs Remote
  exec "tabe " . l:base
  wincmd v
  exec "b " . l:remote
  windo diffthis
  let t:guitablabel='Original v/s Theirs'

  " Diff - Base vs Local
  exec "tabe " . l:base
  wincmd v
  exec "b " . l:local
  set readonly
  windo diffthis
  let t:guitablabel='Original v/s Yours'

  " Diff - Remote vs Local
  exec "tabe " . l:remote
  wincmd v
  exec "b " . l:local
  set readonly
  windo diffthis
  let t:guitablabel='Theirs v/s Yours'

  " Diff - Remote vs Merge
  exec "tabe " . l:remote
  wincmd v
  exec "b " . l:merge
  windo diffthis
  let t:guitablabel='Theirs v/s Merge'

  " Diff - Local vs Merge
  exec "tabe " . l:local
  wincmd v
  exec "b " . l:merge
  set readonly
  windo diffthis
  let t:guitablabel='Yours v/s Merge'

  set columns=420
  tabdo wincmd =
  tabfirst
endfunction


function! s:ConflictInnerMotion(fwd, ...)                                                                         " {{{1
  let l:flags = 'W' . (a:fwd ? '' : 'b') . get(a:000, 0, '')
  return search('\M^\(>>>> ORIGINAL\|==== THEIRS\|==== YOURS\|<<<<\)', l:flags)
endfunction


function! s:ConflictInnerMotion(ai, ...)                                                                          " {{{1
  let l:block = get(a:000, 0, '')
  let l:start_pat = '\M^\(>>>> ORIGINAL\|==== THEIRS\|==== YOURS\|<<<<\)'
  let l:end_pat   = '\M^\(==== THEIRS\|==== YOURS\|<<<<\)'

  if (l:block ==# 'ORIGINAL')
    let l:start_pat = '\M^>>>> ORIGINAL'
    let l:end_pat   = '\M^\(==== THEIRS\|==== YOURS\|<<<<\)'
  elseif (l:block ==# 'THEIRS')
    let l:start_pat = '\M^==== THEIRS'
    let l:end_pat   = '\M^\(==== YOURS\|<<<<\)'
  elseif (l:block ==# 'YOURS')
    let l:start_pat = '\M^==== YOURS'
    let l:end_pat   = '\M^<<<<'
  endif

  " Find starting line of any block
  if (getline('.') =~ '\M^<<<<')
    -
  endif
  if (search(l:start_pat, 'bWc') != 0)
    let l:start = line('.')
  elseif (search(l:start_pat, 'W') != 0)
    let l:start = line('.')
  else
    echo "DEBUG: No start in sight"
    return
  endif
  if (a:ai ==# 'i')
    +
    let l:start += 1
  endif

  " Find ending line of any block
  let l:end = search(l:end_pat, 'Wn')
  if (l:end == 0)
    echo "DEBUG: No end in sight"
    return
  endif
  let l:end -= 1

  if (l:start > l:end)
    echoe "Shit's fucked up!"
  else
    execute 'normal! V' . (l:end - l:start) . 'j'
  endif
endfunction

function! s:CreateMaps()
  noremap  ]C :call <SID>ConflictMotion(0)<CR>
  noremap  [C :call <SID>ConflictMotion(1)<CR>
  xnoremap iC :call <SID>ConflictInnerMotion('i')<CR>
  xnoremap aC :call <SID>ConflictInnerMotion('a')<CR>
  onoremap iC :call <SID>ConflictInnerMotion('i')<CR>
  onoremap aC :call <SID>ConflictInnerMotion('a')<CR>

  nmap dgo d:call <SID>ConflictInnerMotion('a', 'THEIRS')<CR>d:call   <SID>ConflictInnerMotion('a','YOURS')<CR>dd[Cdd
  nmap dgt d:call <SID>ConflictInnerMotion('a', 'ORIGINAL')<CR>d:call <SID>ConflictInnerMotion('a','YOURS')<CR>dd[Cdd
  nmap dgy d:call <SID>ConflictInnerMotion('a', 'ORIGINAL')<CR>d:call <SID>ConflictInnerMotion('a','THEIRS')<CR>dd]Cdd
endfunction