#!/bin/bash
#
# get-sts-cc-git-credentials.sh by <ebo@>
#
# This script is used on AWS EC2 Linux to `git clone` a CodeCommit repository using temporary STS credentials provided by an AWS IAM role. 
# 2) Installed awscli
# 3) Installed curl

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

	for bin in aws curl timeout; do
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

