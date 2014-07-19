
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Name:		woc.vim
" Shortdesc:	WOC client for Vim
"
" Desc:		Detailed documentation can be found in
" 		http://dev.dyne.org/trac.cgi/wiki/Woc
" 		
"		See the woc.psy file for an overview of the internals of this
"		script, or jump to {-overview-}
"
" WARNINGS:	- Right now this plugin is not portable! It should work only
" 		  in a GNU environment (tested), and maybe in a *BSD one (not
" 		  tested).
" 		
" 		- ~/.vim/woc/ must be a writable directory.
" 		  It is hardcoded, its path cannot cannot be changed.
"
"		- ~/.vim/woc/ must contain the {-wocdownloader-} script!
"
" Dependencies: woc.vim depends on these vim plugins:
" 			netrw
" 		and on these shell programs:
" 			wget, sed, awk, cut
"
" Usage:	In the simplest form, just use CTRL-] and CTRL-T to respectively 
" 		jump to a tag and to go back.
"		Use    :Woctags help   to get online help.
"		
" 		The :Woctags command executes a tag command
" 		It's optional arguments are:
"
" 			:Woctags [tagcmd [tag]]
"		
"		`tagcmd' specifies the tag command to be executed. It can be
"		one of the following:
"
"			--- WoC tags commands ---
"			j:  Jump to this tag (default)
"			r:  Reverse jump: find references to this tag
"			fj: File Jump: Open this file
"		
"			--- cscope find commands ---
"		        c: Find functions calling this function
"		        d: Find functions called by this function
"		        e: Find this egrep pattern
"		        f: Find this file
"		        g: Find this definition
"		        i: Find files #including this file
"		        s: Find this C symbol
"		        t: Find assignments to
"
" 		`tag' is the tag. If it's not specified, it will be set to the 
" 		tag under the cursor.
"
" 		The command specified in `tag' takes priority over that 
" 		specified in `tagcmd'.
"		For example, if the tag is {-mytag:"c-} and `tagcmd' is 'j', then
"		the action would be "Jump to this tag" and not "Find functions
"		calling this function"
"
" Mappings:	These mappings are automatically defined.
"
"			<C-]>	-->  :Woctags
"	
"			<C-_>s  -->  :Woctags s
"			<C-_>g  -->  :Woctags g
"			<C-_>c  -->  :Woctags c
"			<C-_>t  -->  :Woctags t
"			<C-_>e  -->  :Woctags e
"			<C-_>r  -->  :Woctags r
"			<C-_>f  -->  :Woctags fj
"			<C-_>i  -->  :Woctags i
"			<C-_>d  -->  :Woctags d
"
" 		If you don't like them, put the following line inside
" 		your .vimrc and define there your own mappings:
"
" 			let g:woc_mappings = 1
"
"
" Options:	If is g:woc_clear_cache is set to 1 (default), the woc cache
"		will be automatically cleaned on exit.
"
"		If the cache isn't cleaned, then the files, which are already
"		there, won't be downloaded a second time. This is useful is
"		you want to do an "offline browsing".
"
"		If g:woc_syntax_hl is set to 1 (default), the WoC tags will be
"		highlighted.
"
"		g:woc_global_index can be set to a global ``index.woc'' file.
"		For example, you can put something like this in your .vimrc:
"			
"			let g:woc_global_index = "/my/path/to/my_index.woc"
"
" Version:	1.2
" Author:	AlpT (@freaknet.org)
" Licence:	This program is free software; you can redistribute it
"               and/or modify it under the terms of the GNU General Public
"               License.  See http://www.gnu.org/copyleft/gpl.txt
" 
" Credits:	Katolaz, Efphe, frogonwheels
"
" RippedSrc:	Some codes here derive from the following plugins:
" 		 
" 		  Vimball, Vimspell
"
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if exists("g:loaded_wocscript")
	finish
endif
let g:loaded_wocscript=1
let s:save_cpo = &cpo
set cpo&vim

augroup WOC
  au! 
   au BufReadPre		*	call s:WOCOpenFile(expand("<afile>"))
   au BufReadPost		*	if g:woc_syntax_hl|call s:WOCSyntax()|endif

   " {-TODO wocpath-} . It is hardcoded.
   au BufReadCmd	*/woc/cache/*	call s:WOCOpenFile(expand("<afile>"))

   au VimLeave			*	if g:woc_clear_cache|call s:WOCClearCache()|endif
augroup END

" User command
com! -nargs=*           Woctags     call s:WOCTagCmd(<f-args>)
com! -nargs=*           WocClearCache     call s:WOCClearCache(1)

" Add our mappings 
if !exists("g:woc_mappings") || !g:woc_mappings
	nmap <C-]>  :call <SID>WOCTagCmd()<cr>

	" See {-TODO mouse support-}
	"nmap <C-LeftMouse>  :call <SID>WOCTagCmd()<cr>
	"nmap g<LeftMouse>  :call <SID>WOCTagCmd()<cr>

	nmap <C-_>s :Woctags s<cr>
	nmap <C-_>g :Woctags g<cr>
	nmap <C-_>c :Woctags c<cr>
	nmap <C-_>t :Woctags t<cr>
	nmap <C-_>e :Woctags e<cr>
	nmap <C-_>r :Woctags r<cr>
	nmap <C-_>f :Woctags fj<cr>
	nmap <C-_>i :Woctags i<cr>
	nmap <C-_>d :Woctags d<cr>

	let g:woc_mappings = 1
endif

" Initialize: 
" 
if !exists("g:woc_index_fname")
	let g:woc_index_fname="index.woc"
endif
if !exists("g:woc_global_index")
	let g:woc_global_index=""
endif
if !exists("g:woc_clear_cache")
	let g:woc_clear_cache = 1
endif
if !exists("g:woc_syntax_hl")
	let g:woc_syntax_hl = 1
endif

" WOCHome: determine/get home directory path (usually from rtp) 
" (Function ripped from the VimBall plugin)
fun! s:WOCHome()
	" go to vim plugin home
	for home in split(&rtp,',') + ['']
		if isdirectory(home) && filewritable(home) | break | endif
	endfor
	if home == ""
		" just pick the first directory
		let home= substitute(&rtp,',.*$','','')
	endif
	if (has("win32") || has("win95") || has("win64") || has("win16"))
		let home= substitute(home,'/','\\','g')
	endif

   	" {-TODO wocpath-} . It is hardcoded.
	return home . '/woc'
endfun
if !exists("$WOC_HOME")
	let $WOC_HOME = s:WOCHome()
endif


" 
fun! s:WOCInitialize()
	if !exists("b:woc_index")	" Executed for each new buffer
		let b:woc_index={
			\	"name"		: "",
			\	"description"	: "",
			\	"alias"		: {},
			\	"syn_def_left"	   : '|{',
			\	"syn_def_right"	   : '}|',
			\	"syn_ref_left"	   : '{-',
			\	"syn_ref_right"	   : '-}',
			\	"tags_file"	   : 'auto',
			\	"woc_tags_file"	   : 'tags.woc',
			\	"woc_revtags_file" : 'tags.rev.woc',
			\	"tfile_compress"   : 'yes' }
	endif

	let s:woc_last_path  = !exists("s:woc_cur_path") ? "" :  s:woc_cur_path
	let s:woc_cur_path   =  expand("%:p:h")
	let b:woc_cur_path   =  expand("%:p:h")

	if !exists("s:woc_indexes")	" Executed only once
		let s:woc_indexes = { s:woc_cur_path : b:woc_index }
	endif
	if !exists("s:woc_cache_url")
		let s:woc_cache_url = {}
	endif

	exe "set tags+=" . b:woc_index.woc_tags_file
endfun

" 
" WOCAddIndexOpt: Parses a:ml and properly adds it to b:woc_index  
"
" a:ml is a list:
" 	a:ml[0] is the entire line where the option was defined in index.woc
" 	a:ml[1]	is the option name
" 	a:ml[2, ...] are the option values
"
"
fun! s:WOCAddIndexOpt(ml)
	let opt=a:ml[1]
	let value=a:ml[2]

	if opt == "alias" && value != ''
	
		"call Decho("opt alias: ", opt," ",  value)

		" `value' is in the form:
		" 	alias	  shortname	url
		let al = matchlist(value, '\s*\(\w\+\)\s\+\(.\+\)')
		if al == []
			echoerr 'WoC: Missing long name for alias "'.al[1] . '". Skipping.'
			return
		endif

		let short=al[1]
		let long=al[2]

		if short == "" || long == "" 
			return
		endif
		"call Decho("opt alias: short ", short ," long: ", long)
		let b:woc_index.alias[short] = substitute(long, '\s*$', '', "e")
	elseif value == ""
		echoerr "WoC: no value specified for " . opt . " Skipping."
		return
	elseif opt != ""
		let b:woc_index[opt] = value
	endif
