#!/bin/sh -x

sudo -E luajit stackshots.lua $1 -f ${2:-50} -t ${3:-10} | tee /tmp/stackshots.out

if [[ "$?" -eq "0" ]] ; then
    stackshots=`tail -1 /tmp/stackshots.out |awk '{print $5}' `
    echo $stackshot
    ./foldstackshots.sh $stackshot
fi
