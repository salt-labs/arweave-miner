#!/usr/bin/env bash

##################################################
# Name: healthcheck.sh
# Description: Arweave healthcheck script
##################################################

set -e
set -u
set -o pipefail

export SCRIPT=${0##*/}

export LOGLEVEL="${LOGLEVEL:=INFO}"

export ARWEAVE_PORT="${ARWEAVE_PORT:=1984}"
export HEALTHCHECK_URL="http://localhost:${ARWEAVE_PORT}/info"

#########################
# Pre-reqs
#########################

# Import the required functions
# shellcheck source=functions.sh
source "/scripts/functions.sh" || {
	echo "Failed to source dependant functions!"
	exit 1
}

checkLogLevel "${LOGLEVEL}" || {
	writeLog "ERROR" "Failed to check the log level"
	exit 1
}

checkReqs || {
	writeLog "ERROR" "Failed to check all requirements"
	exit 1
}

#########################
# Main
#########################

# Reference: https://ec.haxx.se/usingcurl/usingcurl-verbose/usingcurl-writeout
CURL_FORMAT='{\n
    "http_code": %{http_code},\n
    "time_redirect": %{time_redirect},\n
    "time_namelookup": %{time_namelookup},\n
    "time_connect": %{time_connect},\n
    "time_appconnect": %{time_appconnect},\n
    "time_pretransfer": %{time_pretransfer},\n
    "time_starttransfer": %{time_starttransfer},\n
    "time_total": %{time_total},\n
    "size_request": %{size_request},\n
    "size_upload": %{size_upload},\n
    "size_download": %{size_download},\n
    "size_header": %{size_header}\n
}\n'

curl \
	--silent \
	--insecure \
	--location \
	--write-out "${CURL_FORMAT}" \
	"${HEALTHCHECK_URL}"

ARWEAVE_HEALTH_STATUS=$?

if [[ "${ARWEAVE_HEALTH_STATUS:-1}" -ne 0 ]]; 
then

	writeLog "ERROR" "Arweave Health check failed!"
	exit 1

else

	writeLog "INFO" "Arweave Health check success!"
	exit 0

fi
