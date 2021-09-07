#!/usr/bin/env bash

##################################################
# Name: functions.sh
# Description: useful shell functions
##################################################

#########################
# Common
#########################

checkBin() {

	# Checks the binary name is available in the path

	local COMMAND="$1"

	#if ( command -v "${COMMAND}" 1> /dev/null ) ; # command breaks with aliases
	if ( type -P "${COMMAND}" &> /dev/null ) ;
	then
		writeLog "DEBUG" "The command $COMMAND is available in the Path"
		return 0
	else
		writeLog "DEBUG" "The command $COMMAND is not available in the Path"
		return 1
	fi

}

checkReqs() {

	# Make sure all the required binaries are available within the path
	for BIN in "${REQ_BINS[@]}" ;
	do
		writeLog "DEBUG" "Checking for dependant binary ${BIN}"
		checkBin "${BIN}" || { writeLog "ERROR" "Please install the ${BIN} binary on this system in order to run ${SCRIPT}" ; return 1 ; }
	done

	return 0

}

checkPermissions () {

	# Checks if the user is running as root

	if [ "${EUID}" -ne 0 ] ;
	then
		return 1
	else
		return 0
	fi

}

checkLogLevel() {

	# Only the following log levels are supported.
	#   DEBUG
	#   INFO or INFORMATION
	#   WARN or WARNING
	#   ERR or ERROR

	local LEVEL="${1}"
	export LOGLEVEL

	# POSIX be gone!
	# LOGLEVEL="$( echo "${1}" | tr '[:lower:]' '[:upper:]' )"
	case "${LEVEL^^}" in

		"DEBUG" | "TRACE" )

			export LOGLEVEL="DEBUG"

		;;

		"INFO" | "INFORMATION" )

			export LOGLEVEL="INFO"

		;;

		"WARN" | "WARNING" )

			export LOGLEVEL="WARN"

		;;

		"ERR" | "ERROR" )

			export LOGLEVEL="ERR"

		;;

		* )

			writeLog "INFO" "An unknown log level of ${LEVEL^^} was provided, defaulting to INFO"
			export LOGLEVEL="INFO"

		;;

	esac

	return 0

}

writeLog() {


	local LEVEL="${1}"
	local MESSAGE="${2}"

	case "${LEVEL^^}" in

		"DEBUG" | "TRACE" )

			LEVEL="DEBUG"

			# Do not show debug messages if the level is > debug
			if [ ! "${LEVEL^^}" = "${LOGLEVEL^^}" ] ;
			then
				return 0
			fi

		;;

		"INFO" | "INFORMATION" )

			LEVEL="INFO"

			# Do not show info messages if the level is > info
			if [ "${LOGLEVEL^^}" = "WARN" ] || [ "${LOGLEVEL^^}" = "ERR" ] ;
			then
				return 0
			fi

		;;

		"WARN" | "WARNING" )

			LEVEL="WARN"

			# Do not show warn messages if the level is > warn
			if [ "${LOGLEVEL^^}" = "ERR" ] ;
			then
				return 0
			fi

		;;

		"ERR" | "ERROR" )

			LEVEL="ERR"

			# Errors are always shown

		;;

		* )

			MESSAGE="Unknown log level ${LEVEL^^} provided to log function. Valid options are DEBUG, INFO, WARN, ERR"
			LEVEL="ERR"

		;;

	esac

	echo "$( date +"%Y/%m/%d %H:%M:%S" ) [${LEVEL^^}] ${MESSAGE}"

	return 0

}

function checkVarEmpty() {

	# Returns true if the variable is empty

	# NOTE:
	#	Pass this function the string NAME of the variable
	#	Not the expanded contents of the variable itself.

	local VAR_NAME="${1}"
	local VAR_DESC="${2}"

	if [[ "${!VAR_NAME:-EMPTY}" == "EMPTY" ]];
	then
		writeLog "ERROR" "The variable ${VAR_DESC} is empty."
		return 0
	else
		writeLog "DEBUG" "The variable ${VAR_DESC} is not empty, it is set to ${!VAR_NAME}"
		return 1
	fi

}

checkResult () {

	local RESULT="${1}"

	if [ "${RESULT}" -ne 0 ];
	then
		return 1
	else
		return 0
	fi

}

#########################
# Specific
#########################

