#!/bin/bash -eu

function out()
{
	local rc=$?

	if [ "${rc}" -ne 0 ] ; then
		echo "Script failed" >&2
	fi
}

function encode_line()
{
	echo "__MARK__${STATUS}__MARK__${COUNT}__MARK__${COMMIT}__MARK__${PATCH_ID}__MARK__${SUBJECT}__MARK__${FUZZY_SUBJECT}__MARK__"
}

trap out EXIT INT TERM HUP

COUNT=0
while IFS= read -r line ; do
	STATUS=
	COUNT=$((COUNT + 1))
	COMMIT=${line%% *}
	PATCH_ID=$(git show "${COMMIT}" | git patch-id)
	PATCH_ID=${PATCH_ID%% *}
	SUBJECT=${line#* }
	FUZZY_SUBJECT=$(echo "${SUBJECT,,}" | tr -c -d '[:alnum:]')

	encode_line
done < <(git log --oneline "$@")
