#!/usr/bin/env bats

set -eu

# TODO: Split into multiple files.

################################################################################

function setup_file() {
    bats_require_minimum_version 1.5.0;
    export TEST_FILE=tests/test-runner.zsh;
    export TEST_RUNNER=tests/test-runner.zsh;
    export TEST_COMMAND=tests/test-command.zsh;
    export TRACE_top=$($TEST_RUNNER "eval 'echo \$funcfiletrace[1]'");
    export REPLY_NAME=_zfun_reply_1;
    export NL=$'\n';
}

function teardown_file() {
    rm -f "$TEST_COMMAND";
}

function setup() {
    load '/usr/local/lib/bats-support/load.bash';
    load '/usr/local/lib/bats-assert/load.bash';
}

################################################################################

function quoted() {
    local arg;
    for arg; do
        echo -n " \"$arg\"";
    done;
}

function join() {
    local delimiter=${1:-};
    local first=${2:-};
    if shift 2; then
        printf %s "$first" "${@/#/$delimiter}";
    fi;
}

function expected_stdout() {
    join "$NL" "${expected_output[@]}";
}

function expected_stderr() {
    if [ -v expected_error ]; then
        if [ ! -v expected_trace ]; then
            local expected_trace=("at $TRACE_top($main)");
        fi;
        join "$NL" "${expected_error[@]}" "${expected_usage[@]}" "${expected_trace[@]}";
    fi;
}

# NAME
#
# check – Checks that a command behaves as expected.

# SYNOPSIS
#
# check <test-command>

# INPUT VARIABLES
#
# - prelude - string: An optional prelude to prepend to the test
#     command.
#
# - expected_status - integer: The command's expected exit status. If
#     unspecified and "expected_error" is specified, defaults to 1,
#     otherwise default to 0.
#
# - expected_output - array: The command's expected output lines. If
#     unspecified, defaults to an empty array.
#
# - expected_error - array: The command's expected error lines. If
#     unspecified, defaults to an empty array.
#
# - expected_usage - array: The command's expected usage lines. If
#     unspecified, defaults to an empty array.
#
# - expected_trace - array: The command's expected stack trace
#     elements. If unspecified and "expected_error" is specified,
#     defaults to a trace with a single call to the function specified
#     by "main", otherwise defaults to an empty array. To explicitly
#     specify no trace, set "expected_trace" to an empty string
#     (because, at least with some versions of Bash, setting it to an
#     empty array is the same as no specifying it).
#
# - main - string: The name of the function to use in the default
#     stack trace.
#
# Array input variables whose value are an array containing a single
# string may also be directly initialized with that string.

# DESCRIPTION
#
# Checks whether the test command (with the prelude prepended) returns
# with the expected exit status, the expected stdout output, and the
# expected stderr output. The expected stdout output is the
# concatenation of the expected output lines. The expected stderr
# output is the concatenation of the expected error lines, the
# expected usage lines, and the expected stack trace elements.

# BEWARE: The code here is Bash code while the code in the test
# command is Zsh code.
function check() {
    local command="${prelude:-}$1";
    echo "# Testing: $TEST_RUNNER ${command@Q}";

    run --separate-stderr $TEST_RUNNER "$command";
    if ((${expected_status:-0})); then
        assert_failure ${expected_status};
    elif [ -n "${expected_error[*]}" ]; then
        assert_failure 1;
    else
        assert_success;
    fi;
    assert_equal "$output" "$(expected_stdout)";
    assert_equal "$stderr" "$(expected_stderr)";
}

@test "function names" {
    main=_zfun-parse-fun-name;
    for type in "" ":s" ":xyz" ":x:y:z" ":" ":::"; do
        for name in f F 0 _ - foobar FooBar FOO_BAR -foo-42- _foo_42_; do
            expected_output=$name;
            check "usage=usage; depth=0; $main '$name$type'";
        done;
    done;
}

@test "invalid function names" {
    main=_zfun-parse-fun-name;
    for type in "" ":s" ":xyz" ":x:y:z" ":" ":::"; do
        for name in "" @ @foobar foo@bar foobar@; do
            expected_error="$main: Illegal function name: \"$name\".";
            check "usage=usage; depth=0; $main '$name$type'";
        done
    done;
}

@test "argument names" {
    main=_zfun-parse-arg-name;
    for type in "" ":s" ":xyz" ":x:y:z" ":" ":::"; do
        for name in f F _ foobar FooBar FOO_BAR  _foo_42_; do
            expected_output=$name;
            check "usage=usage; depth=0; $main '$name$type'";
        done;
    done;
}

@test "invalid argument names" {
    main=_zfun-parse-arg-name;
    for type in "" ":s" ":xyz" ":x:y:z" ":" ":::"; do
        for name in "" - -foobar foo-bar foobar- foo@bar; do
            expected_error="$main: Illegal argument name: \"$name\".";
            check "usage=usage; depth=0; $main '$name$type'";
        done
    done;
}