endfun

fun! s:WoCLoadIndexFile(file)
	let file=a:file

	if !filereadable(file)
		let s:index_loaded=0

		" No index.woc could be found. Try to read the option from the
		" last loaded ones
		if has_key(s:woc_indexes, s:woc_cur_path)
			let path = s:woc_cur_path
		else
			let path = s:woc_last_path
		endif
		if has_key(s:woc_indexes, path)
			"call Decho("Loading b:woc_index from s:woc_indexes. path: " . path)
			let b:woc_index = s:woc_indexes[path]
		endif

		return
	endif
	let s:index_loaded=1

	"call Decho("Loading index.woc")

	let ln=0
	for line in readfile(file)
		let ln+=1
		if line =~ '^\s*#' || line =~ "^\s*$"
			" skip comments and new lines 
			continue
		endif
					 " option	values
		let ml = matchlist(line, '\s*\(\w\+\)\s\+\(.*\)')
		if ml != []
			if !has_key(b:woc_index, ml[1])
				" This option doesn't exist
				echoerr 'WoC: Invalid option "' . ml[1] . '" at '.file.':'. ln . '. Skipping.'
				continue
			else
				" Add the option in b:woc_index
				call s:WOCAddIndexOpt(ml)
			endif
		else
			echoerr 'WoC: Invalid syntax at line '.file.':'. ln . '. Skipping.'
			continue
		endif
	endfor
