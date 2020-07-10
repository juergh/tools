#!/bin/bash -u
#
# Merge the processed list1 into list2
#

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
list2=$2

cp "${list2}" .tmp

# Append upstream commits to the end of the results list
grep -F '__MARK__U__MARK__' "${list1}" >> .tmp

block=()
while IFS= read -r line ; do
	decode_line "${line}"

	case "${STATUS}" in
		-)
			block+=("${line}")
			;;
		R|Q|U)
			# Skip reverts, squashes and upstream commits
			continue
			;;
		P|S|F)
			if [ "${#block[@]}" -eq 0 ] ; then
				continue
			fi
			case "${STATUS}" in
				P) pattern="__MARK__${PATCH_ID}__MARK__" ;;
				S) pattern="__MARK__${SUBJECT}__MARK__" ;;
				F) pattern="__MARK__${FUZZY_SUBJECT}__MARK__" ;;
			esac
			match=$(grep -nF "${pattern}" .tmp | tail -1)
			if [ -z "${match}" ] ; then
				echo "FATAL: No match" >&2
				exit 1
			fi
			(
				head -n "${match%%:*}" .tmp
				printf '%s\n' "${block[@]}" | tac
				tail -n +"$((${match%%:*} + 1))" .tmp
			) > .tmp1
			mv  .tmp1 .tmp
			block=()
			;;
	esac
done < <(tac "${list1}")

if [ "${#block[@]}" -ne 0 ] ; then
	(
		printf '%s\n' "${block[@]}" | tac
		cat .tmp
	) > .tmp1
	mv .tmp1 .tmp
fi

cat .tmp