@test "types" {
    main=_zfun-parse-type;
    for entry in :s/scalar :a/array :A/association /default-result; do
        type=${entry%/*};
        expected_output=${entry#*/};
        check "usage=usage; depth=0; $main default-result 'name$type'";
    done;
}

@test "invalid types" {
    main=_zfun-parse-type;
    for type in "x" "array" "s:a:A" "" "::"; do
        expected_error="$main: Invalid type: \"$type\".";
        check "usage=usage; depth=0; $main default-result 'name:$type'";
    done;
}

@test "function declarations" {
    check 'fun f       :{ echo foo }';
    check 'fun f ""    :{ echo foo }';
    check 'fun f  a    :{ echo foo }';
    check 'fun f "a"   :{ echo foo }';
    check 'fun f  a b  :{ echo foo }';
    check 'fun f "a b" :{ echo foo }';

    check 'fun f       :{}';
    check 'fun f ""    :{}';
    check 'fun f  a b  :{}';
    check 'fun f "a b" :{}';

    check 'fun f:s     :{ echo foo }';
    check 'fun f:a     :{ echo foo }';
    check 'fun f:A     :{ echo foo }';
    check 'fun f:s a b :{ echo foo }';
    check 'fun f:a a b :{ echo foo }';
    check 'fun f:A a b :{ echo foo }';

    check 'fun foo  a b  :{ echo foo }';
    check 'fun f-o  a b  :{ echo foo }';
    check 'fun f_o  a b  :{ echo foo }';
    check 'fun -fo  a b  :{ echo foo }';
    check 'fun _fo  a b  :{ echo foo }';
    check 'fun fo-  a b  :{ echo foo }';
    check 'fun fo_  a b  :{ echo foo }';
    check 'fun ---  a b  :{ echo foo }';
    check 'fun ___  a b  :{ echo foo }';
}

@test "function calls" {
    expected_output=$'foo';
    check 'fun f       :{ echo foo }; f';
    check 'fun f ""    :{ echo foo }; f';
    check 'fun f  a    :{ echo foo }; f x';
    check 'fun f "a"   :{ echo foo }; f x';
    check 'fun f  a b  :{ echo foo }; f x y';
    check 'fun f "a b" :{ echo foo }; f x y';

    expected_output=$'foo\nv=bar';
    check 'fun f:s     :{ echo foo; r:set bar }; var v := f    ; echo v=$v';
    check 'fun f:s a   :{ echo foo; r:set bar }; var v := f x  ; echo v=$v';
    check 'fun f:s a b :{ echo foo; r:set bar }; var v := f x y; echo v=$v';

    expected_output=$'foo\nv=1 2 3';
    check 'fun f:a     :{ echo foo; r:set 1 2 3 }; var v := f    ; echo v=$v';
    check 'fun f:a a   :{ echo foo; r:set 1 2 3 }; var v := f x  ; echo v=$v';
    check 'fun f:a a b :{ echo foo; r:set 1 2 3 }; var v := f x y; echo v=$v';

    expected_output=$'foo\nv=k v';
    check 'fun f:A     :{ echo foo; r:set k v }; var v := f    ; echo v=${(kv)v}';
    check 'fun f:A a   :{ echo foo; r:set k v }; var v := f x  ; echo v=${(kv)v}';
    check 'fun f:A a b :{ echo foo; r:set k v }; var v := f x y; echo v=${(kv)v}';

    expected_output=$'';
    check 'fun f       :{}; f';
    check 'fun f ""    :{}; f';
    check 'fun f  a    :{}; f x';
    check 'fun f "a"   :{}; f x';
    check 'fun f  a b  :{}; f x y';
    check 'fun f "a b" :{}; f x y';
}