endfun

"
" WOCLoadIndex: loads "index.woc" and the options defined in it. 
fun! s:WOCLoadIndex()

	" Initialize
	call s:WOCInitialize()

	" Load options from the global index
	if g:woc_global_index != ""
		call s:WoCLoadIndexFile(g:woc_global_index)
	endif
	let file=expand("%:p:h") . '/' . g:woc_index_fname

	" Load options from ./index.woc
	call s:WoCLoadIndexFile(file)

	" Save options for future references
	let s:woc_indexes[s:woc_cur_path]=b:woc_index
endfun

"
" WOCExtractTag: returns the WoC tag under the cursor 
"
" A WoC tag is either a standard tagword or a word delimited by
" b:woc_index.syn_ref_left and b:woc_index.syn_ref_right
"
fun! s:WOCExtractTag()
	"
	" Extract the tag
	" 
	
	" Find the left delimiter of the tag: {-
	let [lnum, leftcol] = searchpos('\V' . b:woc_index.syn_ref_left, 'bcnW')
	" Find the right delimiter of the tag: -}
	let [rnum, rightcol] = searchpos('\V' . b:woc_index.syn_ref_right, 'cnW')
	let [curbuf, curlin, curcol, curoff]  = getpos(".")
	" Have we found something?
	let rlfound=([lnum, leftcol] != [0,0] && [rnum, rightcol] != [0,0] && lnum == rnum && lnum == curlin)

	" Do we have at our left a right delimiter ?
	let [lrnum, lrightcol] = searchpos('\V' . b:woc_index.syn_ref_right, 'bcnW')
	let leftright=([lrnum, lrightcol] != [0,0] && lrightcol > leftcol && lrightcol < rightcol && lrnum == curlin)
	" Do we have at our right a left delimiter ?
	let [rlnum, rleftcol] = searchpos('\V' . b:woc_index.syn_ref_left, 'cnW')
	let rightleft=([rlnum, rleftcol] != [0,0] && rleftcol < rightcol && rleftcol > leftcol && rlnum == curlin)
	
	"call Decho("TAGextract: " . string([lnum, leftcol]) . string([rnum, rightcol]) . " ", curcol, " ", rlfound, " ", leftright, " ", rightleft, " ", lrightcol, " ", rleftcol)
	if rlfound && leftcol < curcol && curcol < rightcol && !(leftright && rightleft)
		let l=leftcol + strlen(b:woc_index.syn_ref_left) - 1
		let r=rightcol - strlen(b:woc_index.syn_ref_right)
		let tagword = getline(".")[l : r]
	else
		" Get the tagword in the standard way
		let tagword = expand("<cword>")
		"call Decho("Falling back to normal tagword")
	endif

	return tagword
