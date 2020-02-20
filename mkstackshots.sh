#!/bin/sh -x

pid=$1
freq=${2:-50}
time=${3:-10}

function process_stackshots()
{
    if [[ -f stackshots-$pid.out ]] ; then
        stackshots=`cat stackshots-$pid.out`
        echo $stackshots
        mkdir -p ${stackshots%.*}
        ./foldstackshots.sh $stackshots
    fi
}

function ctrl_c() {
    if [[ -f stackshots.pid ]]; then
        trap INT
        sleep 1
        process_stackshots
    fi
}

trap ctrl_c INT
sudo -E luajit stackshots.lua $pid -f $freq -t $time
process_stackshots