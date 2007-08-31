" Vim plugin -- bookmarks for undo states
" Version      : 1.2
" Last change  : 2007-09-01
" Maintainer   : A.Politz <politza@fh-trier.de>
" Contributors : Andy Wokula

if exists("loaded_undo_tags")
  finish
endif
let loaded_undo_tags=1

if v:version < 700 
  redraw | echohl Error | echo "undo_tags : You need at least vim7 for this plugin." | echohl None
  finish
endif

let s:cpo=&cpo
set cpo&vim

func! s:UTMark( bang, name, ...)
  let undo_tags=s:UTGetBufTags()
  if has_key(undo_tags,a:name) && !a:bang
    echohl Error | echo "Tag '".a:name."' already exists. Add ! to overwrite it." | echohl None
    return
  endif
  if changenr() == 0
    let changes = 0
  else
    let changes = "n/a"
    for e in s:UTGetUndoList()
      if e.number == changenr()
        let changes=e.changes
        break
      endif
    endfor
  endif

  let tagdata = {}
  let undo_tags[a:name] = tagdata
  let tagdata.number = changenr()+0
  let tagdata.changes = changes
  let tagdata.time = strftime("%H:%M:%S")
  let tagdata.description = join(a:000," ")
  call s:UTList({ a:name : tagdata })
endfun

func! s:UTRestore( name )
  let undo_tags=s:UTGetBufTags()
  if !has_key(undo_tags,a:name)
    echohl Error|echo "No such tag : ".a:name |echohl None
    return
  endif
  try
    if undo_tags[a:name].number == 0
      exec ":undo 1"
      normal u
    else
      exec ":undo ".undo_tags[a:name].number
    endif
  catch /.*/	"No error code for this atm.
    echohl Error|echo "Sorry, you ran out of 'undolevels'. Deleting tag '".a:name."'." |echohl None
    call remove(undo_tags,a:name)
  endtry
endfun

func! s:UTDelete( pat )
  let undo_tags=s:UTGetBufTags()
  let len=len(undo_tags)
  let pat = '^'.a:pat.'$'
  try
    call filter(undo_tags,'v:key !~ pat')
  catch /.*/ "Catch invalid pattern
    echohl Error | echo v:exception | echohl None
  endtry
  let deleted = len-len(undo_tags)
  echo "Removed ".deleted." tag". ( deleted != 1 ? "s." : ".")
endfun

func! s:UTList( tag_hash, ...)
  let order_by =  a:0 && a:1 =~ '^\%(tag\|time\|number\|changes\|description\)$' ? a:1 : 'time'
  let max_tag_len = max(map(keys(a:tag_hash),'len(v:val)'))
  let tag_pad = max_tag_len < 10 ? 10 : max_tag_len

  let tag_h           = "  tag".repeat(" ",tag_pad)
  let number_h        = "number    "
  let changes_h       = "changes   "
  let time_h          = "time       "
  let description_h   = "description"
  redraw | echohl Title | echo tag_h.number_h.changes_h.time_h.description_h |  echohl None

  for e in s:UTSortTagKeys(a:tag_hash,order_by)
    let c = a:tag_hash[e].changes
    let n = a:tag_hash[e].number
    let d = a:tag_hash[e].description
    let t = a:tag_hash[e].time
    "This does not work in all cases
    let fc = '  ' " n == changenr() ? "> " : "  "

    echo fc.e.repeat(" ",len(tag_h)-len(e)-len(fc))
    \.n.repeat(" ",len(number_h)-len(n))
    \.c.repeat(" ",len(changes_h)-len(c))
    \.t.repeat(" ",len(time_h)-len(t))
    \.d
  endfor
endfun

func! s:UTSortTagKeys( tag_hash, order_by)
  if a:order_by=="tag" 
    return sort(keys(a:tag_hash))
  else
    let s:order_by = a:order_by
    let s:hash = a:tag_hash
    let sorted = sort(keys(a:tag_hash),"s:_UTCompareTags")
    unlet s:hash
    unlet s:order_by
    return sorted
  endif
endfun

func! s:UTGetUndoList( )
  "There is no func for this.
  redir => strundolist
  silent undolist
  redir END
  let undo_list = split(strundolist, "\n")
  let res = []
  for str in undo_list
    if str !~ '\d' | continue | endif
    let branch = {}
    call add(res, branch)
    let [ n,c,t ] =  matchlist(str, '\(\d\+\)  *\(\d\+\)  *\(\S.*\)')[1:3]
    let [branch.number, branch.changes, branch.time] = [n+0,c+0,t]
  endfor
  return res
endfun

func! s:UTGetBufTags()
  if !exists("b:undo_tags")
    let b:undo_tags = {}
  endif
  return b:undo_tags
endfunc

func! s:UTCompleteHeader(a,b,c)
  return "tag\nchanges\nnumber\ndescription\ntime"
endfun

func! s:UTCompleteTags(a,b,c)
  return join(keys(s:UTGetBufTags()),"\n")
endfun

func! s:_UTCompareTags(k1, k2)
  return s:hash[a:k1][s:order_by] < s:hash[a:k2][s:order_by]
  \ ? -1
  \ : s:hash[a:k1][s:order_by] > s:hash[a:k2][s:order_by]
endfun


comm -nargs=1 -complete=custom,s:UTCompleteTags UTRestore :call s:UTRestore(<q-args>)
comm -nargs=1 -complete=custom,s:UTCompleteTags UTDelete :call s:UTDelete(<q-args>)
comm -nargs=+ -bang -complete=custom,s:UTCompleteTags UTMark :call s:UTMark(<bang>0,<f-args>)
comm -nargs=? -complete=custom,s:UTCompleteHeader UTList :call s:UTList(s:UTGetBufTags(),<q-args>) 

let &cpo=s:cpo
unlet s:cpo

" vim:sts=2:sw=2:et:fdl=0:fdm=expr:fde=getline(v\:lnum)=~'^fun'?"a1"\:getline(v\:lnum-1)=~'^endf'?"<1"\:"="
