#!/usr/bin/env bash
# Copyright (c) 2025 pierrecdevs
#
# Licensed under the Creative Commons Attribution 4.0 International License (CC BY 4.0).
# See the LICENSE file for details.

SERVER=irc.libera.chat
PORT=6667
NICK=bashircuser
CHANNEL=\#bash-dev
VERBOSE=TRUE

fatal() {
  echo '[FATAL]' "$@" >&2 
  exit 1
}

graceful-exit() {
  local fd=$1
  echo "EXITING..."
  exec ${fd}>&-
}

join-channel() {
  local fd=$1
  local target=$2

  send-command "${fd}" "JOIN ${target}"
}

part-channel() {
  local fd=$1
  local target=$2

  send-command "${fd}" "PART ${target}"
}

send-message() {
  local fd=$1
  local target=$2
  local message=${@:3}
  message="${message#"${message%%[![:space:]]*}"}"
  message="${message%"${message##*[![:space:]]}"}"

  send-command "${fd}" "PRIVMSG ${target} :${message}"
}

quit() {
  local fd=$1
  local message=${@:2}
  message="${message#"${message%%[![:space:]]*}"}"
  message="${message%"${message##*[![:space:]]}"}"
  message="${message:-Source code available: //github.com/pierrecdevs/purebash-irc}"

  echo "QUITTING"

  send-command "${fd}" "QUIT :${message}"
}

send-command() {
  local fd=$1
  local cmd=${@:2}
  cmd="${cmd#"${cmd%%[![:space:]]*}"}"
  cmd="${cmd%"${cmd##*[![:space:]]}"}"
  
  # TODO: This is for debug purpose will add a debug option soon.
  if [[ $VERBOSE == "TRUE" ]]; then
    printf '\e[42m -%c %s \e[0m\n' ">" "${cmd}"
  fi

  printf "%s\n" "${cmd}" >&${fd};
}

parse-request() {
  local fd=$1
  local line=${@:2}
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  local server_name="${line%% *}"
  local reply_code="${line#* }"
  reply_code="${reply_code%% *}"

  local nick_connected="${line#* $reply_code }"
  nick_connected="${nick_connected%% *}"

  local remainder="${line#* $reply_code $nick_connected}"
  
  echo "($reply_code) $remainder"

  case $reply_code in 
    '376')
      join-channel "${fd}" "${CHANNEL}"
     ;;
   '366')
     echo "JOINED."
     # NOTE: This can obviously be changed to have it's own usecase
     send-message "${fd}" "${CHANNEL}" "Hello from BASH"
     send-message "${fd}" "${CHANNEL}" "Have a great day!"
     ;;
   *)
     if [[ $line =~ ^PING\  ]]; then
       pong "${fd}" "${remainder}"
       quit "${fd}" "Source at //github.com/pierrecdevs/purebash-irc"
      else
        if [[ $VERBOSE == "TRUE" ]]; then
          printf '\e[41m %c- %s \e[0m\n' "<" "${line}"
        fi
     fi
     ;;
  esac
}

pong() {
  local fd=$1
  local resp=$2

  echo "PONG! ${resp}"
  send-command "${fd}" "${resp}"
}

process-data() {
  local fd=$1

  while read -r data <&${fd}; do
    parse-request "${fd}" "${data}"
  done

  exec {fd}>&-
}


main() {
  local OPTARG OPTIND opt
  while getopts 's:p:n:c:v:' opt; do
    case "$opt" in
      s) SERVER=$OPTARG;;
      p) PORT=$OPTARG;;
      n) NICK=$OPTARG;;
      c) CHANNEL=$OPTARG;;
      v) VERBOSE=$OPTARG;;
      *) fatal 'bad option';;
    esac
  done

  VERBOSE="${VERBOSE:-FALSE}"
  printf "Connecting to %s:%d as %s and joining %s\n" $SERVER $PORT $NICK $CHANNEL

  local fd=3
  trap "graceful-exit" "${fd}" exit
  exec {fd}<>/dev/tcp/$SERVER/$PORT
  
  send-command "${fd}" "NICK ${NICK}"
  send-command "${fd}" "USER ${NICK} 0 * :${NICK}"
  process-data "${fd}"
}

main "$@"
