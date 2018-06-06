#!/bin/bash
#
# get-sts-cc-git-credentials.sh by <ebo@>
#
# This script is a `credential.helper` for `git` that uses temporary security credentials from an AWS IAM role provided by AWS Security Token Service (AWS STS).
#
# This script cannot be used stand-alone, it must be executed using the `git` command.
#
# Usage:
#
# git clone \
#	-c credential.UseHttpPath=true \
#	-c credential.helper="!/usr/local/bin/get-sts-cc-git-credentials.sh XXX_iam_role" \
#	--no-progress "https://git-codecommit.us-east-1.amazonaws.com/v1/repos/XXX_cc_repo"

set -ueo pipefail

readonly __progname="$(basename "$0")"

errx() {
	echo -e "${__progname} $*" >&2

	exit 1
}

usage() {
	echo -e "${__progname} <IAM role> [AWS account id]" >&2

	exit 1
}

main() {
	[[ "$#" -lt 1 ]] && \
		usage

	for bin in aws curl; do
		which "${bin}" >/dev/null 2>&1 || \
			errx "cannot find '${bin}' in 'PATH=${PATH}'"
	done

	local -r iamrole="$1"
	local -r metadataurl="http://169.254.169.254/latest/dynamic/instance-identity/document"

	if [[ "$#" -ge 2 ]]; then
		local -r awsaccount="$2"
	else
		local -r awsaccount="$(curl -s "${metadataurl}" | \
			awk '/accountId/ { print $3 }' | \
			cut -d '"' -f 2)"
	fi

	local -r rolearn="arn:aws:iam::${awsaccount}:role/${iamrole}"
	local -r session="$(hostname)-$(date +%s)"
	local -ra stscredentials=($(aws sts assume-role \
		--role-arn "${rolearn}" \
		--query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
		--role-session-name "${session}" \
		--output text))

	export AWS_ACCESS_KEY_ID="${stscredentials[0]}"
	export AWS_SECRET_ACCESS_KEY="${stscredentials[1]}"
	export AWS_SESSION_TOKEN="${stscredentials[2]}"

	aws codecommit credential-helper get || \
		errx "'aws codecommit credential-helper get' failed"

	return 0
}

main "$@"

exit $?
