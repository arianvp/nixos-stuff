#!/usr/bin/env bash
set -e
set -x

profile=/nix/var/nix/profiles/system

while [ "$#" -gt 0 ]; do
	i="$1"; shift 1
	case "$i" in
		--flake)
			flake="$1"
			shift 1
			;;
		--profile-name|-p)
			if [ "$1" != system ]; then
				profile="/nix/var/nix/profiles/system-profiles/$1"
			fi
			shift 1
			;;
	esac
done

if [[ -n $flake ]]; then
	if [[ $flake =~ ^(.*)\#([^\#\"]*)$ ]]; then
		flake="${BASH_REMATCH[1]}"
		flakeAttr="${BASH_REMATCH[2]}"
	fi
	if [[ -z $flakeAttr ]]; then
		hostname=$(hostnamectl hostname)
		flakeAttr="nixosConfigurations.\"$hostname\""
	else
		flakeAttr="nixosConfigurations.\"$flakeAttr\""
	fi
fi

systemClosure="$(nix build "$flake#$flakeAttr.config.system.build.toplevel" --print-out-paths --profile "$profile" "$@")"

"$systemClosure/bin/switch-to-configuration" switch
