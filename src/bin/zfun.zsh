#!/bin/zsh
################################################################################

# WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING

# THIS IS STILL VERY EXPERIMENTAL. NON BACKWARD INCOMPATIBLE API
# CHANGES ARE STILL POSSIBLE. USE AT YOUR ON RISKS.

# WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING

################################################################################

. zabort.zsh;

################################################################################

IFS=$'\C-@';

################################################################################

# Warn when a function assigns a global variable.
set -o warnnestedvar;

# Warn when a function assigns a variable from an enclosing scope.
set -o warncreateglobal;

# Warn when a break or a continue propagates outside of a function.
set -o localloops;

# Restore shell options on function exit.
set -o localoptions;

# Restore pattern options on function exit.
set -o localpatterns;

# Restore signal traps on function exit.
set -o localtraps;

################################################################################

# Name of the function in the "fun … :{ … }" construct.
typeset -g _zfun_fun_name;

# Maps function names to reply types ("void", "scalar", "array", "association").
typeset -g -A _zfun_fun_type;

# Maps function names to argument names separated by spaces.
typeset -g -A _zfun_arg_names;

# Maps function names to argument types separated by spaces.
typeset -g -A _zfun_arg_types;

function _zfun-parse-fun-name() {
    local depth=$((depth+1));
    local input=$1; shift 1;
    local name=${input%%:*};
    case $name in
        ""               ) ;&
        *[!-_[:alnum:]]* ) $usage "Illegal function name: ${(qqq)name}.";;
        *                ) echo -E - "$name";
    esac;
}

function _zfun-parse-arg-name() {
    local depth=$((depth+1));
    local input=$1; shift 1;
    local name=${input%%:*};
    case $name in
        ""              ) ;&
        [!_[:alpha:]]*  ) ;&
        *[!_[:alnum:]]* ) $usage "Illegal argument name: ${(qqq)name}.";;
        *               ) echo -E - "$name";
    esac;
}

function _zfun-parse-type() {
    local depth=$((depth+1));
    local default=$1; shift 1;
    local input=$1; shift 1;
    case $input in
        *:*:* ) $usage "Invalid type: ${(qqq)input#*:}.";;
        *:s   ) echo scalar;;
        *:a   ) echo array;;
        *:A   ) echo association;;
        *:*   ) $usage "Invalid type: ${(qqq)input#*:}.";;
        *     ) echo -E - "$default";;
    esac;
}

function _zfun-fun-usage() {
    local depth=$((depth+1));
    local self=$funcstack[$depth];
    local error=(
        "$1"
        "Usage: $self name arg1 ... argN :{ ... }"
        "       $self name \"arg1 ... argN\" :{ ... }"
    );
    usage -$((depth-1)) ${(F)error}
}