@test "scalar replies" {
    expected_output="$REPLY_NAME=foobar";
    check 'fun f:s :{ r:set foobar; }; f; show-reply';
    check 'fun f:s :{ r:set barfoo; r:set foobar; }; f; show-reply';
    check 'fun f:s :{ r:set foo; r:add bar; }; f; show-reply';
    check 'fun f:s :{ r:set fo; r:add ob; r:add ar; }; f; show-reply';
    check 'fun f:s :{ r:set foobar; r:add ""; }; f; show-reply';
    check 'fun f:s :{ r:set ""; r:add foobar; }; f; show-reply';
    check 'fun f:s :{ r:add foobar; }; f; show-reply';
    check 'fun f:s :{ r:add foo; r:add bar; }; f; show-reply';
    check 'fun f:s :{ r:set xyz; }; fun g:s :{ r:set foobar; }; f; g; show-reply';
    check 'fun f:s :{ r:set xyz; }; fun g:s :{ r:add foobar; }; f; g; show-reply';
    check 'fun f:s :{ r:set xyz; }; fun g:s :{ f; r:set foobar; }; g; show-reply';
    check 'fun f:s :{ r:set xyz; }; fun g:s :{ f; r:add foobar; }; g; show-reply';
    check 'fun f:s :{ r:set xyz; }; fun g:s :{ r:set foobar; f; }; g; show-reply';
    check 'fun f:s :{ r:set xyz; }; fun g:s :{ r:add foobar; f; }; g; show-reply';
    check 'fun f:s :{ r:set xyz; }; fun g:s :{ f; r:set foo; f; r:add bar; f; }; g; show-reply';
    check 'fun f:s :{ r:add xyz; }; fun g:s :{ f; r:set foobar; }; g; show-reply';
    check 'fun f:s :{ r:add xyz; }; fun g:s :{ f; r:add foobar; }; g; show-reply';
    check 'fun f:s :{ r:add xyz; }; fun g:s :{ r:set foobar; f; }; g; show-reply';
    check 'fun f:s :{ r:add xyz; }; fun g:s :{ r:add foobar; f; }; g; show-reply';
    check 'fun f:s :{ r:add xyz; }; fun g:s :{ f; r:set foo; f; r:add bar; f; }; g; show-reply';
    check 'fun f:s :{ { r:set foobar; }; }; f; show-reply';
    check 'fun f:s :{ eval r:set foobar; }; f; show-reply';
    check 'fun f:s :{ eval eval r:set foobar; }; f; show-reply';
    check 'fun f:s :{ eval eval eval r:set foobar; }; f; show-reply';

    expected_output="$REPLY_NAME='  foo    bar  '";
    check 'fun f:s :{ r:set "  foo    bar  "; }; f; show-reply';
    check 'fun f:s :{ r:set "  foo  "; r:add "  bar  "; }; f; show-reply';
    check 'fun f:s :{ r:add "  foo    bar  "; }; f; show-reply';

    expected_output="$REPLY_NAME=''";
    check 'fun f:s :{ r:set ""; }; f; show-reply';
    check 'fun f:s :{ r:set ""; r:add ""; }; f; show-reply';
    check 'fun f:s :{ r:set ""; r:add ""; r:add ""; }; f; show-reply';
    check 'fun f:s :{ r:add ""; r:add ""; }; f; show-reply';
    check 'fun f:s :{ r:add ""; }; f; show-reply';
    check 'fun f:s :{ r:set "foobar"; r:set ""; }; f; show-reply';

    expected_output="$REPLY_NAME is undefined";
    check 'fun f:s :{}; f; show-reply';
    check 'fun f:s :{ r:set xyz; }; fun g:s :{}; f; g; show-reply';
    check 'fun f:s :{ r:set xyz; }; fun g:s :{ f; }; g; show-reply';
}

