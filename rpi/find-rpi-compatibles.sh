#!/bin/bash

dts_arm64=(
	bcm2837-rpi-3-a-plus.dts
	bcm2837-rpi-3-b.dts
	bcm2837-rpi-3-b-plus.dts
	bcm2837-rpi-cm3-io3.dts
	bcm2711-rpi-4-b.dts
)

dts_arm=(
	bcm2836-rpi-2-b.dts
	bcm2837-rpi-3-a-plus.dts
	bcm2837-rpi-3-b.dts
	bcm2837-rpi-3-b-plus.dts
	bcm2837-rpi-cm3-io3.dts
	bcm2711-rpi-4-b.dts
)

function find_compatibles()
{
	local dts=${1}

	comp=
	done=0
	while IFS= read -r line ; do
		if [ "${line#compatible=}" != "${line}" ] ; then
			comp=${line#*=}
			if [ "${line%;}" != "${line}" ] ; then
				done=1
			fi
		elif [ -n "${comp}" ] && [ "${done}" -eq 0 ] ; then
			comp="${comp}${line}"
			if [ "${line%;}" != "${line}" ] ; then
				done=1
			fi
		fi

		if [ "${done}" -eq 1 ] ; then
			echo "${comp}" | sed -e 's/","/\n/g' -e 's/^"//' -e 's/";$//'
			comp=
			done=0
		fi
	done < <(cpp -nostdinc -I include -I arch  -undef -x assembler-with-cpp \
				 "${dts}" | tr -d ' \t')
}

for dts in "${dts_arm[@]}" ; do
	echo "${dts}"
	find_compatibles "arch/arm/boot/dts/${dts}" | sort -u | sed 's/^/  /'
	echo
done