endfun

"
" WOCExpandAlias: If `alias' is mapped, it returns its expantion, otherwise 
" 		  "" is returned.
fun! s:WOCExpandAlias(alias)
	if has_key(b:woc_index.alias, a:alias)
		return b:woc_index.alias[a:alias]
	else
		return ""
	endif
endfun


" 
" WOCExtractVIandTAGcmd: Given a tag, it extracts the vi command and the tag 
" 			 command.
" It returns [baretag, vicmd, tagcmd]
" where baretag is `tag' without vicmd and tagcmd
" 
" If vicmd wasn't specified in the tag, then vicmd = ""
" the same applies to tagcmd.
"
fun! s:WOCExtractVIandTAGcmd(tag)

	" Do you know a better way to do it without 'VERYMAGICCOLON' ? ;)
	let fullvicmd = substitute(a:tag, '\\:', 'VERYMAGICCOLON', 'g')
	let baretag   = substitute(fullvicmd, ':[^:]*$', '', '')
	let baretag   = substitute(baretag, 'VERYMAGICCOLON', ':', 'g')
	let fullvicmd = matchstr(fullvicmd, ':[^:]*$')
	let fullvicmd = substitute(fullvicmd, 'VERYMAGICCOLON', ':', 'g')
	
	let vicmd  = substitute(fullvicmd, '"[^"]*$', '', '')
	let tagcmd = matchstr(fullvicmd, '"[^"]*$')[1:]

	return [baretag, vicmd, tagcmd]
endfun

" 
" WOCFakeTagJump: hack: create a temp tag file, write on it a fake tag, which points  
" to a:file as a tag. Finally jump on the tag, and remove the temp file.
"
fun! s:WOCFakeTagJump(file)
	let file=a:file

	let tmpfile = tempname()
	let tag=substitute(tmpfile, '/','', 'g')
	let tagline = tag . "\t".fnamemodify(file, ":p")."\t"."0"
	call writefile([tagline], tmpfile)
	"call Decho("Writing ", tagline," in ", tmpfile)
	exe "set tags+=" . tmpfile
	exe "tag ". tag
	exe "set tags-=" . tmpfile
	call system("rm " . tmpfile)
endfun