@test "array replies" {
    expected_output="$REPLY_NAME=(a b c d)";
    check 'fun f:a :{ r:set a b c d; }; f; show-reply';
    check 'fun f:a :{ r:set x y z; r:set a b c d; }; f; show-reply';
    check 'fun f:a :{ r:set a b c d; r:add; }; f; show-reply';
    check 'fun f:a :{ r:set a b c; r:add d; }; f; show-reply';
    check 'fun f:a :{ r:set a b; r:add c d; }; f; show-reply';
    check 'fun f:a :{ r:set a; r:add b c d; }; f; show-reply';
    check 'fun f:a :{ r:set; r:add a b c d; }; f; show-reply';
    check 'fun f:a :{ r:set a; r:add b c; r:add d; }; f; show-reply';
    check 'fun f:a :{ r:add a b c d; }; f; show-reply';
    check 'fun f:a :{ r:add a b c d; r:add; }; f; show-reply';
    check 'fun f:a :{ r:add a b c; r:add d; }; f; show-reply';
    check 'fun f:a :{ r:add a b; r:add c d; }; f; show-reply';
    check 'fun f:a :{ r:add a; r:add b c d; }; f; show-reply';
    check 'fun f:a :{ r:add; r:add a b c d; }; f; show-reply';
    check 'fun f:a :{ r:set x y z; }; fun g:a :{ r:set a b c d; }; f; g; show-reply';
    check 'fun f:a :{ r:set x y z; }; fun g:a :{ r:add a b c d; }; f; g; show-reply';
    check 'fun f:a :{ r:set x y z; }; fun g:a :{ f; r:set a b c d; }; g; show-reply';
    check 'fun f:a :{ r:set x y z; }; fun g:a :{ f; r:add a b c d; }; g; show-reply';
    check 'fun f:a :{ r:set x y z; }; fun g:a :{ r:set a b c d; f; }; g; show-reply';
    check 'fun f:a :{ r:set x y z; }; fun g:a :{ r:add a b c d; f; }; g; show-reply';
    check 'fun f:a :{ r:set x y z; }; fun g:a :{ f; r:set a b; f; r:add c d; f; }; g; show-reply';
    check 'fun f:a :{ r:add x y z; }; fun g:a :{ f; r:set a b c d; }; g; show-reply';
    check 'fun f:a :{ r:add x y z; }; fun g:a :{ f; r:add a b c d; }; g; show-reply';
    check 'fun f:a :{ r:add x y z; }; fun g:a :{ r:set a b c d; f; }; g; show-reply';
    check 'fun f:a :{ r:add x y z; }; fun g:a :{ r:add a b c d; f; }; g; show-reply';
    check 'fun f:a :{ r:add x y z; }; fun g:a :{ f; r:set a b; f; r:add c d; f; }; g; show-reply';
    check 'fun f:a :{ { r:set a b c d; }; }; f; show-reply';
    check 'fun f:a :{ eval r:set a b c d; }; f; show-reply';
    check 'fun f:a :{ eval eval r:set a b c d; }; f; show-reply';
    check 'fun f:a :{ eval eval eval r:set a b c d; }; f; show-reply';

    expected_output="$REPLY_NAME=('  foo  ' '  bar  ')";
    check 'fun f:a :{ r:set "  foo  " "  bar  "; }; f; show-reply';
    check 'fun f:a :{ r:set "  foo  "; r:add "  bar  "; }; f; show-reply';
    check 'fun f:a :{ r:add "  foo  " "  bar  "; }; f; show-reply';

    expected_output="$REPLY_NAME=('' ' ' ' ' '')";
    check 'fun f:a :{ r:set "" " " " " ""; }; f; show-reply';
    check 'fun f:a :{ r:set "" " "; r:add " " ""; }; f; show-reply';
    check 'fun f:a :{ r:set ""; r:add " " " "; r:add ""; }; f; show-reply';
    check 'fun f:a :{ r:add "" " "; r:add " " ""; }; f; show-reply';
    check 'fun f:a :{ r:add "" " " " " ""; }; f; show-reply';
    check 'fun f:a :{ r:set "foo" "bar"; r:set "" " " " " ""; }; f; show-reply';

    expected_output="$REPLY_NAME is undefined";
    check 'fun f:a :{}; f; show-reply';
    check 'fun f:a :{ r:set x y z; }; fun g:a :{}; f; g; show-reply';
    check 'fun f:a :{ r:set x y z; }; fun g:a :{ f; }; g; show-reply';
}

@test "association replies" {
    expected_output="$REPLY_NAME=([a]=x [b]=y)";
    check 'fun f:A :{ r:set a x b y; }; f; show-reply';
    check 'fun f:A :{ r:set k v; r:set a x b y; }; f; show-reply';
    check 'fun f:A :{ r:set a x b y; r:add; }; f; show-reply';
    check 'fun f:A :{ r:set a x; r:add b y; }; f; show-reply';
    check 'fun f:A :{ r:set; r:add a x b y; }; f; show-reply';
    check 'fun f:A :{ r:set a v b w; r:add a x b y; }; f; show-reply';
    check 'fun f:A :{ r:set a v b w; r:add a x; r:add b y; }; f; show-reply';
    check 'fun f:A :{ r:add a x b y; }; f; show-reply';
    check 'fun f:A :{ r:add a x b y; r:add; }; f; show-reply';
    check 'fun f:A :{ r:add a x; r:add b y; }; f; show-reply';
    check 'fun f:A :{ r:add; r:add a x b y; }; f; show-reply';
    check 'fun f:A :{ r:add a v b w; r:add a x b y; }; f; show-reply';
    check 'fun f:A :{ r:add a v b w; r:add a x; r:add b y; }; f; show-reply';
    check 'fun f:A :{ r:set k v; }; fun g:A :{ r:set a x b y; }; f; g; show-reply';
    check 'fun f:A :{ r:set k v; }; fun g:A :{ r:add a x b y; }; f; g; show-reply';
    check 'fun f:A :{ r:set k v; }; fun g:A :{ f; r:set a x b y; }; g; show-reply';
    check 'fun f:A :{ r:set k v; }; fun g:A :{ f; r:add a x b y; }; g; show-reply';
    check 'fun f:A :{ r:set k v; }; fun g:A :{ r:set a x b y; f; }; g; show-reply';
    check 'fun f:A :{ r:set k v; }; fun g:A :{ r:add a x b y; f; }; g; show-reply';
    check 'fun f:A :{ r:set k v; }; fun g:A :{ f; r:set a x; f; r:add b y; f; }; g; show-reply';
    check 'fun f:A :{ r:add k v; }; fun g:A :{ f; r:set a x b y; }; g; show-reply';
    check 'fun f:A :{ r:add k v; }; fun g:A :{ f; r:add a x b y; }; g; show-reply';
    check 'fun f:A :{ r:add k v; }; fun g:A :{ r:set a x b y; f; }; g; show-reply';
    check 'fun f:A :{ r:add k v; }; fun g:A :{ r:add a x b y; f; }; g; show-reply';
    check 'fun f:A :{ r:add k v; }; fun g:A :{ f; r:set a x; f; r:add b y; f; }; g; show-reply';
    check 'fun f:A :{ { r:set a x b y; }; }; f; show-reply';
    check 'fun f:A :{ eval r:set a x b y; }; f; show-reply';
    check 'fun f:A :{ eval eval r:set a x b y; }; f; show-reply';
    check 'fun f:A :{ eval eval eval r:set a x b y; }; f; show-reply';

    expected_output="$REPLY_NAME=(['  foo  ']='  bar  ')";
    check 'fun f:A :{ r:set "  foo  " "  bar  "; }; f; show-reply';
    check 'fun f:A :{ r:add "  foo  " "  bar  "; }; f; show-reply';

    expected_output="$REPLY_NAME=(['']=' ' [' ']='')";
    check 'fun f:A :{ r:set "" " " " " ""; }; f; show-reply';
    check 'fun f:A :{ r:set "" " "; r:add " " ""; }; f; show-reply';
    check 'fun f:A :{ r:add "" " "; r:add " " ""; }; f; show-reply';
    check 'fun f:A :{ r:add "" " " " " ""; }; f; show-reply';
    check 'fun f:A :{ r:set "foo" "bar"; r:set "" " " " " ""; }; f; show-reply';

    expected_output="$REPLY_NAME is undefined";
    check 'fun f:A :{}; f; show-reply';
    check 'fun f:A :{ r:set k v; }; fun g:A :{}; f; g; show-reply';
    check 'fun f:A :{ r:set k v; }; fun g:A :{ f; }; g; show-reply';
}

