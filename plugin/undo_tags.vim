if exists("loaded_undo_tag")
  finish
endif
let loaded_undo_tag=1
let s:cpo=&cpo
set cpo-=C

augroup undo_tags
  au!
  au BufEnter * if !exists('b:undo_tags') | :let b:undo_tags = {} | endif
augroup END

func! s:GetUndoList( )
  "There is no func for this.
  let tmp = tempname()
  exec "redir > ".tmp
  silent undol
  redir END
  let undo_list=readfile(tmp)
  "First line is always empty
  if len(undo_list) <= 2
    return {}
  endif
  let res = []
  for b in undo_list[2:]
    let number = matchstr(b,'^\s*\zs\d\+\ze')+0
    let changes = matchstr(b,'^\s*\d\+\s\+\zs\d\+\ze')+0
    let time = matchstr(b,'^\s*\%(\d\+\s\+\)\{2}\zs.*')
    call add(res,{'number' : number , 'changes' : changes , 'time' : time  })
  endfor
  return res
endfun


func! s:UndoTagBranch( bang, name, ...)
  let undos = s:GetUndoList()
  if empty(undos) 
    redraw | echo "Nothing to undo."
    return
  endif
  if has_key(b:undo_tags,a:name) && a:bang !~ "!"
    echohl Error | echo "Tag already exists. Add ! to overwrite it." | echohl None
    return
  endif
  let b:undo_tags[a:name]= undos[-1]
  let b:undo_tags[a:name].time = strftime("%H:%M:%S")
  let b:undo_tags[a:name].description = join(a:000," ")
  call s:UndoListTags({ a:name : b:undo_tags[a:name] })
endfun

func! s:UndoGotoTag( name )
  if !has_key(b:undo_tags,a:name)
    echohl Error|echo "No such tag : ".a:name |echohl None
    return
  endif
  exec ":undo ".b:undo_tags[a:name].number
endfun

func! s:UndoListTags( hash, ...)
  let order_by = 
        \!a:0 ? "number"                       :
        \a:1=="tag"         ? "tag"         : 
        \a:1=="time"        ? "time"        : 
        \a:1=="number"      ? "number"      : 
        \a:1=="changes"     ? "changes"     : 
        \a:1=="description" ? "description" : 
	\"number"
  
  let tag_h           = "tag           "
  let tag_h           = "tag           "
  let tag_h           = "tag           "
  let number_h        = "number    "
  let changes_h       = "changes   "
  let time_h          = "time            "
  let description_h   = "description"
  redraw | echohl Question | echo tag_h.number_h.changes_h.time_h.description_h |  echohl None
  
  let s:order_by = order_by
  let s:hash = a:hash
  func! s:SortTags(k1,k2)
    return s:hash[a:k1][s:order_by] < s:hash[a:k2][s:order_by]?-1:s:hash[a:k1][s:order_by] > s:hash[a:k2][s:order_by]?1:0
  endfun

  for e in (order_by=="tag" ? sort(keys(a:hash)): sort(keys(a:hash),"s:SortTags"))
    let c = b:undo_tags[e].changes
    let n = b:undo_tags[e].number
    let d = b:undo_tags[e].description
    let t = b:undo_tags[e].time

    echo e.repeat(" ",len(tag_h)-len(e))
	  \.n.repeat(" ",len(number_h)-len(n))
	  \.c.repeat(" ",len(changes_h)-len(c))
	  \.t.repeat(" ",len(time_h)-len(t))
	  \.d
  endfor
  unlet s:hash
  unlet s:order_by
endfun

func! s:UndoListComplete(a,b,c)
  return "tag\ndescription\ntime\nnumber\nchanges\n"
endfun

func! s:UndoTagComplete(a,b,c)
  return join(keys(b:undo_tags),"\n")
endfun

comm! -nargs=1 -complete=custom,s:UndoTagComplete UTGotoTag :call s:UndoGotoTag(<q-args>)
comm! -nargs=+ -bang -complete=custom,s:UndoTagComplete UTMakeTag :call s:UndoTagBranch("<bang>",<f-args>)
comm! -nargs=? -complete=custom,s:UndoListComplete UTListTags :call s:UndoListTags(b:undo_tags,<q-args>) 

let &cpo=s:cpo
unlet s:cpo
