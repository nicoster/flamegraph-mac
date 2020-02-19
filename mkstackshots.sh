#!/bin/sh -x

sudo -E luajit stackshots.lua $1 -f ${2:-50} -t ${3:-10} | tee /tmp/stackshots.out

trap ctrl_c INT

function ctrl_c() {
    if [[ -f stackshots.pid ]]; then
        kill -s INT `cat stackshots.pid`
    fi
}

if [[ "$?" -eq "0" ]] ; then
    stackshots=`tail -1 /tmp/stackshots.out |awk '{print $5}' `
    echo $stackshots
    mkdir -p ${stackshots%.*}
    ./foldstackshots.sh $stackshots
fi
