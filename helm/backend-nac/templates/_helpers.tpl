{{- define "gnalarm.repo" -}}
{{- $prefix := default "" -}}
{{- if eq .Values.genians_default_branch "current" -}}
{{- $prefix = "dev" -}}
{{- else if eq .Values.genians_default_branch "beta" -}}
{{- $prefix = "beta" -}}
{{- else if eq .Values.genians_default_branch "rc" -}}
{{- $prefix = "rc" -}}
{{- end -}}
{{- printf "docker.io/genians/genian-msa-gnalarm-%s" $prefix }}
{{- end -}}