"
" WOCTagCmd: executes a tag command. This is the main function.	
"	
" `a:1' is one of the following:
"
"	--- WoC tags commands ---
"	j:  Jump to this tag (default)
"	r:  Reverse jump: find references to this tag
"	fj: File Jump: Open this file
"
"	--- cscope find commands ---
"       c: Find functions calling this function
"       d: Find functions called by this function
"       e: Find this egrep pattern
"       f: Find this file
"       g: Find this definition
"       i: Find files #including this file
"       s: Find this C symbol
"       t: Find assignments to
"
" `a:2' is the tag. If it's not specified, it will be set to the tag
" under the cursor.
"
" The command specified in `a:1' takes priority over that specified in `a:2'.
" For example, if the tag is {-mytag:"c-} and `a:1' is 'j', then the action
" would be "Jump to this tag" and not "Find functions calling this function"
"
fun! s:WOCTagCmd(...)
	
	let cmd = ""
	if a:0 >= 1
		let cmd = a:1
	endif

	if cmd == "help" 
		echo "\nUsage:	Woctags [tagcmd [tag]]\n" . 
\"		\n".
\"	`tagcmd` specifies the tag command to be executed. It can be\n".
\"	one of the following:\n".
\"\n".
\"	--- WoC tags commands ---\n".
\"	j:  Jump to this tag (default)\n".
\"	r:  Reverse jump: find references to this tag\n".
\"	fj: File Jump: Open this file\n".
\"\n".
\"	--- cscope find commands ---\n".
\"        c: Find functions calling this function\n".
\"        d: Find functions called by this function\n".
\"        e: Find this egrep pattern\n".
\"        f: Find this file\n".
\"        g: Find this definition\n".
\"        i: Find files #including this file\n".
\"        s: Find this C symbol\n".
\"        t: Find assignments to\n".
\"\n"
		return
	endif


	" Get the tag under the cursor if a:2 wasn't specified
	if a:0 == 2
		let fulltag = a:2
	else
		let fulltag = s:WOCExtractTag()
		"call Decho("D: Extracted tag: ", fulltag)
	endif

	" Extract the bare tag, the VI cmd, and the TAG cmd
	let [fulltag, vicmd, tagcmd] = s:WOCExtractVIandTAGcmd(fulltag)
	let tag=fulltag

	" Extract the URL from the tag (if any)
	let fullurl = matchstr(fulltag, '.*/')
	let url = matchstr(fullurl, '[-.[:alnum:]_~]\+/')[:-2]
	if url != ""
		" The tag has a `/' in it, it might be a remote tag
		let alias = url
		
		" expand the alias (if any)
		let url = s:WOCExpandAlias(alias) 
		if url == ""
			" alias not found.
			" Use all the '.*/' as URL
			let url = fullurl
		else
			" Include in the url the path defined between the alias
			" and the tag
			let url = substitute(fullurl, '\V'.alias, url, '')
		endif
		
		if url !~ '/$'
			let url .= '/'
		endif

		"call Decho("D: URL: ",url)
		if tagcmd != "fj" 
		" If the tag command isn't `file jump': 

			" download the remote tags file, and
			" prepare for the hyperjump
			" Note, if successful, it does a lcd to
			" the cache dir
			call s:WOCLoadRemote(url) 	

			" Reload the tags file
			exe "set tags-=" . b:woc_index.woc_tags_file
			exe "set tags+=" . b:woc_index.woc_tags_file

		"call Decho("D: curdir " . getcwd() . ". tagfiles: ". string(tagfiles()))
		endif

		let tag = matchstr(fulltag, '/[^/]*$')[1:]
		"call Decho("D: tag: ", tag)
		"call Decho("D: taglist: ", tagfiles())
	endif

	if cmd == ""
		let cmd = tagcmd
	endif
	if cmd == ""
		" If no command has been specified, assume the default (jump)
		let cmd = 'j'
	endif
	
	"call Decho('D: vicmdtag: ' . string([tag, vicmd, tagcmd, cmd]))
	let oldfile=expand("%:p")

	if cmd == "fj"
		" File jump

		" Revert back to old dir
		exe 'lcd ' . b:woc_cur_path

		call s:WOCFakeTagJump(url . tag)
		"exe "edit " . url . tag 
	elseif tag != ""
		" tag is not null, at least

		if has("cscope")
			set nocsverb
			if filereadable("cscope.out")
				cs add cscope.out
			endif
			if filereadable(".woc/cscope.out")
				cs add .woc/cscope.out
			endif
		endif

		if cmd == "j"
			" Jump
			"         <o/
			"          |_
			"         /'
			"
			exe "tag " . tag

		elseif cmd == "r"
			" Reverse jump
			"
			"         \._
			"          |
			"         <0\
			"      ~~~~~~~~~
			"call Decho("D: revjump ", tag)
			exe "set tags+=" . b:woc_index.woc_revtags_file
			"call Decho("D: revjump list ",  tagfiles())
			exe "tag " . tag
			exe "set tags-=" . b:woc_index.woc_revtags_file
		else
			" A cscope command
			exe "cscope find " . cmd . " " . tag
		endif
	endif

	if expand("%:p") == oldfile
		" We didn't jump to a new file, thus revert back to our
		" previous dir
		exe 'lcd ' . b:woc_cur_path
	endif
	
	" And that's all folks
	"call Decho("D: Executing ", vicmd)
	execute vicmd
