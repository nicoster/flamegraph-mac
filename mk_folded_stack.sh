$!/bin/sh


sudo -E luajit stackshots.lua $1 -f $2 -t $3

/usr/bin/python kcdata.py --multiple /tmp/pid%43887@1581862753585.9.stackshot | sed '1s/^{/\[{/; s/^}$/},/g; $s/},$/}\]/; ' > kcdata-multiple.json

./stackcollapse-stackshot.lua kcdata-multiple.json 