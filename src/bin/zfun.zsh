#!/bin/zsh
################################################################################

# WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING

# THIS IS STILL VERY EXPERIMENTAL. BACKWARD INCOMPATIBLE API CHANGES
# ARE STILL POSSIBLE. USE AT YOUR ON RISKS.

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

function _zfun_check-token-expansion() {
  local depth=$((depth+1));
  local token=$1; shift 1;
  local token_index=$@[(i)*$~token*];
  if [[ $token_index -le $# ]]; then
    [[ $@[token_index] != *?$~token ]] || $usage "The token $token must be preceded by a space.";
    [[ $@[token_index] != $~token?* ]] || $usage "The token $token must be followed by a space.";
    [[ $@[token_index] = $~token ]] || $usage "The token $token must be preceded and followed by a space.";
    [[ -v galiases[$token] ]] || $usage "The global alias for the token $token must be enabled.";
    $usage "The token $token must be present as a literal.";
  fi;
  [[ $# -ge 1 && $@[#] = :token-expansion-marker: ]] || $usage "The token $token is required.";
}

################################################################################

# Name of the function in the "fun … :{ … }" construct.
typeset -g _zfun_fun_name;

# Maps function names to reply types ("void", "scalar", "array", "association").
typeset -g -A _zfun_fun_type;

# Maps function names to initialization code.
typeset -g -A _zfun_fun_init;

# Maps function names to argument names separated by spaces.
typeset -g -A _zfun_arg_names;

# Maps function names to argument types separated by spaces.
typeset -g -A _zfun_arg_types;

function _zfun-fun-usage() {
  local self=$funcstack[depth+1];
  local error=(
    "$1"
    "Usage: $self <function-name>[:<reply-type>] [(<parameter-name>[:<parameter-type>])…] :{ … }"
    "       $self <function-name>[:<reply-type>] \"[(<parameter-name>[:<parameter-type>])…]\" :{ … }"
  );
  usage -$depth ${(F)error}
}

# Usage:
# - fun <function-name>[:<reply-type>] [(<parameter-name>[:<parameter-type>])…] :{ … }
# - fun <function-name>[:<reply-type>] "[(<parameter-name>[:<parameter-type>])…]" :{ … }
# TODO: Add support for flags.
# TODO: Add support for optional parameters.
# TODO: Add support for final catch-all parameter.
function fun() {
  local usage=_zfun-fun-usage;
  local depth=1;

  _zfun_check-token-expansion ":{" "$@"; argv[#]=();

  [[ ${#@} -ge 1 ]] || $usage "A function name is required.";
  local fun=$1; shift 1;
  local fun_name=$(_zfun-parse-fun-name "$fun");
  local fun_type=$(_zfun-parse-type void "$fun");

  # TODO: Add support for syntax 'fun "name(arg1 arg2)" { ... }'
  [[ $# -ne 1 ]] || argv=(${(s: :)@});

  local arg_names=();
  local arg_types=();
  local arg;
  for arg; do
    arg_names+=($(_zfun-parse-arg-name "$arg"));
    arg_types+=($(_zfun-parse-type scalar "$arg"));
  done;

  typeset -g _zfun_fun_name=$fun_name;
  _zfun_fun_type[$fun_name]=$fun_type;
  _zfun_arg_names[$fun_name]="$arg_names";
  _zfun_arg_types[$fun_name]="$arg_types";

  local local__=();
  local local_A=();
  local fun_init=();

  local arg_count=$#arg_names;
  local arg_error="\"Expected $arg_count argument(s), got \$(_zfun-args-show \"\$@\").\"";
  fun_init+="[[ \$# -eq $arg_count ]] || usage -1 $arg_error";
  if [[ $arg_count -ge 1 ]]; then
    local i;
    for i in {1..$arg_count}; do
      case $arg_types[i] in
        scalar      ) local__+="$arg_names[i]=\$$i";;
        array       ) local__+="$arg_names[i]=(\${=$i})";;
        association ) local_A+="$arg_names[i]=(\${=$i})";;
        *           ) abort "Unrecognised type: ${(qqq)arg_type[$i]}";;
      esac;
    done;
  fi;

  # If the function has a reply value, set up a reply variable. It's
  # not possible to write directly into a user provided variable
  # because the function may have a local variable with the same,
  # which would hide it.
  if [[ $fun_type != void ]]; then
    # The reply's shell. Used to ensure that replies are only set
    # from within the same shell (because subshells can't modify
    # variables of their parent shell).
    local__+="_zfun_reply_shell=\$ZSH_SUBSHELL";
    # The reply's stack frame. Used to ensure that replies are set
    # from within the function's body and not from within nested
    # function calls.
    local__+="_zfun_reply_frame=\$((\$#funcstack-1))";
    # The reply's variable. With nested function calls, multiple
    # reply variables may be needed at the same time. In the worst
    # case, one variable per stack frame is needed.
    local__+="_zfun_reply_name=_zfun_reply_\$((\$#funcstack-1))";
    # The reply's type.
    local__+="_zfun_reply_type=$fun_type";
  fi;

  [[ $#local__ -eq 0 ]] || fun_init+="local ${(j: :)local__}";
  [[ $#local_A -eq 0 ]] || fun_init+="local -A ${(j: :)local_A}";

  if [[ $fun_type != void ]]; then
    # Unset the reply variable. It may have been set by previous
    # function calls.
    fun_init+="unset \$_zfun_reply_name";
  fi;

  _zfun_fun_init[$fun_name]=${(j:; :)fun_init};
}

################################################################################

function _zfun-args-show() {
  echo -E - "${#}${${(j: :)${(qqq)@}}/\"/: \"}";
}

alias -g ':{'=':token-expansion-marker:; function $_zfun_fun_name { eval "$_zfun_fun_init[$0]"; ';
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
    association-add-1 ) while (($#)); do eval $var_name'[$1]'='$2'; shift 2; done;;

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

# Name of the variable in the "var … := … " construct.
typeset -g _zfun_var_name;

function _zfun-var-usage() {
  local error=(
    "$1"
    "Usage: var <variable-name> := <function-name> [<argument>…]"
  );
  usage -$depth ${(F)error}
}

# Usage:
# - var <variable-name> := <function-name> [<argument>…]
# TODO: Add support for += to append values.
function var() {
  local usage=_zfun-var-usage;
  local depth=1;

  if [[ ${1:-} = :var-callback-marker: ]] && shift 1; then
    local var_name=$_zfun_var_name;

    [[ $# -ge 1 ]] || $usage "A function call is required.";
    local fun_name=$1; shift 1;
    local fun_type=${_zfun_fun_type[$fun_name]:-void};
    [[ $fun_type != void ]] ||
      $usage "Function ${(qqq)fun_name} has no reply value. It can't be used with \"var\".";

    $fun_name "$@"; local exit_status=$?

    # TODO: Should this be moved to an EXIT trap of the called function?
    local reply_name=_zfun_reply_$(($#funcstack + 1));
    [[ ${(P)+reply_name} -eq 1 ]] ||
      abort -1 "Function ${(qqq)fun_name} returned without setting a reply.";
    _zfun-write $var_name $fun_type set "${(kv)${(P)reply_name}[@]}";
    return $exit_status;
  fi;

  _zfun_check-token-expansion ":=" "$@"; argv[#]=();

  [[ $# -ge 1 ]] || $usage "A variable name is required.";
  [[ $# -eq 1 ]] || $usage "A single variable name is allowed, got $(_zfun-args-show "$@").";
  typeset -g _zfun_var_name=$1;
}

# Space at the end to trigger alias resolution on first argument.
galiases[:=]=':token-expansion-marker:; local $_zfun_var_name > /dev/null; unset $_zfun_var_name; var :var-callback-marker: ';

################################################################################
