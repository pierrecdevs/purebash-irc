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
  cmd="${cmd//$'\r'/}"
  cmd="${cmd//$'\n'/}"
  cmd="${cmd#"${cmd%%[![:space:]]*}"}"
  cmd="${cmd%"${cmd##*[![:space:]]}"}"
  
  # TODO: This is for debug purpose will add a debug option soon.
  if [[ $VERBOSE == "TRUE" ]]; then
    printf '\e[42m -%c %s\e[0m\n' ">" "${cmd}"
  fi

  printf "%s\r\n" "${cmd}" >&${fd};
}

parse-request() {
  local fd=$1
  local line=${@:2}

  # REF: https://datatracker.ietf.org/doc/html/rfc1459#section-2.3.1
  local prefix=""
  local command=""
  local trailing=""
  local middle=""
  local nick=""
  local user=""
  local host=""
  local remainder=""

  if [[ "$line" == :* ]]; then
    prefix="${line%% *}"
    line="${line#"$prefix"}"
    line="${line# }"
  fi

  command="${line%% *}"
  line="${line#"$command"}"
  line="${line# }"

  if [[ "$line" == *:* ]]; then
    trailing="${line#*:}"
    middle="${line%%:*}"
  else
    middle="$line"
  fi

  IFS=' ' read -r -a middle_params <<< "$middle"
  if [[ "$prefix" =~ ^:([^!]+)!([^@]+)@(.+)$ ]]; then
    nick="${BASH_REMATCH[1]}"
    user="${BASH_REMATCH[2]}"
    host="${BASH_REMATCH[3]}"
  fi

  case "$command" in
    376)
      join-channel "${fd}" "${CHANNEL}"
     ;;
    366)
     echo "JOINED."
     # NOTE: This can obviously be changed to have it's own usecase
     # send-message "${fd}" "${CHANNEL}" "Hello from BASH"
     # send-message "${fd}" "${CHANNEL}" "Have a great day!"
     ;;
   NOTICE)
     printf "[*] NOTICE %s\n%s\n" "${prefix}" "${trailing}"
     ;;
    PRIVMSG)
      if [[ "$trailing" =~ $'\x01'.*$'\x01' ]]; then
        local ctcp_type="${trailing//$'\x01'/}"
        printf "[*] CTCP DETECTED: %s\n" "${ctcp_type}"
      else
        trailing="${trailing#"${trailing%%[![:space:]]*}"}"
        trailing="${trailing%"${trailing##*[![:space:]]}"}"

        if [[ $nick == "n32d" && $trailing == "quit" ]]; then
          send-message "${fd}" "${middle_params[*]}" "Have a great day!"
          sleep 5
          quit "${fd}" "PUREBASH IRC https://github.com/pierrecdevs/purebash-irc"
        else
          printf "[*] Message %s\n[%s]: %s\n" "${middle_params[*]}" "${nick}" "${trailing}"
        fi
      fi
      ;;
    PING)
      pong "${fd}" "${line}"
      ;;
    JOIN)
      printf "[+] %s Joined: %s\n%s\n" "${nick}" "${middle_params[0]}" "${trailing}"
      ;;
    PART)
      printf "[-] %s Left: %s\n%s\n" "${nick}" "${middle_params[0]}" "${trailing}"
      ;;
    *)
      printf "\e[41m%c- (%s) %s\e[0m\n" "<" "${command}" "${line}"
      ;;
  esac
}

pong() {
  local fd=$1
  local resp=$2

  echo "PONG! ${resp}"
  send-command "${fd}" "PONG ${resp}"
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
  printf "Connecting to %s:%d as %s and joining %s\n" \
    "${SERVER}" \
    "${PORT}" \
    "${NICK}" \
    "${CHANNEL}"

  local fd=3
  trap "graceful-exit" "${fd}" exit
  exec {fd}<>/dev/tcp/$SERVER/$PORT
  
  send-command "${fd}" "NICK ${NICK}"
  send-command "${fd}" "USER ${NICK} 0 * :${NICK}"
  process-data "${fd}"
}

main "$@"
