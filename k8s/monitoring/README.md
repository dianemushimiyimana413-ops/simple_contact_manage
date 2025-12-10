# Monitoring & Alerting (Prometheus / Grafana) — notes

What was added
- Prometheus ConfigMap + Deployment + Service
- Grafana Deployment + Service
- Minimal EFK bundle (Elasticsearch / Fluentd / Kibana) for logs

Alerting rule (error budget example)
- Alert: HighErrorRate
- Expression (example): ratio of 5xx to total requests over 5m > 0.1% (threshold in alerts.yml)
- This is an example SLO: 99.9% availability -> 0.1% error budget. Tune threshold to match your real SLO.

Next steps / production considerations
- Use Alertmanager to route notifications (PagerDuty / Slack / email) and silence/aggregate alerts.
- Replace example EFK with the official Elastic Helm chart or use hosted logging (Elastic Cloud, Logz.io) for production.
- Secure Grafana (admin password via Kubernetes Secret) and enable dashboards (import Prometheus dashboards).
- Add Pod/Cluster metrics exporters (node-exporter, kube-state-metrics) and a PVC for Prometheus TSDB.
- Create HPA and PodDisruptionBudgets; tune Prometheus retention and resources after load testing.

How to enable
- Commit these files to k8s/ and push; the CI workflow applies k8s/ recursively.
- Ensure the application exposes /metrics or instrument it (Prometheus client lib) for accurate alerts.

