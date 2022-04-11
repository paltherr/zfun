#!/bin/zsh

path[1,0]=(${0:h}/../src/bin);
fpath[1,0]=(${0:h}/../src/functions);

. zfun.zsh;

function as-kv() {
    while [[ $# -gt 0 ]]; do
        echo -nE - "[$1]=$2";
        shift 2;
        [[ $# -eq 0 ]] || echo -nE - " ";
    done
}

function show() {
    while [[ $# -ge 1 ]]; do
        if [[ "${(tP)+1}" -ne 1 ]]; then
            echo -nE - "$1 is undefined";
        else
            case "${(tP)1}" in
                scalar* | integer* | float* ) echo -nE - "$1=${(q+P)1}";;
                array*                      ) echo -nE - "$1=(${(q+)${(P)1}[@]})";;
                association*                ) echo -nE - "$1=($(as-kv ${(q+kv)${(P)1}[@]}))";;
                *                           ) echo -nE - "$1 is of unsupported type: ${(tP)1}";;
            esac;
        fi;
        shift 1;
        [[ $# -eq 0 ]] || echo -nE - ", ";
    done;
    echo;
}

function show-reply() {
    show $(reply-name "$@");
}

function reply-name() {
    echo _zfun_reply_${1:-1};
}