@test "nested replies" {
    expected_output="v=foo, w=bar";
    check 'fun f:s :{ r:set foo; }; fun g:s :{ r:set bar; }; var v := f; var w := g; show v w';
    check 'fun f:s :{ r:set foo; }; fun g:s :{ r:set bar; }; var w := g; var v := f; show v w';

    expected_output="v=bar";
    check 'fun f:s :{ r:set foo; }; fun g:s :{ r:set bar; }; var v := f; var v := g; show v';

    expected_output="v=foobar";
    check 'fun f:s :{ r:set foo; }; fun g:s :{ var w := f; r:set ${w}bar; }; var v := g; show v';
    check 'fun f:s :{ r:set foo; }; fun g:s :{ var v := f; r:set ${v}bar; }; var v := g; show v';
    check 'fun f:s :{ r:set bar; }; fun g:s :{ r:set foo; var v := f; r:add $v; }; var v := g; show v';

    expected_output="v=12345";
    check 'fun f:s a:a :{ [[ $#a -gt 0 ]] || { r:set ""; return }; var v := f "$a[2,-1]"; r:set $a[1]$v; }; args=(1 2 3 4 5); var v := f "$args"; show v';

    expected_output="v=foobar";
    check 'fun f:s :{ eval "r:set foobar"; }; var v := f; show v';
}


@test "invalid replies" {
    for main in r:set r:add; do
        echo "";
        echo "# Testing with ( main='$main' ):";

        local expected_trace=("at $TRACE_top($main)");

        expected_error="$main: Replies can only be set from within functions that have a reply value.";
        check "$main;";
        check "$main foo;";
        check "$main foo bar;";
        expected_trace[1]="at $TRACE_top(f)";
        check "f() { $main; }; f";
        check "f() { $main foo; }; f";
        check "f() { $main foo bar; }; f";
        check "fun f :{ $main; }; f";
        check "fun f :{ $main foo; }; f";
        check "fun f :{ $main foo bar; }; f";
        expected_trace[2]="at $TRACE_top(g)";
        check "fun g:s :{ f() { $main; }; f; }; g";
        check "fun g:s :{ f() { $main foo; }; f; }; g";
        check "fun g:s :{ f() { $main foo bar; }; f; }; g";
        unset expected_trace[2];

        # TODO: Test calling $main from a sourced file.

        expected_error="$main: Replies can not be set from within subshells.";
        check "fun f:s :{ ($main foobar); }; f";
        check "fun f:s :{ : \$($main foobar); }; f";

        expected_error="$main: Scalar replies require exactly one value, got 0.";
        check "fun f:s :{ $main; }; f";
        expected_error="$main: Scalar replies require exactly one value, got 2: \"foo\" \"bar\".";
        check "fun f:s :{ $main foo bar; }; f";

        expected_error="$main: Association replies require key/value pairs, got dangling key: \"k\".";
        check "fun f:A :{ $main k; }; f";
        check "fun f:A :{ $main a x k; }; f";
        check "fun f:A :{ $main a x b y k; }; f";
    done;
}

