{{/*
Escape XML special characters for attribute values in sdtdserver.xml.
*/}}
{{- define "helm-7dtd.xmlEscape" -}}
{{- . | toString | replace "&" "&amp;" | replace "<" "&lt;" | replace ">" "&gt;" | replace "\"" "&quot;" | replace "'" "&apos;" -}}
{{- end -}}
