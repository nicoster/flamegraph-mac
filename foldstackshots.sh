#!/bin/sh

stackshots=$1
echo 'fold ' $stackshots
basename=${stackshots%.*}
mkdir -p $basename
/usr/bin/python kcdata.py --multiple $stackshots \
| sed '1s/^{/\[{/; s/"lr": \([0-9]\{1,\}\)/"lr": "\1"/g; s/^}$/},/g; $s/},$/}\]/; ' > $basename.json \
&& ./stackcollapse-stackshot.lua $basename.json | tee $basename.fold_result \
&& for f in `ls -1 $basename`; do
    echo convert $f to ${f%.*}.svg
    ./flamegraph.pl $basename/$f > $basename/${f%.*}.svg \
    && rm $basename/$f
done