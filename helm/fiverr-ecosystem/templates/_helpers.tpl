{{- define "fiverr-ecosystem.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fiverr-ecosystem.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: fiverr-club-ecosystem
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}