@test "scalar parameters" {
    expected_output="a=x";
    check 'fun f a :{ show a }; f x;';
    check 'fun f a:s :{ show a }; f x;';

    expected_output="a=x, b=y";
    check 'fun f a b :{ show a b }; f x y';
    check 'fun f a:s b :{ show a b }; f x y';
    check 'fun f a b:s :{ show a b }; f x y';
    check 'fun f a:s b:s :{ show a b }; f x y';

    expected_output="a=x, b=y, c=z";
    check 'fun f a b c :{ show a b c }; f x y z';
    check 'fun f a:s b:s c:s :{ show a b c }; f x y z';

    expected_output="a=''${NL}a='  x  x  '${NL}a='x\$y\"z'${NL}a=\$' a\\nb '";
    check 'fun f a :{ show a }; f ""; f "  x  x  "; f "x\$y\"z"; f $(echo " a"; echo "b ")';

    expected_output="a=x, b='', c=z${NL}a='', b='  ', c=''${NL}a='', b='', c=''";
    check 'fun f a b c :{ show a b c }; f x "" z; f "" "  " ""; f "" "" ""';

    expected_output="a=\$'x\\C-@y\\C-@z'";
    check 'fun f a :{ show a }; v=(x y z); f "$v"';
}

@test "array parameters" {
    expected_output="a=(x)";
    check 'fun f a:a :{ show a }; f x';
    check 'fun f a:a :{ show a }; v=(x); f "$v"';

    expected_output="a=(x y z)";
    check 'fun f a:a :{ show a }; v=(x y z); f "$v"';
    check 'fun f a:a :{ show a }; f "$(printf "x\0y\0z")"';
    check "fun f a:a :{ show a }; f \$'x\0y\0z'";

    expected_output="a=('' '' '')";
    check 'fun f a:a :{ show a }; v=("" "" ""); f "$v"';
    check "fun f a:a :{ show a }; f \$'\0\0'";

    expected_output="a=()";
    check 'fun f a:a :{ show a }; v=(); f "$v"';
    check 'fun f a:a :{ show a }; f ""';
    # Because zsh uses value separators rather than value terminators,
    # empty arrays are indistinguishable from arrays containing a
    # single empty string in their stringified form.
    check 'fun f a:a :{ show a }; v=(""); f "$v"';

    expected_output="a=('  ' \$' a\\nb ' '  ')";
    check 'fun f a:a :{ show a }; v=("  " $(echo " a"; echo "b ") "  "); f "$v"';

    expected_output="a=(x1 x2), b=(y), c=(z1 z2)";
    check 'fun f a:a b:a c:a :{ show a b c }; v=(x1 x2); w=(z1 z2); f "$v" "y" "$w"';

    expected_output="a=('' ''), b=(), c=('' '')";
    check 'fun f a:a b:a c:a :{ show a b c }; v=("" ""); f "$v" "" "$v"';
}

@test "association parameters" {
    expected_output="a=()";
    check 'fun f a:A :{ show a }; f ""';
    check 'fun f a:A :{ show a }; v=(); f "$v"';
    check 'fun f a:A :{ show a }; local -A v=(); f "${(kv)v}"';

    expected_output="a=([k1]=v1 [k2]=v2)";
    check 'fun f a:A :{ show a }; local -A v=(); v[k1]=v1; v[k2]=v2; f "${(kv)v}"';
    check 'fun f a:A :{ show a }; local -A v=([k1]=v1 [k2]=v2); f "${(kv)v}"';
    check 'fun f a:A :{ show a }; local -A v=(k1 v1 k2 v2); f "${(kv)v}"';
    check 'fun f a:A :{ show a }; v=(k1 v1 k2 v2); f "$v"';
    check "fun f a:A :{ show a }; f \$'k1\0v1\0k2\0v2'";

    expected_output="a=(['']='')";
    check 'fun f a:A :{ show a }; local -A v=([""]=""); f "${(kv)v}"';

    expected_output="a=(['  k  ']='  v  ')";
    check 'fun f a:A :{ show a }; local -A v=(["  k  "]="  v  "); f "${(kv)v}"';

    expected_output="a=([\$'k\nk']=\$'v\nv')";
    check "fun f a:A :{ show a }; local -A v=([\$'k\nk']=\$'v\nv'); f \"\${(kv)v}\"";
}