usage() {

	cat <<- EOF

	Options:

		config_file (path)                      Load configuration from specified file.
        peer (ip:port)                          Join a network on a peer (or set of peers).
        start_from_block_index                  Start the node from the latest stored block index.
        mine                                    Automatically start mining once the netwok has been joined.
        port                                    The local port to use for mining. This port must be accessible by remote peers.
        data_dir                                The directory for storing the weave and the wallets (when generated).
        metrics_dir                             The directory for persisted metrics.
        polling (num)                           Poll peers for new blocks every N seconds. Default is 60. Useful in environments where port forwarding is not possible.
        no_auto_join                            Do not automatically join the network of your peers.
        mining_addr (addr)                      The address that mining rewards should be credited to. Set 'unclaimed' to send all the rewards to the endowment pool.
        stage_one_hashing_threads (num)         The number of mining processes searching for the SPoRA chunks to read.Default: 4. If the total number of stage one and stage two processes exceeds the number of available CPU cores, the excess processes will be hashing chunks when anything gets queued, and search for chunks otherwise.
        io_threads (num)                        The number of processes reading SPoRA chunks during mining. Default: 10.
        stage_two_hashing_threads (num)         The number of mining processes hashing SPoRA chunks.Default: 6. If the total number of stage one and stage two processes exceeds the number of available CPU cores, the excess processes will be hashing chunks when anything gets queued, and search for chunks otherwise.
        max_emitters (num)                      The maximum number of transaction propagation processes (default 2).
        tx_propagation_parallelization (num)    The maximum number of best peers to propagate transactions to at a time (default 4).
        max_propagation_peers (num)             The maximum number of best peers to propagate blocks and transactions to. Default is 50.
        sync_jobs (num)                         The number of data syncing jobs to run. Default: 20. Each job periodically picks a range and downloads it from peers.
        header_sync_jobs (num)                  The number of header syncing jobs to run. Default: 1. Each job periodically picks the latest not synced block header and downloads it from peers.
        load_mining_key (file)                  Load the address that mining rewards should be credited to from file.
        ipfs_pin                                Pin incoming IPFS tagged transactions on your local IPFS node.
        transaction_blacklist (file)            A file containing blacklisted transactions. One Base64 encoded transaction ID per line.
        transaction_blacklist_url               An HTTP endpoint serving a transaction blacklist.
        transaction_whitelist (file)            A file containing whitelisted transactions. One Base64 encoded transaction ID per line. If a transaction is in both lists, it is considered whitelisted.
        transaction_whitelist_url               An HTTP endpoint serving a transaction whitelist.
        disk_space (num)                        Max size (in GB) for the disk partition containing the Arweave data directory (blocks, txs, etc) when the miner stops writing files to disk.
        disk_space_check_frequency (num)        The frequency in seconds of requesting the information about the available disk space from the operating system, used to decide on whether to continue syncing the historical data or clean up some space. Default is 30.
        init                                    Start a new weave.
        internal_api_secret (secret)            Enables the internal API endpoints, only accessible with this secret. Min. 16 chars.
        enable (feature)                        Enable a specific (normally disabled) feature. For example, subfield_queries.
        disable (feature)                       Disable a specific (normally enabled) feature.
        gateway (domain)                        Run a gateway on the specified domain
        custom_domain (domain)                  Add a domain to the list of supported custom domains.
        requests_per_minute_limit (number)      Limit the maximum allowed number of HTTP requests per IP address per minute. Default is 900.
        max_connections                         The number of connections to be handled concurrently. Its purpose is to prevent your system from being overloaded and ensuring all the connections are handled optimally. Default is 1024.
        max_gateway_connections                 The number of gateway connections to be handled concurrently. Default is 128.
        max_poa_option_depth                    The number of PoA alternatives to try until the recall data is found. Has to be an integer > 1. The mining difficulty grows linearly as a function of the alternative as (0.75 + 0.25 * number) * diff, up to (0.75 + 0.25 * max_poa_option_depth) * diff. Default is 500.
        disk_pool_data_root_expiration_time     The time in seconds of how long a pending or orphaned data root is kept in the disk pool. The default is 2 * 60 * 60 (2 hours).
        max_disk_pool_buffer_mb                 The max total size in mebibytes of the pending chunks in the disk pool.The default is 2000 (2 GiB).
        max_disk_pool_data_root_buffer_mb       The max size in mebibytes per data root of the pending chunks in the disk pool. The default is 50.
        randomx_bulk_hashing_iterations         The number of hashes RandomX generates before reporting the result back to the Arweave miner. The faster CPU hashes, the higher this value should be.
        disk_cache_size_mb                      The maximum size in mebibytes of the disk space allocated for storing recent block and transaction headers. Default is 5120.
        debug                                   Enable extended logging.

	EOF

	return 0

}

#########################
# Export
#########################

# Export common functions
export -f checkBin checkReqs checkPermissions checkLogLevel writeLog checkVarEmpty checkResult

# Export specific functions
export -f usage

#########################
# End
#########################

writeLog "INFO" "Sourced and exported functions.sh"
