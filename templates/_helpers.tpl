{{/*
  _helpers.tpl — reusable named templates for the network-policy-chart
*/}}

{{/*
  chart.namespace — resolves the target namespace
*/}}
{{- define "chart.namespace" -}}
{{ .Values.namespace | default "default" }}
{{- end }}

{{/*
  chart.labels — common labels attached to every resource
*/}}
{{- define "chart.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
