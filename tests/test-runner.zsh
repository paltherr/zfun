#!/bin/zsh

set -eu

file=${0:h}/test-command.zsh;
{ cat ${0:h}/test-header.zsh; echo; echo -E - "$@"; } > $file;
chmod 755 $file;
exec $file;
