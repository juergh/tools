#!/bin/bash -u

function pr_info() { echo -e "\033[33m${*}\033[0m"; }
function pr_note() { echo -e "\033[93m${*}\033[0m"; }

while IFS= read -r f ; do
	f=${f#./}
	rpi=~/git/raspberry/linux/$f

	case "$f" in
		arch/arm/*) true ;;
		arch/arm64/*) true ;;
		drivers/bluetooth/*) true ;;
		drivers/bus/*) true ;;
		drivers/char/broadcom/*) true ;;
		drivers/char/hw_random/*) true ;;
		drivers/clk/*) true ;;
		drivers/clocksource/*) true ;;
		drivers/dma/*) true ;;
		drivers/firmware/*) true ;;
		drivers/gpio/*) true ;;
		drivers/gpu/drm/v3d/*) true ;;
		drivers/gpu/drm/vc4/*) true ;;
		drivers/i2c/busses/*) true ;;
		drivers/leds/*) true ;;
		drivers/mailbox/*) true ;;
		drivers/media/platform/bcm2835/*) true ;;
		drivers/mfd/*) true ;;
		drivers/misc/*) true ;;
		drivers/mmc/core/*) true ;;
		drivers/mmc/host/*) true ;;
		drivers/net/ethernet/broadcom/genet/*) true ;;
		drivers/net/phy/*) true ;;
		drivers/of/*) true ;;
		drivers/pci/controller/*) true ;;
		drivers/perf/*) true ;;
		drivers/pinctrl/bcm/*) true ;;
		drivers/pwm/*) true ;;
		drivers/regulator/*) true ;;
		drivers/soc/bcm/*) true ;;
		drivers/spi/*) true ;;
		drivers/staging/media/rpivid/*) true ;;
		drivers/staging/vc04_services/*) true ;;
		drivers/thermal/broadcom/*) true ;;
		drivers/tty/serial/8250/*) true ;;
		drivers/usb/dwc2/*) true ;;
		drivers/usb/host/*) true ;;
		drivers/usb/phy/*) true ;;
		drivers/video/fbdev/*) true ;;
		sound/soc/bcm/*) true ;;
		Makefile) true ;;
		*)
			pr_info "Skipping file: $f" >&2
			continue
			;;
	esac

	if ! [ -e "$rpi" ] ; then
		pr_info "No such file: $rpi" >&2
		continue
	fi

	if diff -q "$rpi" "$f" >/dev/null ; then
		pr_info "Identical: $f" >&2
		continue
	fi

	pr_note "*** $f"
	colordiff "$rpi" "$f"
	echo
	echo
#	colordiff -y -W $(tput cols) "$rpi" "$f"
	
done < <(cat "$1")