# Usage:
# - fun name arg1 ... argN :{ ... }
# - fun name "arg1 ... argN" :{ ... }
# - fun "name(arg1 ... argN)" :{ ... }
# TODO: Add support for flags.
# TODO: Add support for optional parameters.
# TODO: Add support for final catch-all parameter.
function fun() {
    local usage=${usage:-_zfun-fun-usage};
    local depth=$((${depth:-0}+1));

    [[ $# -ge 1 ]] || $usage "A function name and the token :{ are required.";
    [[ ${@[$#]} = *:\{ ]] || $usage "The token :{ is required.";
    [[ ${@[$#]} = :\{ ]] || $usage "The token :{ must be preceded by a space.";
    [[ $# -ge 2 ]] || $usage "A function name is required.";

    local fun=$1; shift 1;
    local fun_name=$(_zfun-parse-fun-name "$fun");
    local fun_type=$(_zfun-parse-type void "$fun");

    # TODO: Add support for syntax 'fun "name(arg1 arg2)" { ... }'
    local args=("${@[1,-2]}"); shift $#args;
    [[ $#args -ne 1 ]] || args=(${(s: :)args});

    local arg_names=();
    local arg_types=();
    local arg;
    for arg in "${args[@]}"; do
        arg_names+=($(_zfun-parse-arg-name "$arg"));
        arg_types+=($(_zfun-parse-type scalar "$arg"));
    done;

    typeset -g _zfun_fun_name=$fun_name;
    _zfun_fun_type[$fun_name]=$fun_type;
    _zfun_arg_names[$fun_name]="$arg_names";
    _zfun_arg_types[$fun_name]="$arg_types";
}

################################################################################

function _zfun-args-show() {
    echo -E - "${#}${${(j: :)${(qqq)@}}/\"/: \"}";
}

function _zfun-args-parse() {
    local fun_name=$funcstack[2];
    local fun_type=${_zfun_fun_type[$fun_name]};

    # If the function has a reply value, set up a reply variable. It's
    # not possible to write directly into a user provided variable
    # because the function could have a local variable with the same
    # name, which would hide the provided variable.
    if [[ $fun_type != void ]]; then
        # With nested function calls, multiple reply variables may be
        # needed at the same time. In the worst case, one variable per
        # stack frame is required.
        local reply_frame=$(($#funcstack - 1));
        local reply_name=_zfun_reply_$reply_frame;
        echo "local _zfun_reply_name=$reply_name;";
        echo "local _zfun_reply_type=$fun_type;";
        # We keep track of the reply's stack frame to ensure that
        # replies are only set from within the body of the function
        # and not from nested function calls.
        echo "local _zfun_reply_frame=$reply_frame;";
        # We keep track of the reply's shell to ensure that replies
        # are only set from within the same shell. Setting replies
        # from subshells is impossible because subshells can't modify
        # variables of their parent shell.
        echo "local _zfun_reply_shell=\$ZSH_SUBSHELL;";
        # Unset the reply variable to ensure that replies from
        # previous function calls won't affect this function's reply.
        echo "unset $reply_name;";
    fi;

    local arg_names=(${=_zfun_arg_names[$fun_name]});
    local arg_types=(${=_zfun_arg_types[$fun_name]});
    local arg_count=$#arg_names;

    [[  $# -eq $arg_count ]] ||
        usage -1 "Expected $arg_count argument(s), got $(_zfun-args-show "$@").";

    if [[ $arg_count -ge 1 ]]; then
        local i;
        for i in {1..$arg_count}; do
            case $arg_types[$i] in
                scalar      ) echo "local $arg_names[$i]=\$$i;";;
                array       ) echo "local -a $arg_names[$i]=(\${=$i});";;
                association ) echo "local -A $arg_names[$i]=(\${=$i});";;
                *           ) abort "Unrecognised type: ${(qqq)arg_type[$i]}";;
            esac;
        done;
    fi;
}

alias -g ':{'='":{"; function $_zfun_fun_name { eval $(_zfun-args-parse "$@");';
alias -g ":{}"=':{ }'

################################################################################

# TODO: Write tests that directly test this function.
function _zfun-write() {
    local var_name=$1; shift 1;
    local var_type=$1; shift 1;
    local operator=$1; shift 1;

    local state=$var_type-$operator-${(P)+var_name};
    case $state in
        scalar-set-? ) ;&
        scalar-add-0 ) typeset -g $var_name=$1;;
        scalar-add-1 ) eval $var_name'[-1]'+='$1';;

        array-set-? ) ;&
        array-add-0 ) eval typeset -g -a $var_name='( "$@" )';;
        array-add-1 ) eval $var_name'[-1]'+='( "$@" )';;

        association-set-? ) ;&
        association-add-0 ) eval typeset -g -A $var_name='( "$@" )';;
        association-add-1 ) while (($#)) do eval $var_name'[$1]'='$2'; shift 2; done;;

        * ) abort "Unrecognised state: ${(qqq)state}";;
    esac;
}

################################################################################

function _zfun-reply-write() {
    local operator=$1; shift 1;

    # Tolerate calls to "reply" within "eval" expressions.
    [[ -v _zfun_reply_frame && ${#${funcstack[3,-1-${_zfun_reply_frame}]#\(eval\)}} -eq 0 ]] ||
        usage -1 "Replies can only be set from within functions that have a reply value.";
    [[ $_zfun_reply_shell -eq $ZSH_SUBSHELL ]] ||
        usage -1 "Replies can not be set from within subshells.";
    [[ $_zfun_reply_type != scalar ]] || [[ $# -eq 1 ]] ||
        usage -1 "Scalar replies require exactly one value, got $(_zfun-args-show "$@").";
    [[ $_zfun_reply_type != association ]] || [[ $(($# % 2)) -eq 0 ]] ||
        usage -1 "Association replies require key/value pairs, got dangling key: ${(qqq)@[-1]}.";

    _zfun-write $_zfun_reply_name $_zfun_reply_type $operator "$@";
}

function r:set() {
    _zfun-reply-write set "$@";
}

function r:add() {
    _zfun-reply-write add "$@";
}

################################################################################

# TODO: write more tests
function var:=() {
    local var_name=$1; shift 1;
    local fun_name=$1; shift 1;
    local fun_type=${_zfun_fun_type[$fun_name]:-void};

    [[ $fun_type != void ]] ||
        abort "Only functions with reply values may be use in variable assignments.";

    $fun_name "$@";
    local exit_status=$?

    # TODO: Should this be moved to an EXIT trap of the called function?
    local reply_name=_zfun_reply_$(($#funcstack + 1));
    _zfun-write $var_name $fun_type set "${(kv)${(P)reply_name}[@]}";
    return $exit_status;
}

################################################################################

# Name of the variable in the "var … := … " construct.
typeset -g _zfun_var_name;

# TODO: Add detection of misuage of the token := like in the function "fun".
# TODO: Add support for += to append values.
function var() {
    typeset -g _zfun_var_name=$1;
}

# Space at the end to trigger alias resolution on first argument.
galiases[:=]="; local \$_zfun_var_name=; unset \$_zfun_var_name; var:= \$_zfun_var_name ";

################################################################################
