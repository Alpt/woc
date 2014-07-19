echo "[*] Creating ~/.vim/woc and copying stuff in it"
if [ ! -d ~/.vim/woc ]; then mkdir -p ~/.vim/woc; fi
cp wocdownloader ~/.vim/woc

echo "[*] Copying woc.vim in ~/.vim/plugin/"
if [ ! -d ~/.vim/plugin ]; then mkdir -p ~/.vim/plugin; fi
cp woc.vim ~/.vim/plugin/

echo "[+] Done"
echo "    The last thing is up to you: if you want to use ./woctags.sh, then"
echo "    copy it somewhere in your PATH (f.e. /usr/bin/)"
