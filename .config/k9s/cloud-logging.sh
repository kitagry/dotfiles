#!/usr/bin/env bash
# k9s plugin helper: pretty-print GCP Cloud Logging structured (JSON) logs.
#
# WHY: GKE workloads emit GCP structured-logging JSON to stdout. The raw k9s
# log view shows one giant JSON object per line, which is unreadable. This
# collapses each entry into a single colorized line (time / severity / message
# + remaining fields), while passing non-JSON lines through untouched.
#
# Invoked by ~/.config/k9s/plugins.yaml. WHY positional args (not env vars):
# k9s does NOT export $NAME/$NAMESPACE/etc. to the process environment — it only
# substitutes those tokens textually into the plugin `args`. So plugins.yaml
# passes them as arguments and we read them here as $3.. .
#
# Usage: cloud-logging.sh <mode> <follow> <context> <namespace> <primary> [secondary]
#   mode "pod"       -> primary = pod name; logs all containers
#   mode "container" -> primary = pod name, secondary = container name
#   mode "job"       -> primary = job name; logs via job/<name>
#   follow "follow" streams live (Ctrl-C to quit); otherwise a paged snapshot.
set -euo pipefail

mode="${1:-pod}"
follow="${2:-snapshot}"
context="${3:?context not set}"
namespace="${4:?namespace not set}"

case "$mode" in
  container) target="${5:?pod not set}"; container="${6:?container not set}" ;;
  job)       target="job/${5:?job not set}"; container="" ;;
  *)         target="${5:?pod not set}"; container="" ;;
esac

logs_args=(--context "$context" -n "$namespace" logs "$target")
if [[ -n "$container" ]]; then
  logs_args+=(-c "$container")
else
  # No --prefix: a "[pod/container]" prefix would break per-line JSON parsing.
  logs_args+=(--all-containers)
fi

if [[ "$follow" == "follow" ]]; then
  logs_args+=(--tail="${K9S_LOG_TAIL:-200}" -f)
else
  logs_args+=(--tail="${K9S_LOG_TAIL:-2000}")
fi

fmt='
  def col(s):
    if s=="ERROR" or s=="CRITICAL" or s=="ALERT" or s=="EMERGENCY" then "[1;31m"
    elif s=="WARNING" then "[33m"
    elif s=="INFO" or s=="NOTICE" then "[32m"
    elif s=="DEBUG" then "[90m"
    else "[37m" end;
  def rst: "[0m";
  def dim: "[90m";
  . as $raw
  | (try fromjson catch null) as $j
  | if ($j|type) != "object" then $raw
    else
      ($j.timestamp // $j.time // $j.eventTime // $j.ts // "") as $ts
      | (($j.severity // $j.level // "DEFAULT") | tostring | ascii_upcase
         | if . == "WARN" then "WARNING"
           elif . == "ERR" then "ERROR"
           elif . == "FATAL" or . == "CRIT" then "CRITICAL"
           elif . == "TRACE" then "DEBUG"
           else . end) as $sev
      | (($j.message // $j.msg // "") | tostring) as $msg
      | ($j | del(
          .timestamp, .time, .eventTime, .ts,
          .severity, .level, .message, .msg,
          .["logging.googleapis.com/trace"],
          .["logging.googleapis.com/spanId"],
          .["logging.googleapis.com/trace_sampled"],
          .["logging.googleapis.com/sourceLocation"],
          .["logging.googleapis.com/labels"],
          .["logging.googleapis.com/insertId"]
        )) as $rest
      | ($rest | to_entries
          | map("\(.key)=\(.value|tostring)") | join(" ")) as $extra
      | col($sev) + $ts + " " + $sev + rst + "  " + $msg
        + (if $extra == "" then "" else "  " + dim + $extra + rst end)
    end
'

# 2>&1: surface kubectl errors (e.g. job pods already gone) as plain lines in
# the output instead of a silent failure. pipefail is off so quitting the pager
# early (SIGPIPE to kubectl) does not get reported back to k9s as an error.
set +o pipefail
if [[ "$follow" == "follow" ]]; then
  kubectl "${logs_args[@]}" 2>&1 | jq -R -r --unbuffered "$fmt"
else
  kubectl "${logs_args[@]}" 2>&1 | jq -R -r "$fmt" | less -R +G
fi