endfun

" 
fun! s:WOCLoadRemote(url)
	let url=a:url

	"
	" Check if the url is local
	" 
	if url =~ '^/' || url =~ '^file://' || url !~ '^\w\+://'
		let url = substitute(url, 'file://', '', '')
		let url=substitute(url, '/$', '', '')
		"call Decho("Loading local url: " . url )

		" Check if we are in the cache dir
		let cachedir=simplify(fnamemodify(expand("$WOC_HOME"), ":p").'/cache')
		let fullpath=getcwd()
		"call Decho("Loading local url: cur dir " . fullpath )
		if fullpath =~ cachedir
			" Load the tags files
			let md5dir=matchlist(fullpath, 'cache/\(\w\+\)')[1]
			if has_key(s:woc_cache_url, md5dir)
				let url2=s:woc_cache_url[md5dir]

				if url2 =~ '%s'
					let url3=url
					if url =~ '^/'| let url3 = url[1:]| endif
					let url2=substitute(url2, '%s', url3, '')
				else
					if url2 !~ '/$' | let url2 .= '/' | endif
					let url2 = url2 . url
				endif
				
				let prefix=matchstr(url2, '^\w\+://')
				let url3=matchstr(url2, '://.*')[3:]
				let url2=prefix . simplify(url3)

				"call Decho("Calling s:WOCLoadRemote a II time. url2: ". url2)
				call s:WOCLoadRemote(url2)
			else
				" We are in the cache dir, and the directory doesn't
				" exist. Just create it.
				call mkdir('./'.url, 'p')
			endif
		else
			if isdirectory('./'.url)
				exe 'lcd ' . './'.url
			endif
		endif

		return
	endif

	" The URL passed to `wocdownloader', must always have one %s, which
	" will be substituted with the file to download
	if url !~ '%s'
		if url =~ '/$'
			let url.='%s'
		else
			let url.='/%s'
		endif
	endif

	echo "Downloading " . url
	"call Decho("Downloading " . url)
	"call Decho(expand("$WOC_HOME") . '/'. "wocdownloader " . '"'.url.'"')

	"let md5cache=system('bash -x ' . expand("$WOC_HOME") . '/'. "wocdownloader " . '"'.url.'"'. ' 2> /tmp/LOOGS')
	let md5cache=system(expand("$WOC_HOME") . '/'. "wocdownloader " . '"'.url.'"')
	if v:shell_error == 0
		if md5cache != ""
			"call Decho("Entering in " . md5cache )
			exe 'lcd ' . md5cache
			let md5=matchlist(md5cache, 'cache/\(\w\+\)')[1]
			if url !~ '^\w\+://'
				let url = 'http://' . url
			endif

			" |{woc_cache_url}|
			let s:woc_cache_url[md5]=url
		else
			echoerr "No tag files could be found in \"" . url . '"'
		endif
	endif
endfun

