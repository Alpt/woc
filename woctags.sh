#!/bin/sh


if [ "$1" == "-h" -o "$1" == "help" -o "$1" == "--help" -o "$1" == "-help" ] 
then
	echo "Usage:  woctags [dir|files] [options to 'find']"
	echo ""
	echo "Note :  By default, 'find' searches recursively the current"
	echo "        directory. To disable this behaviour use -maxdepth 1"
	echo ""
	echo "If the WOC_FILE_LIST enviroment variable has been defined, woctags.sh"
	echo "will examine only the files listed in the \$WOC_FILE_LIST file."
	exit 1
fi

#echo "[!] Use $0 -h  to get help"
exclude_files='~$|\<tags\.woc$|\<tags$|\<TAGS$|\<tags\.rev\.woc$|\<cscope.out$|\<CVS/$'

echo "[*] (re)Making .woc/ directory"
if [ -d .woc/ ]
then
	rm -f .woc/*.bz2
else
	mkdir .woc/
fi
echo "[*] Generating WoC tags files"
if [ ! -z "$WOC_FILE_LIST" ]
then
	echo "[*] Loading files list from $WOC_FILE_LIST"
	tfile=$WOC_FILE_LIST
else
	tfile=`tempfile`
	find $@  | grep -Ev "$exclude_files" > $tfile
fi

# If you want to change the syntax for the WoC tags, then have fun with
# these two regexp
exuberant-ctags -f tags.woc --langdef=woc --language-force=woc \
		--regex-woc='/\|\{(.+)\}\|/\1/d,definition/' \
		--tag-relative -L $tfile
exuberant-ctags -f tags.rev.woc --langdef=woc --language-force=woc \
		--regex-woc='/\{-(.+)(:[^:]*)-\}/\1/r,reference/' \
		--regex-woc='/\{-([^:]+)-\}/\1/r,reference/' \
		--tag-relative -L $tfile
		
if [ -z "$WOC_FILE_LIST" ]; then
	rm -f $tfile
fi


echo "[*] Compressing tags files"
for i in index.woc tags.woc tags.rev.woc tags TAGS cscope.out
do
	if [ -r "$i" ]; then
		bzip2 -fk $i
		mv $i.bz2 .woc/
	fi
done
if [ ! -f  tags -a ! -f TAGS -a ! -f cscope.out ]
then
	echo "[!] No tags file found. Did you run ctags or cscope, before"
	echo "    launching $0 ?"
	exit 0
fi