@test "invalid function declarations" {
    main=fun;
    expected_usage=(
        "Usage: $main name arg1 ... argN :{ ... }"
        "       $main name \"arg1 ... argN\" :{ ... }"
    );

    expected_error="$main: A function name and the token :{ are required.";
    check "fun";

    expected_error="$main: The token :{ is required.";
    check "fun f";
    check "fun f arg1";
    check "fun f arg1 arg2";

    expected_error="$main: The token :{ must be preceded by a space.";
    check "fun f:{${NL}echo foo${NL}}";
    check "fun f arg1:{${NL}echo foo${NL}}";
    check "fun f arg1 arg2:{${NL}echo foo${NL}}";

    expected_error="$main: A function name is required.";
    check "fun :{${NL}echo foo${NL}}";

    expected_error="$main: Illegal function name: \"\".";
    check "fun '' :{}";
    check "fun ':s' :{}";
    check "fun ':array' :{}";
    check "fun ':s:a:A' :{}";
    expected_error="$main: Illegal function name: \"foo@\".";
    check "fun foo@ :{}";
    expected_error="$main: Illegal function name: \"f@oo\".";
    check "fun f@oo :{}";
    expected_error="$main: Illegal function name: \"@foo\".";
    check "fun @foo :{}";

    expected_error="$main: Illegal argument name: \"\".";
    check "fun foo arg1 '' arg3 :{}";
    check "fun foo arg1 ':s' arg3 :{}";
    check "fun foo arg1 ':array' arg3 :{}";
    check "fun foo arg1 ':s:a:A' arg3 :{}";
    expected_error="$main: Illegal argument name: \"arg@\".";
    check "fun foo arg1 arg@ arg3 :{}";
    expected_error="$main: Illegal argument name: \"a@rg\".";
    check "fun foo arg1 a@rg arg3 :{}";
    expected_error="$main: Illegal argument name: \"@arg\".";
    check "fun foo arg1 @arg arg3 :{}";

    expected_error="$main: Invalid type: \"\".";
    check "fun foo: :{}";
    check "fun foo arg1:s arg2: arg3:a :{}";
    expected_error="$main: Invalid type: \"x\".";
    check "fun foo:x :{}";
    check "fun foo arg1:s arg2:x arg3:a :{}";
    expected_error="$main: Invalid type: \"array\".";
    check "fun foo:array :{}";
    check "fun foo arg1:s arg2:array arg3:a :{}";
    expected_error="$main: Invalid type: \"s:a:A\".";
    check "fun foo:s:a:A :{}";
    check "fun foo arg1:s arg2:s:a:A arg3:a :{}";

    expected_error="$TRACE_top: parse error near \`}'";
    expected_usage=();
    expected_trace="";
    check "fun { echo foo; }";
    check "fun foo { echo foo; }";
    check "fun foo arg1 { echo foo; }";
    check "fun foo arg1 arg2 { echo foo; }";
}

@test "invalid function calls" {
    main=f;

    expected_error='f: Expected 0 argument(s), got 1: "x".';
    check 'fun f :{}; f x';
    expected_error='f: Expected 0 argument(s), got 1: "".';
    check 'fun f :{}; f ""';
    expected_error='f: Expected 0 argument(s), got 2: "x" "y".';
    check 'fun f :{}; f x y';
    expected_error='f: Expected 0 argument(s), got 2: "" "".';
    check 'fun f :{}; f "" ""';

    expected_error='f: Expected 1 argument(s), got 0.';
    check 'fun f a :{}; f';
    expected_error='f: Expected 1 argument(s), got 2: "x" "y".';
    check 'fun f a :{}; f x y';
    expected_error='f: Expected 1 argument(s), got 2: "" "".';
    check 'fun f a :{}; f "" ""';

    expected_error='f: Expected 2 argument(s), got 0.';
    check 'fun f a b :{}; f';
    expected_error='f: Expected 2 argument(s), got 1: "x".';
    check 'fun f a b :{}; f x';
    expected_error='f: Expected 2 argument(s), got 1: "".';
    check 'fun f a b :{}; f ""';
}

@test "scalar assignments" {
    main=var:=;

    expected_output="v=foobar";
    check 'fun f:s :{ r:set foobar; }; var v := f; show v';

    expected_output="v='   foo   bar   '";
    check 'fun f:s :{ r:set "   foo   bar   "; }; var v := f; show v';

    expected_output="v='   '";
    check 'fun f:s :{ r:set "   "; }; var v := f; show v';

    expected_output="v=''";
    check 'fun f:s :{ r:set ""; }; var v := f; show v';
}

@test "array assignments" {
    main=var:=;

    expected_output="v=(a b c d)";
    check 'fun f:a :{ r:set a b c d; }; var v := f; show v';

    expected_output="v=('   foo   bar   ')";
    check 'fun f:a :{ r:set "   foo   bar   "; }; var v := f; show v';

    expected_output="v=('' '   ' '' '' '   ' '')";
    check 'fun f:a :{ r:set "" "   " "" "" "   " ""; }; var v := f; show v';

    expected_output="v=('')";
    check 'fun f:a :{ r:set ""; }; var v := f; show v';

    expected_output="v=()";
    check 'fun f:a :{ r:set; }; var v := f; show v';
}

@test "association assignments" {
    main=var:=;

    expected_output="v=([a]=x [b]=y)";
    check 'fun f:A :{ r:set a x b y; }; var v := f; show v';

    expected_output="v=(['   aaa    aaa   ']='   xxx   yyy   ')";
    check 'fun f:A :{ r:set "   aaa    aaa   " "   xxx   yyy   "; }; var v := f; show v';

    expected_output="v=(['']='   ' ['   ']='')";
    check 'fun f:A :{ r:set "" "   " "   " ""; }; var v := f; show v';

    expected_output="v=(['']='')";
    check 'fun f:A :{ r:set "" ""; }; var v := f; show v';

    expected_output="v=()";
    check 'fun f:A :{ r:set; }; var v := f; show v';
}