"
" WOCClearCache: clear the woc cache 
"
" If a:1 is set to a non-zero value, the whole cache dir will be removed,
" otherwise only the used subdirs will be cleaned.
"
fun! s:WOCClearCache(...)
	let home=fnamemodify(expand("$WOC_HOME"), ":p")

	if home == "/" || (home !~ simplify(expand("$HOME").'/').'.*\w\+' && home !~ "/tmp")
		echoerr "$WOC_HOME is set to a dangerous place (".home.")!\n" . "No cache cleaning"
		return
	endif

	if a:0 >= 1 && a:1
		echo "WoC: Cleaning the whole cache"
		"call Decho("rm -rf " . expand("$WOC_HOME").'/cache/')
		call system("rm -rf " . expand("$WOC_HOME").'/cache/')
	else
		if exists("s:woc_cache_url") && s:woc_cache_url != {}
			echo "WoC: Cleaning the last used cache"
			for key in keys(s:woc_cache_url)
				"call Decho("rm -rf " . expand("$WOC_HOME").'/cache/'.key)
				call system("rm -rf " . expand("$WOC_HOME").'/cache/'.key)
			endfor
		endif
	endif
endfun


"
" WOCOpenFile: called when a file is opened 
"
" If a:file is in the woc cache dir, then try to download it from the remote
" url
fun! s:WOCOpenFile(file)
	call s:WOCLoadIndex()
	
	let cachedir=simplify(fnamemodify(expand("$WOC_HOME"), ":p").'/cache')
	let fullpath=fnamemodify(expand(a:file), ":p")
	let url=""
	"call Decho("Wrapping " . fullpath)

	if fullpath =~ cachedir
		let file=matchlist(fullpath, 'cache/\w\+/\(.*\)$')[1]
		let md5dir=matchlist(fullpath, 'cache/\(\w\+\)')[1]
		let md5dirpath=matchstr(fullpath, '.*/cache/\(\w\+\)')
		if has_key(s:woc_cache_url, md5dir)
			let url=s:woc_cache_url[md5dir]
		endif
		"call Decho("Wrapping cache " . fullpath, " url: ", url, " md5: ", md5dirpath," ", md5dir  )

		exe "lcd " . md5dirpath
		echo "Downloading file: " . file
		"call Decho("Downloading file: " . file, " url: ", url)
		"call Decho("woc_cache_url: ", string(s:woc_cache_url))
		let md5cache = system(expand("$WOC_HOME") . '/'. "wocdownloader " . '"'.url.'"' . ' "' . file .'"')
		if v:shell_error == 1 || md5cache == ""
			echoerr "File \"" . file ."\" could not be downloaded"
			" going back
			pop
		else
			exe "edit " . fullpath
			exe "silent doau BufRead ".fullpath
		endif
	endif
endfun


