#!/bin/bash -eu

function out()
{
	local rc=${?}

	trap - EXIT INT TERM HUP
	[ ${rc} -eq 0 ] || echo "Error: Script failed" >&2
	exit ${rc}
}

function query_lp_bug()
{
	local bug=${1} attr=${2}

	curl -s -S --get "https://api.launchpad.net/devel/bugs/${bug}" | \
		python3 -c "\
import json,sys
obj = json.load(sys.stdin)
print(obj['${attr}'])
"
}

function format_patch()
{
	local branch=${1} odir=${2} msg_id=${3} single_patch=${4}
	local series start rev_range num_commits s subject_prefix opts bug subject new_msg_id f

	rm -rf "${odir}"
	mkdir -p "${odir}"

	series=${branch#*/}
	# FIXME: The following is not robust and flexible enough...
	start=$(git merge-base "${branch}" linux-ubuntu/"${series}"/linux)  # FIXME
	rev_range=${start}..${branch}

	# Generate the subject prefix
	s=${series::1}
	subject_prefix="SRU][${s^}][PATCH"
	if [ -n "${VERSION}" ] ; then
		subject_prefix="${subject_prefix} v${VERSION}"
	fi

	# git format-patch options
	opts=(
		"--thread=shallow"
		"--output-directory=${odir}"
		"--filename-max-length=50"
		"--subject-prefix=${subject_prefix}"
	)

	if [ -n "${msg_id}" ] ; then
		opts+=("--in-reply-to=${msg_id}")
	fi

	if [ "${single_patch}" -eq 0 ] ; then
		# Get the subject for the patch series
		bug=$(git log --format=%b "${rev_range}" | grep -m1 -E '^BugLink: https://' | sed 's|.*/||')
		subject="$(query_lp_bug "${bug}" title) (LP: #${bug})"

		# Generate the cover letter
		cat <<EOF > "${odir}"/cover-letter
${subject}

$(git log --format=%b "${rev_range}" | sed -n 's|^BugLink: https://|https://|p' | sort -u)
EOF

		opts+=(
			"--cover-letter"
			"--cover-from-description=subject"
			"--description-file=${odir}/cover-letter"
		)
	fi

	# Create the patchset
	git format-patch "${opts[@]}" "${rev_range}"

	# HACK: git format-patch creates a cover letter message ID that only contains
	# seconds-since-the-epoc as a unique identifier which results in identical
	# cover letter message IDs for a multi-series submission. Ugh.
	# Hack around that by adding the series name to the message ID.
	if [ -e "${odir}"/0000-cover-letter.patch ] ; then
		msg_id=$(grep -m1 '^Message-ID: ' "${odir}"/0000-cover-letter.patch)
		msg_id=${msg_id#*<}
		msg_id=${msg_id%>*}
		new_msg_id=${series}.${msg_id}
		sed -i "s/${msg_id}/${new_msg_id}/g" "${odir}"/*.patch
	fi

	# Add the series name to the patch filenames
	for f in "${odir}"/0*.patch ; do
		f=${f##*/}
		mv "${odir}"/"${f}" "${odir}"/"${series}-${f}"
	done
}

function sort_series()
{
	while IFS= read -r line ; do
		case "${line}" in
			trusty|xenial) echo "1 ${line}" ;;
			*)             echo "2 ${line}" ;;
		esac
	done | sort -rV | sed 's/^..//'
}

function usage()
{
	cat <<EOF
Usage: ubuntu-format-patch [-h] [-v NUM] [SERIES [SERIES...]]

Positional arguments:
  SERIES  Series name. If not provided, is determined from the available branches.

Optional arguments:
  -h, --help         Show this help text and exit.
  -v, --version NUM  Patch submission version.
EOF
}

VERSION=
series=()

while [ ${#} -gt 0 ] ; do
	case "${1}" in
		-h|--help)
			usage
			exit
			;;
		-v|--version)
			shift
			VERSION=${1}
			;;
		*)
			series=("${@}")
			break
			;;
	esac
	shift
done

trap out EXIT INT TERM HUP

branch_prefix=$(git rev-parse --abbrev-ref HEAD | sed 's,/.*,,')

if [ ${#series[@]} -eq 0 ] ; then
	readarray -t series < <(git branch | sed -n "s,^..${branch_prefix}/,,p")
fi

sha1=$(date -R | sha1sum | awk '{ print $1 }')

#
# Sanity check
#

private=0
public=0
for s in "${series[@]}" ; do
	case "${s}" in
		trusty|xenial|bionic) private=1 ;;
		*) public=1 ;;
	esac
done

if [ ${private} -eq 1 ] && [ ${public} -eq 1 ] ; then
	echo "Can't mix private and public kernels in a single patch series submission" >&2
	exit 1
fi

#
# Create a top-level message ID for multi-series submissions
#

msg_id=
if [ ${#series[@]} -gt 1 ] ; then
	msg_id="<${sha1}.$(date +%s).git.$(git config user.email)>"
fi

#
# Figure out if it's a single patch for all series
#

single_patch=1
for s in "${series[@]}" ; do
	branch=${branch_prefix}/${s}
	start=$(git merge-base "${branch}" linux-ubuntu/"${s}"/linux)  # FIXME
	num_commits=$(git log --oneline "${start}..${branch}" | wc -l)
	if [ "${num_commits}" -ne 1 ] ; then
		single_patch=0
		break
	fi
done

#
# Create the patch series
#

rm -rf .ubuntu-*

for s in "${series[@]}" ; do
	branch=${branch_prefix}/${s}
	odir=.ubuntu-${s}

	echo "-- ${branch}"
	format_patch "${branch}" "${odir}" "${msg_id}" "${single_patch}"
	echo
done

#
# Combine the patch series
#

rm -rf .outgoing
mkdir .outgoing
mv .ubuntu-*/*.patch .outgoing/
rm -rf .ubuntu-*

#
# Create a top-level cover letter for multi-series submissions
#

if [ -n "${msg_id}" ] ; then
	# Get all buglinks from all patches
	readarray -t buglinks < <(sed -n 's|^BugLink: https://|https://|p' .outgoing/*.patch)

	# Submission subject
	bug=${buglinks[0]}
	bug=${bug##*/}
	subject="$(query_lp_bug "${bug}" title) (LP: #${bug})"

	# List of targeted series
	series_list=$(printf "%.1s/" "${series[@]^}")
	series_list=${series_list%/}

	patch="PATCH"
	if [ -n "${VERSION}" ] ; then
		patch="${patch} v${VERSION}"
	fi
	if [ "${single_patch}" -eq 0 ] ; then
		patch="${patch} 0/${#series[@]}"
	fi

	{
		echo "From ${sha1} Mon Sep 17 00:00:00 2001"
		echo "Message-Id: ${msg_id}"
		echo "References: ${msg_id}"
		echo "Subject: [SRU][${series_list}][${patch}] ${subject}"
		echo
		printf "%s\n" "${buglinks[@]}" | sort -u
		echo
		query_lp_bug "${bug}" description
		echo
	} > .outgoing/0000-cover-letter.patch
fi

#
# Done
#

echo "-- Final patch series in .outgoing/"
ls -1 .outgoing/*
