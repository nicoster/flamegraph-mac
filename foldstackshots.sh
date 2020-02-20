#!/bin/bash 

SCRIPTDIR=$(dirname -- "$(readlink "$BASH_SOURCE" || echo $BASH_SOURCE)")
# echo BASH_SOURCE: $BASH_SOURCE
# echo SCRIPTDIR: $SCRIPTDIR

stackshots=$1
echo 'folding ' $stackshots
basename=${stackshots%.*}
mkdir -p $basename

function convert_svg()
{
    local first
    for f in `ls -1 $basename/*.folded`; do
        local svgfile=${f%.*}.svg
        echo convert $f to $svgfile
        $SCRIPTDIR/flamegraph.pl $f > $svgfile && rm $f

        if [[ "$first" -eq "" ]]; then
            first=1
            open $svgfile
        fi
    done
}

/usr/bin/python $SCRIPTDIR/kcdata.py --multiple $stackshots \
| sed '1s/^{/\[{/; s/"lr": \([0-9]\{1,\}\)/"lr": "\1"/g; s/^}$/},/g; $s/},$/}\]/; ' > $basename/stackshots.json \
&& $SCRIPTDIR/stackcollapse-stackshot.lua $basename/stackshots.json | tee $basename/fold.result \
&& convert_svg