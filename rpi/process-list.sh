#!/bin/bash -eu

LINUX=/srv/git/linux.git
LINUX_STABLE=/srv/git/linux-stable.git

function out()
{
	local rc=$?

	if [ "${rc}" -ne 0 ] ; then
		echo "Script failed" >&2
	fi
}

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

function get_line_commit()
{
	local line=${1}
	local tokens

	readarray -t tokens < <(echo "${line}" | sed -e 's,__MARK__,\n,g')
	echo "${tokens[3]}"
}


function encode_line()
{
	echo "__MARK__${STATUS}__MARK__${COUNT}__MARK__${COMMIT}__MARK__${PATCH_ID}__MARK__${SUBJECT}__MARK__${FUZZY_SUBJECT}__MARK__"
}

trap out EXIT INT TERM HUP

list=${1}

declare -A reverted
while IFS= read -r line ; do
	decode_line "${line}"

	# Check if it's an upstream commit
	if git -C "${LINUX}" cat-file -t "${COMMIT}" >/dev/null 2>&1 ; then
		STATUS="L"
		encode_line
		continue
	fi

	# Check if it's an upstream stable commit
	if git -C "${LINUX_STABLE}" cat-file -t "${COMMIT}" >/dev/null 2>&1 ; then
		STATUS="S"
		encode_line
		continue
	fi

	# Check if it's a commit that modifies debian[.foo]/*
	if git log --format= --name-only "${COMMIT}" -1 | grep -q '^debian[./]' ; then
		STATUS="D"
		encode_line
		continue
	fi

	# Check if it's an UBUNTU commit
	if [ "${SUBJECT#UBUNTU}" != "${SUBJECT}" ] ; then
		STATUS="U"
		encode_line
		continue
	fi

	# Check if it's an upstream backport
	if git log --format=%b "${COMMIT}" -1 | \
			grep -qP '^[Cc]ommit [0-9a-f]{40} upstream|[Uu]pstream commit [0-9a-f]{40}' ; then
		STATUS="B"
		encode_line
		continue
	fi

	# Check if it's a reverted commit
	reverted_commit=${reverted[${COMMIT}]:-}
	if [ -n "${reverted_commit}" ] ; then
		STATUS="R"
		encode_line
		continue
	fi

	# Check if it's a revert
	no_revert=${SUBJECT#Revert \"}
	if [ "${no_revert}" != "${SUBJECT}" ] ; then
		no_revert=${no_revert%\"}
		match_line=$(sed "1,${COUNT} d" "${list}" | \
						 grep -m1 -F "__MARK__${no_revert}__MARK__" || true)
		if [ -n "${match_line}" ] ; then
			match_commit=$(get_line_commit "${match_line}")
			reverted[${match_commit}]=${COMMIT}
			STATUS="R"
			encode_line
			continue
		fi
	fi

	encode_line
done < <(cat "${list}")
