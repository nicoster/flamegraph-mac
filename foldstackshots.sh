#!/bin/sh

stackshots=$1
/usr/bin/python kcdata.py --multiple $stackshots \
| sed '1s/^{/\[{/; s/"lr": \([0-9]\{1,\}\)/"lr": "\1"/g; s/^}$/},/g; $s/},$/}\]/; ' > $stackshots.json \
&& ./stackcollapse-stackshot.lua $stackshots.json