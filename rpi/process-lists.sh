#!/bin/bash -u

list1=$1
list2=$2

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

function encode_line()
{
	echo "__MARK__${STATUS}__MARK__${COUNT}__MARK__${COMMIT}__MARK__${PATCH_ID}__MARK__${SUBJECT}__MARK__${FUZZY_SUBJECT}__MARK__"
}

function find_in_list()
{
	local line=${1} list=${2} commit_log=${3}
	local match

	decode_line "${line}"
	
	# Check if it's a revert
	if [ "${STATUS}" = "R" ] ; then
		echo "${line}"
		return
	fi

	# Check by patch-id
	match=$(grep -F "__MARK__${PATCH_ID}__MARK__" "${list}")
	if [ -n "${match}" ] ; then
		STATUS="P"
		encode_line
		return
	fi

	# Check by subject
	match=$(grep -F "__MARK__${SUBJECT}__MARK__" "${list}")
	if [ -n "${match}" ] ; then
		STATUS="S"
		encode_line
		return
	fi

	# Check by fuzzy subject
	match=$(grep -F "__MARK__${FUZZY_SUBJECT}__MARK__" "${list}")
	if [ -n "${match}" ] ; then
		STATUS="F"
		encode_line
		return
	fi

	# Check if the commit was squashed
	if grep -m1 -q -F "__MARK__${SUBJECT}__MARK__" "${commit_log}" ; then
		STATUS="Q"
		encode_line
		return
	fi

	# Check if it's an upstream backport
	if git log --format=%b "${COMMIT}" -1 | \
	   grep -qP '^[Cc]ommit [0-9a-f]{40} upstream' ; then
		STATUS="U"
		encode_line
		return
	fi

	STATUS="-"
	encode_line
}

decode_line "$(tail -1 "${list2}")"
from=${COMMIT}

decode_line "$(head -1 "${list2}")"
to=${COMMIT}

git log --format=%b "${from}..${to}" | \
	sed -e 's,^,__MARK__,' -e 's,$,__MARK__,' > .tmp

while IFS= read -r line ; do
	find_in_list "${line}" "${list2}" .tmp
done < <(cat "${list1}")
