perl xactxtract2.pl -x "Wave Bank.xwb"
cd "Wave Bank"
find . -name "*.xwma" -exec ffmpeg -i {} -ab 256k {}.m4a \; 
python makeXwb.py "Wave Bank.xwb" *.m4a