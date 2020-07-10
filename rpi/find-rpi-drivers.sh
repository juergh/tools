#!/bin/bash

here=$(dirname "$0")

readarray -t comps < <("${here}"/find-rpi-compatibles.sh | grep '^ ' | \
						   sed -e 's,^\s*,,' | sort -u)

for c in "${comps[@]}" ; do
	echo "${c}"
	git grep -P "\.compatible[\s\t]*=[\s\t]*\"${c}\"" -- *.c | \
		awk -F: '{ print $1 }' | sed 's,^,  ,'
done
