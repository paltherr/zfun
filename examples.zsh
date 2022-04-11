#!/bin/zsh

. zfun.zsh;

# Functions can be declared with named arguments.

fun substring string start end :{ # zero based indexes
    [[ 0 -le $start && $start -le $#string && $start -le $end && $end -le $#string ]] ||
        abort "Out of bound";
    echo "${string:$start:$(( $end - $start))}";
}

echo substring1: $(substring "0123456789" 0 10);
echo substring2: $(substring "0123456789" 3 8);
echo;


# Arguments can have types:
# - s: scalar (i.e., strings, integers, or floats)
# - a: array
# - A: association (aka associative array)

# For nicer syntax coloring, arguments can be declared in a single
# string argument.

fun subarray "array:a start:s end:s" :{ # zero based indexes
    [[ 0 -le $start && $start -le $#array && $start -le $end && $end -le $#array ]] ||
        abort "Out of bound";
    echo "${array[$(( 1 + $start )),$end]}"
}

array=( 0 1 2 3 4 5 6 7 8 9 );

echo subarray1: $(subarray "$array" 0 10);
echo subarray2: $(subarray "$array" 3 8);
echo;


# Functions returning arrays or associations can be used as arguments
# for parameters of the corresponding type.

fun zip "array1:a array2:a" :{
    local zipped=( ${array1:^array2} );
    echo "$zipped"; # TODO: Why doesn't it work when zipped is inlined?
}

echo zip: $(zip "$(subarray "$array" 0 5)" "$(subarray "$array" 5 10)");
echo;


# Functions can be declared as having a reply value. This is done by
# specifying a type on the function name. The reply value has to be
# set with the function “r:set“. There is also a function “r:add“ that
# adds/appends values to an already set reply value.
#
# The construct “var“ allows to call a function with a reply value and
# assign its result to a new variable.

fun zip-a:a "array1:a array2:a" :{
    r:set ${array1:^array2};
}

var zipped := zip-a "$(subarray "$array" 0 5)" "$(subarray "$array" 5 10)";

echo zipped: $zipped;
echo;


# TODO: Implement a function that allows the following.

# Functions with a return value can be called normally. In that case
# they print their return value to the standard output.
#
# TODO: Are functions with return values really useful? Their only
# benefits are that they can be run in the same (sub)shell and that
# they can at the same time return a value and print to the standard
# output (in which case, they can't (or rather shouldn't) be called
# outside of the “var“ construct).

# echo zip-a: $(zip-a "$(subarray "$array" 0 5)" "$(subarray "$array" 5 10)");
# echo;


# The “abort” function allows to immediately exit the shell, even from
# subshells, with an error message and a stack trace.

fun test-abort :{
    fun nested1 :{
        fun nested2 :{
            fun nested3 :{
                abort "Fatal failure";
            }
            echo $(nested3);
        }
        nested2 | cat;
    }
    nested1;
}

test-abort;


# Other features:
#
# - zfun sets a number of options to make zsh exit on as many
#   errors/problems as possible or to at least warn about them.
#
# - zfun installs a trap to exit from the shell and print a stack
#   trace when a command returns an unexpected error, even if that was
#   in a subshell. This works in most cases but unfortunately not all.
#
# - zfun changes “IFS" to only contain NUL (i.e., \0). This is what
#   makes it possible to pass arrays and associations as arguments. It
#   assumes however that their values (and keys) never contain the NUL
#   character. This implies that “"$array"” is rendered with NUL as
#   separator instead of the usual space. This only matters when
#   variables have to be rendered for output on the terminal or in a
#   file. One may have to use “${(j: :array)}”. Or simply “echo
#   $array” instead of “echo "$array"”. Echo still renders its
#   arguments separated with spaces.
