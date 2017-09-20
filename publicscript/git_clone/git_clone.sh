#!/bin/bash

# @sacloud-tag @require-module-ansible
# @sacloud-once
# 
# @sacloud-text required shellarg url "Git URL"
# @sacloud-text required shellarg default="startup.sh" auto_exec_cmd "実行ファイル名"
# @sacloud-text shellarg ex_options "追加オプション"
# 
# @sacloud-desc-begin
#   指定のGitリポジトリをcloneし、指定の実行ファイルを自動的に実行します。
#   拡張子が .yml のものは Ansible Playbook として解釈されます。
#   このスクリプトは、CentOS6.XもしくはScientific Linux6.Xでのみ動作します。
# @sacloud-desc-end
# @sacloud-require-archive distro-centos distro-ver-6.*
# @sacloud-require-archive distro-sl distro-ver-6.*

HOME=/root
SACDIR="$HOME/.sacloud-api"
GITDIR="$SACDIR/git"
NOTE_ID=@@@.ID@@@
URL=@@@url@@@
AUTO_EXEC_CMD=@@@auto_exec_cmd@@@
EX_OPTIONS=@@@ex_options@@@
IS_YML=
if [[ "$AUTO_EXEC_CMD" =~ \.[yY][mM][lL]$ ]]; then
  IS_YML=1
fi
cd "$HOME" || exit 1
if ( which yum >/dev/null 2>&1 ); then
  yum install -y git || exit 1
elif ( which apt-get >/dev/null 2>&1 ); then
  # apt-get update -y || exit 1
  apt-get install -y git || exit 1
else
  exit 1
fi

mkdir -p "$GITDIR"
cd "$GITDIR" || exit $?
rm -Rf "$NOTE_ID"
git clone "$URL" "$NOTE_ID" || exit $?
cd "$NOTE_ID" || exit $?
chmod u+x "$AUTO_EXEC_CMD"
if [ "$IS_YML" ]; then
  "$SACDIR/ansible_installer.sh" -g "$AUTO_EXEC_CMD" -o "$EX_OPTIONS" "$NOTE_ID" || exit $?
else
  "./$AUTO_EXEC_CMD" || exit $?
fi

exit 0