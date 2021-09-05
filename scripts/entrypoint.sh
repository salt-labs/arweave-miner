#!/usr/bin/env bash

##################################################
# Name: entrypoint.sh
# Description: Wrapper for running Arweave Miner
##################################################

# Get a script name for the logs
export SCRIPT=${0##*/}

# Common
export LOGLEVEL="${INPUT_LOGLEVEL:=INFO}"

# Arweave
export ARWEAVE_HOME="${ARWEAVE_HOME:=/arweave}"
export ARWEAVE_REWARDS_ADDRESS="${ARWEAVE_REWARDS_ADDRESS}"
export ARWEAVE_PEERS="peer 188.166.200.45 peer 188.166.192.169 peer 163.47.11.64 peer 139.59.51.59 peer 138.197.232.192"
export ARWEAVE_CONFIG_DIR="${ARWEAVE_CONFIG_DIR:=$ARWEAVE_HOME/config}"
export ARWEAVE_DATA_DIR="${ARWEAVE_DATA_DIR:=/data}"

#########################
# Pre-reqs
#########################

# Import the required functions
# shellcheck source=functions.sh
source "/scripts/functions.sh" || { echo "Failed to source dependant functions!" ; exit 1 ; }

checkLogLevel "${LOGLEVEL}" || { writeLog "ERROR" "Failed to check the log level" ; exit 1 ; }

checkReqs || { writeLog "ERROR" "Failed to check all requirements" ; exit 1 ; }

# Used if the CI is running a simple test
case "${1,,}" in

	version )
		${ARWEAVE_HOME}/bin/arweave --"${1}" || { writeLog "ERROR" "Failed to show Arweave version!" ; exit 1 ; }
		exit 0
	;;

	*help | *usage )
		usage
		exit 0
	;;

esac

#########################
# Main
#########################

# Check the minimum required variables are populated
checkVarEmpty "ARWEAVE_REWARDS_ADDRESS" "Arweave Rewards Address" && exit 1

echo -e "##### SYNCING WEAVE #####"

${ARWEAVE_HOME}/bin/start \
	data_dir "${ARWEAVE_DATA_DIR}" \
	sync_jobs 100 \
	${ARWEAVE_PEERS} 

echo -e "##### MINING START #####"

${ARWEAVE_HOME}/bin/start \
	data_dir "${ARWEAVE_DATA_DIR}" \
	mine \
	mining_addr ${ARWEAVE_REWARDS_ADDRESS} \
	${ARWEAVE_PEERS} \
	&

echo -e "##### TAILING LOGS #####"

${ARWEAVE_HOME}/bin/logs -f
