#!/usr/bin/env bash

new_vars() {
	local key=keys/lm-ed
	local device="${DEVICE:=c3.small.x86}"
	local device_count="${DEVICE_COUNT:=2}"
	local flintlock_version="${FLINTLOCK_VERSION:=latest}"
	local project_name="${PROJECT_NAME:=liquid-metal-acceptance-tests}"

	dir="$(dirname "$(realpath "$0")")"

	# we increment the count before the capacity check, because
	# the device_count only includes the devices used to run flintlock,
	# whereas we need to check for capacity with the dhcp/nat device
	# included.
	((device_count++))
	metro="$("$dir"/check.py "$device" "$device_count")"
	if [ "$metro" == "" ]; then
		exit 1
	fi
	# # put the count back afterwards
	((device_count--))

	mkdir keys || true
	rm keys/* || true
	ssh-keygen -q -f "$key" -t ed25519 -N ""
	public_key=$(cat $key.pub)
	private_key_path="$(dirname "$dir")/$key"

	jq --arg org "$METAL_ORG_ID" \
		--arg token "$METAL_AUTH_TOKEN" \
		--arg pub_key "$public_key" \
		--arg priv_key "$private_key_path" \
		--arg metro "$metro" \
		--arg device "$device" \
		--arg host_device_count "$device_count" \
		--arg fl_version "$flintlock_version" \
		--arg prj_name "$project_name" \
		'.org_id = $org |
		.metal_auth_token = $token |
		.public_key = $pub_key |
		.private_key_path = $priv_key |
		.metro = $metro |
		.microvm_host_device_count = $host_device_count |
		.flintlock_version = $fl_version |
		.project_name = $prj_name |
		.server_type = $device' \
		./terraform/terraform.tfvars.example.json > ./terraform/terraform.tfvars.json
}

tf_up() {
	pushd terraform || exit 1
	terraform init
	terraform plan --out ../apply.tf
	terraform apply --auto-approve ../apply.tf
	popd || exit 1
}

tf_down() {
	pushd terraform || exit 1
	terraform destroy --auto-approve
	popd || exit 1
}

if [ $# = 0 ]; then
	echo "No command provided. Use '--vars', '--up' or '--down'"
	exit 1
fi

if [[ -z "${METAL_AUTH_TOKEN}" ]]; then
	echo "METAL_AUTH_TOKEN required"
	exit 1
fi

if [[ -z "${METAL_ORG_ID}" ]]; then
	echo "METAL_ORG_ID required"
	exit 1
fi

while [ $# -gt 0 ]; do
	case "$1" in
	-v | --vars)
		new_vars || exit 1
		;;
	-u | --up)
		tf_up || exit 1
		;;
	-d | --down)
		tf_down || exit 1
		;;
	-*)
		echo "Unknown arg: $1. Use --vars, --up or --down"
		;;
	*)
		break
		;;
	esac
	shift
done
