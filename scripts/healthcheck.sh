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

export ARWEAVE_PROCESS_NAMES=(
	"/arweave/bin/arweave"
)

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

# Check running processes
for ARWEAVE_PROCESS in ${ARWEAVE_PROCESS_NAMES[*]};
do

	echo -e "Checking ${ARWEAVE_PROCESS} status..."

	pgrep \
		--list-name \
		--full \
		"${ARWEAVE_PROCESS}"
	
	ARWEAVE_PROCESS_STATUS=$?

	if [[ "${ARWEAVE_PROCESS_STATUS:-1}" -ne 0 ]]; 
	then
		echo "Process ${ARWEAVE_PROCESS} has failed, exiting!"
		exit 1
	fi

done

echo -e "Arweave healthcheck completed successfully"

exit 0
