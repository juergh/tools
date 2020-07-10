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

list1=$1

while IFS= read -r line ; do
	decode_line "${line}"

	echo "${STATUS:- } ${COMMIT} ${SUBJECT}"
done < <(cat "${list1}")
