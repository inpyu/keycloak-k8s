#!/bin/bash

function disable_backend-nac()
{
	# Makefile 의 build 옵션에 따라 파일 존재여부가 결정됨
	if [ -f $SCRIPTDIR/helm/.values-static-dev.yaml ]; then
		mv $SCRIPTDIR/helm/values-static.yaml $SCRIPTDIR/helm/.values-static.yaml
		cp $SCRIPTDIR/helm/.values-static-dev.yaml $SCRIPTDIR/helm/values-static.yaml
	fi

	cmd_helmfile "helmfile" -f $SCRIPTDIR/helm/helmfile-backend-nac.yaml destroy
	
	# 아래 명령어를 통해 helmfile-backend-nac.yaml 파일에 다음과 같이 사용할 수 있다.
	# values:
	# 	- values-static.yaml
	# 	- values.yaml
	# 	{{- if eq .Values.env.dev "true" -}}
	# 	- .values-static-dev.yaml
	# 	{{- end }}
	# 
	# 
	# ARGS=""
	# if [ -f $SCRIPTDIR/helm/values-static-dev.yaml ]; then
	# 	ARGS="--state-values-set env.dev=true"
	# fi
	# cmd_helmfile "helmfile" -f $SCRIPTDIR/helm/helmfile-backend-nac.yaml $ARGS destroy
}
