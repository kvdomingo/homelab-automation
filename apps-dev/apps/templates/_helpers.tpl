{{- define "apps.finalizers" -}}
- resources-finalizer.argocd.argoproj.io
{{- end }}

{{- define "apps.argocdNamespace" -}}
argocd
{{- end}}