@test "scopes and assignments" {
    local type;
    for type in s a A; do
        case $type in
            s ) local init="x" v="x";;
            a ) local init="x" v="(x)";;
            A ) local init="x x" v="([x]=x)";;
        esac;

        echo "";
        echo "# Testing with ( type='$type' init='$init' v='$v' ):";
        prelude="fun f:$type :{ r:set $init; }; ";

        # Assignments overwrite same name variables in the same scope.
        expected_output=("v=$v");
        check 'local v=z; var v := f; show v';
        check 'local -a v=(z); var v := f; show v';
        check 'local -A v; v[z]=z; var v := f; show v';
        check 't() { local v=z; var v := f; show v; }; t';
        check 't() { local v=(z); var v := f; show v; }; t';
        check 't() { local -A v=(z z); var v := f; show v; }; t';
        check 'fun g:s :{ r:set z; }; var v := g; var v := f; show v';
        check 'fun g:a :{ r:set z; }; var v := g; var v := f; show v';
        check 'fun g:A :{ r:set z z; }; var v := g; var v := f; show v';
        check 'fun g:s :{ r:set z; }; t() { var v := g; var v := f; show v; }; t';
        check 'fun g:a :{ r:set z; }; t() { var v := g; var v := f; show v; }; t';
        check 'fun g:A :{ r:set z z; }; t() { var v := g; var v := f; show v; }; t';

        # Assignments hide same name variables from enclosing scopes but don't modify them.
        expected_output=("v=$v" "v=z");
        check 't() { var v := f; show v; }; local v=z; t; show v';
        check 't() { var v := f; show v; }; u() { local v=z; t; show v; }; u';
        expected_output=("v=$v" "v is undefined");
        check 't() { var v := f; show v; }; local v; unset v; t; show v';
        check 't() { var v := f; show v; }; u() { local v; unset v; t; show v; }; u';
        check 't() { var v := f; show v; }; t; show v';
        check 't() { var v := f; show v; }; u() { t; show v; }; u';

        # Assignments hide same name variables in the initializer function.
        expected_output=("v is undefined" "v is undefined" "v=$v" );
        prelude="fun f:$type :{ show v; r:set $init; show v; }; ";
        check 'local v=z; var v := f; show v';
        check 't() { local v=z; var v := f; show v; }; t';
        check 'fun g:s :{ r:set z; }; var v := g; var v := f; show v';
        check 'fun g:s :{ r:set z; }; t() { var v := g; var v := f; show v; }; t';
    done;
}

@test "invalid assignments" {
    main=var;
    expected_usage=( "Usage: $main <variable-name> := <function-name> [<argument>…]" );

    expected_error="$main: A variable name is required.";
    check 'var';
    check 'var :=';
    check 'var := f';
    check 'var := f x';

    expected_error="$main: The token := is required.";
    check 'var v';
    check 'var v w';
    check 'var v w u';

    expected_error="$main: The token := must be preceded by a space.";
    check 'var v:=';
    check 'var v:= f';
    check 'var v:= f x';
    check 'var v w:=';
    check 'var v w:= f';
    check 'var v w:= f x';
    check 'var v w u:=';
    check 'var v w u:= f';
    check 'var v w u:= f x';

    expected_error="$main: The token := must be followed by a space.";
    check 'var :=f';
    check 'var :=f x';
    check 'var v :=f';
    check 'var v :=f x';
    check 'var v w :=f';
    check 'var v w :=f x';
    check 'var v w u :=f';
    check 'var v w u :=f x';

    expected_error="$main: The token := must be preceded and followed by a space.";
    check 'var v:=f';
    check 'var v:=f x';
    check 'var v w:=f';
    check 'var v w:=f x';
    check 'var v w u:=f';
    check 'var v w u:=f x';

    expected_error="$main: A single variable name is allowed, got 2: \"v\" \"w\".";
    check 'var v w :=';
    check 'var v w := f';
    check 'var v w := f x';

    expected_error="$main: A single variable name is allowed, got 3: \"v\" \"w\" \"u\".";
    check 'var v w u :=';
    check 'var v w u := f';
    check 'var v w u := f x';

    expected_error="$main: A function call is required.";
    check 'var v :=';

    expected_error="$main: Function \"f\" has no reply value. It can't be used with \"var\".";
    check 'f() {}; var v := f';
    check 'fun f :{}; var v := f';

    expected_usage=();

    expected_error="Function \"f\" returned without setting a reply.";
    check 'fun f:s :{}; var v := f';
    check 'fun f:a :{}; var v := f';
    check 'fun f:A :{}; var v := f';
}
