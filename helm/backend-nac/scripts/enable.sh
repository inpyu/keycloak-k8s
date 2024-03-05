#!/bin/bash

function enable_backend-nac()
{
	# Makefile 의 build 옵션에 따라 파일 존재여부가 결정됨
	if [ -f $SCRIPTDIR/helm/.values-static-dev.yaml ]; then
		mv $SCRIPTDIR/helm/values-static.yaml $SCRIPTDIR/helm/.values-static.yaml
		cp $SCRIPTDIR/helm/.values-static-dev.yaml $SCRIPTDIR/helm/values-static.yaml
	else
		source $SCRIPTDIR/helm/nac-tenant/scripts/enable.sh
		enable_nac-tenant

		source $SCRIPTDIR/helm/nac6-tenant/scripts/enable.sh
		enable_nac6-tenant
	fi
	cmd_helmfile "helmfile" -f $SCRIPTDIR/helm/helmfile-backend-nac.yaml apply --wait --suppress-secrets
}
