#!/bin/bash -u

function decode_line()
{
	local line=${1}
	local tokens

	# shellcheck disable=SC2001
	readarray -t tokens < <(echo "${line}" | sed -e 's,__MARK__,\n,g')
	STATUS=${tokens[1]}
	COUNT=${tokens[2]}
	COMMIT=${tokens[3]}
	PATCH_ID=${tokens[4]}
	SUBJECT=${tokens[5]}
	FUZZY_SUBJECT=${tokens[6]}
}

function get_line_count()
{
	local line=${1}
	local tokens

	readarray -t tokens < <(echo "${line}" | sed -e 's,__MARK__,\n,g')
	echo "${tokens[2]}"
}


function encode_line()
{
	echo "__MARK__${STATUS}__MARK__${COUNT}__MARK__${COMMIT}__MARK__${PATCH_ID}__MARK__${SUBJECT}__MARK__${FUZZY_SUBJECT}__MARK__"
}

list=${1}

reverted=()
while IFS= read -r line ; do
	decode_line "${line}"

	reverted_count=${reverted[${COUNT}]:-0}
	no_revert=${SUBJECT#Revert \"}

	# Check if this is an already reverted commit
	if [ "${reverted_count}" -gt 0 ] ; then
		STATUS="R"
		#echo "${COUNT} is reverted by ${reverted_count}"

	# Check if this is a revert
	elif [ "${no_revert}" != "${SUBJECT}" ] ; then
		no_revert=${no_revert%\"}
		match_line=$(sed "1,${COUNT} d" "$1" | \
						 grep -m1 -F "__MARK__${no_revert}__MARK__")
		if [ -n "${match_line}" ] ; then
			match_count=$(get_line_count "${match_line}")
			reverted[${match_count}]=${COUNT}
			STATUS="R"
			#echo "${COUNT} reverts ${match_count}"
		fi
	fi

	encode_line
done < <(cat "${list}")
