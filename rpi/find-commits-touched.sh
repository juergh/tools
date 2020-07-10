#!/bin/bash -eu
#
# Find commits that touched the given files
#

list=$1
shift
rev_range=("${@}")

while IFS= read -r commit ; do
	while IFS= read -r f ; do
		if [ "${f#arch/arm/}" = "$f" ] ; then
			continue
		fi
		if grep -qP "^(./)?${f}$" "${list}" ; then
			git log --oneline "${commit}" -1
			break
		fi
	done < <(git log --format= --name-only "${commit}" -1)
done < <(git log --format=%h "${rev_range[@]}")
