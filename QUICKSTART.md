# 🚀 Quick Start (5 Minutes)

## Simplified Usage

The chart now uses **presence-based enablement**, so you only configure what you need:

```yaml
# Minimal: Services only (no gateway/routes)
externalServices:
  - name: "api"
    port: 80
    endpoints: ["api.example.com"]

---

# Complete: Services + Gateway + Routes
externalServices:
  - name: "api"
    port: 80
    endpoints: ["api.example.com"]

gateway:
  name: "my-gateway"
  className: "cilium"
  listeners: [...]

routes:
  - name: "api-route"
    gateway: "my-gateway"
    hostnames: [...]
    rules: [...]
```

No `enabled` flags needed!

## Step 1: Check Prerequisites (1 min)

```bash
kubectl version --short
helm version
kubectl get nodes
```

## Step 2: Install Gateway API (1 min)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
kubectl get crd | grep gateway
```

## Step 3: Install Gateway Controller (1 min)

Choose ONE option:

**Cilium (Recommended):**
```bash
helm repo add cilium https://helm.cilium.io
helm repo update
helm install cilium cilium/cilium \
  --set kubeProxyReplacement=true \
  --namespace kube-system
```

**Istio:**
```bash
istioctl install --set profile=demo -y
```

**NGINX:**
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx
```

**Kong:**
```bash
helm repo add kong https://charts.konghq.com
helm repo update
helm install kong kong/kong --namespace kong --create-namespace
```

## Step 4: Deploy Chart (1 min)

```bash
# Interactive setup
cd <chart-directory>
./setup.sh

# OR manual deployment with examples
helm install external-gateway . -f ./examples/simple-http.yaml

# Load-balanced multi-endpoint example
helm install external-gateway . -f ./examples/multi-endpoint-loadbalancing.yaml
```

## Step 5: Verify (1 min)

```bash
kubectl get services,gateways,httproutes

# For load-balanced example, verify multiple services created
kubectl get services -l app.kubernetes.io/part-of=proxmox-cluster
```

## Testing Your Deployment

```bash
# Terminal 1: Port-forward
kubectl port-forward svc/cilium-ingress 8080:80

# Terminal 2: Test
curl -H "Host: api.local" http://localhost:8080/

# For load-balanced example
curl -H "Host: pve.example.local" https://localhost:8443/
```

## What You've Built

✅ External services pointing to external HTTP/HTTPS endpoints  
✅ Kubernetes Gateway for ingress traffic  
✅ HTTPRoute for intelligent routing  
✅ All managed via Helm  

## Next Steps

1. **Learn**: Read [README.md](README.md)
2. **Explore**: Try other [examples](examples/README.md)
3. **Customize**: Edit [values.yaml](values.yaml) for your endpoints
4. **Deploy to Production**: Follow checklist in [README.md](README.md#production-checklist)

## Common Next Questions

**Q: How do I point to my own external API?**  
A: Edit the `externalServices[].endpoints` in `values.yaml` to your API URL.

**Q: How do I add HTTPS?**  
A: Create a TLS secret and use the [https-with-tls.yaml](examples/https-with-tls.yaml) example.

**Q: How do I route different paths to different services?**  
A: Use the [multi-service-path-routing.yaml](examples/multi-service-path-routing.yaml) example.

**Q: How do I test canary deployments?**  
A: Use the [weighted-load-balancing.yaml](examples/weighted-load-balancing.yaml) example.

## Troubleshooting

**Routes not working?**
```bash
kubectl describe gateway external-gateway
kubectl describe httproute api-route
kubectl logs -n istio-system -l app=istiod
```

**Need help?**  
See [examples/README.md](examples/README.md#troubleshooting)

---

🎉 **You're all set! You now have a fully functional external gateway load balancer.**