""
"""" Syntax stuff
"" 

"
" Function: s:WOCTuneCommentSyntax() 
" Entirely ripped from the vimspell plugin
"
" -- 
" Add support to do spell checking inside comment. Idea from engspchk.vim from
" Dr. Charles E. Campbell, Jr. <Charles.Campbell.1@gsfc.nasa.gov>.
" This can be done only for those syntax files' comment blocks that
" contains=@cluster.
function! s:WOCTuneCommentSyntax(ft)
  if !exists("b:woc_syntax_ft") || b:woc_syntax_ft != a:ft
    let b:woc_syntax_ft = a:ft
    " Special treatment for filetype which do not use @Spell cluster.
    if     a:ft == "amiga"
      syn cluster amiCommentGroup               add=wocHyperTextJump,wocHyperTextEntry
      " highlight only in comments (i.e. if wocHyperTextJump are contained).
      let b:woc_syntax_options = "contained"
    elseif a:ft == "bib"
      syn cluster bibVarContents        contains=wocHyperTextJump,wocHyperTextEntry
      syn cluster bibCommentContents    contains=wocHyperTextJump,wocHyperTextEntry
      let b:woc_syntax_options = "contained"
    elseif a:ft == "c" || a:ft == "cpp"
      syn cluster cCommentGroup         add=wocHyperTextJump,wocHyperTextEntry
      let b:woc_syntax_options = "contained"
    elseif a:ft == "python" || a:ft == "py"
    "  syn cluster pythonComment  	add=wocHyperTextJump,wocHyperTextEntry
      syn match pythonComment /#.*$/  contains=pythonTodo,wocHyperTextJump,wocHyperTextEntry
      let b:woc_syntax_options = "contained"
    elseif a:ft == "csh"
      syn cluster cshCommentGroup               add=wocHyperTextJump,wocHyperTextEntry
      let b:woc_syntax_options = "contained"
    elseif a:ft == "dcl"
      syn cluster dclCommentGroup               add=wocHyperTextJump,wocHyperTextEntry
      let b:woc_syntax_options = "contained"
    elseif a:ft == "fortran"
      syn cluster fortranCommentGroup   add=wocHyperTextJump,wocHyperTextEntry
      syn match   fortranGoodWord contained     "^[Cc]\>"
      syn cluster fortranCommentGroup   add=fortranGoodWord
      hi link fortranGoodWord fortranComment
      let b:woc_syntax_options = "contained"
    elseif a:ft == "sh" || a:ft == "ksh" || a:ft == "bash"
      syn cluster shCommentGroup                add=wocHyperTextJump,wocHyperTextEntry
    elseif a:ft == "b"
      syn cluster bCommentGroup         add=wocHyperTextJump,wocHyperTextEntry
      let b:woc_syntax_options = "contained"
    elseif a:ft == "xml"
      syn cluster xmlText               add=wocHyperTextJump,wocHyperTextEntry
      syn cluster xmlString             add=wocHyperTextJump,wocHyperTextEntry
      syn cluster xmlRegionHook add=wocHyperTextJump,wocHyperTextEntry

      let b:woc_syntax_options = "contained"
    elseif a:ft == "tex"
      syn cluster texCommentGroup               add=wocHyperTextJump,wocHyperTextEntry

      syn cluster texMatchGroup         add=wocHyperTextJump,wocHyperTextEntry

    elseif a:ft == "vim"
      syn cluster vimCommentGroup               add=wocHyperTextJump,wocHyperTextEntry

      let b:woc_syntax_options = "contained"
    elseif a:ft == "otl"
      syn cluster otlGroup              add=wocHyperTextJump,wocHyperTextEntry
      let b:woc_syntax_options = "contained"
    endif

    " by default, only errors in Spell cluster are highlight
    if !exists("b:woc_syntax_options")
      let b:woc_syntax_options = "contained"
    endif
  endif
endfunction

" WOCSyntax: set the syntax for the WoC tags
fun! s:WOCSyntax()
	" Our syntax
	" Highlights {-TAG-} and |{TAG}|
	syn match wocHyperTextJump   "{-\(\({-\)\@!.\)*-}" contains=wocLeftRef,wocRightRef
			             "\({-\).\+-}" (old regexp)
	syn match wocHyperTextEntry  "|{\(\(|{\)\@!.\)*}|" contains=wocLeftDef,wocRightDef
				     "|{.\+}|" (old regexp)
	syn match wocLeftRef               contained "{-"
	syn match wocRightRef              contained "-}"
	syn match wocLeftDef               contained "|{"
	syn match wocRightDef              contained "}|"
"	hi def link wocHyperTextJump   Identifier
	hi def wocHyperTextJump ctermfg=Cyan guifg=Cyan cterm=underline gui=underline term=reverse
	hi def link wocHyperTextEntry  String
	hi def link wocLeftRef         Ignore
	hi def link wocLeftDef         Ignore
	hi def link wocRightRef        Ignore
	hi def link wocRightDef        Ignore

	call s:WOCTuneCommentSyntax(&l:ft)
endfun

let &cpo = s:save_cpo 
finish
" EOF

Disable debug:
{-:%s/\([^"]\)c[a]ll Decho/\1"call\ Decho/g | '' "-}
Enable debug:
{-:%s/"c[a]ll Decho/call\ Decho/g | '' "-}
