# External Gateway Load Balancer

A production-ready Helm chart that creates external services pointing to multiple HTTP/HTTPS endpoints and exposes them via the Kubernetes Gateway API. This chart enables you to manage external service access declaratively with flexible routing, load balancing, and TLS support.

## Key Features

- **Auto-Generated Gateway & Routes**: Define just `externalServices` and the chart auto-generates gateway and routes with intelligent defaults
- **Customizable at Any Level**: Override auto-generation with custom gateway/routes for advanced scenarios
- **Simplified Configuration**: No `enabled` flags - configuration shows exactly what gets created
- **External Service Integration**: Map external HTTP/HTTPS endpoints to Kubernetes services
- **Gateway API Routing**: Use the modern Kubernetes Gateway API to expose these services
- **Multi-Service Management**: Configure multiple services and routes through a single values file
- **Advanced Routing**: Support for path-based, header-based, and weighted routing
- **TLS/HTTPS**: Native support for HTTPS with certificate management
- **Multi-Endpoint Load Balancing**: Automatically load balance across multiple external endpoints
- **Flexible Protocols**: Support scenarios like HTTPS gateway with HTTP backends

## Project Structure

```
external-gateway-loadbalancer/
├── Chart.yaml                      # Chart metadata
├── values.yaml                     # Default configuration values
├── templates/                      # Kubernetes manifest templates
│   ├── _helpers.tpl               # Template helpers
│   ├── services.yaml              # ExternalName services template
│   ├── gateway.yaml               # Gateway API gateway template
│   └── httproutes.yaml            # HTTPRoute template
├── examples/                       # Example configurations
│   ├── README.md                  # Examples guide
│   ├── auto-generated.yaml        # Auto-generated gateway and routes
│   ├── simple-http.yaml           # Minimal HTTP example  
│   ├── https-with-tls.yaml        # Custom gateway with custom routes
│   ├── https-gateway-http-backends.yaml
│   ├── multi-service-path-routing.yaml
│   ├── header-based-routing.yaml
│   └── weighted-load-balancing.yaml
├── ARCHITECTURE.md                 # Architecture documentation
├── AUTO_GENERATION.md              # Auto-generation feature guide
├── QUICKSTART.md                   # Quick start guide
└── LICENSE
```

## Quick Start: Three Approaches

### 1. Minimal - Auto-Generated (Recommended for Simple Cases)

Define just external services - gateway and routes are auto-generated:

```yaml
externalServices:
  - name: "api"
    port: 80
    protocol: "HTTP"
    endpoints: ["api.example.com"]

# Omit gateway and routes sections - they're auto-generated!
# Result: Gateway on HTTP:80, route with hostname "api.local"
```

Deploy: `helm install -f examples/auto-generated.yaml external-gateway .`

### 2. Custom Gateway - Auto-Generated Routes

Customize the gateway, auto-generate routes from services:

```yaml
externalServices:
  - name: "api"
    port: 80
    protocol: "HTTP"
    endpoints: ["api.example.com"]

gateway:
  name: "my-gateway"
  className: "cilium"
  listeners:
    - name: "https"
      protocol: "HTTPS"
      port: 443
      tls:
        mode: "Terminate"
        certificateRefs:
          - name: "gateway-cert"

# Omit routes section - routes are auto-generated for the custom gateway
```

Result: HTTPS gateway (custom) → HTTP backend (auto-routed)

### 3. Full Control - Custom Everything

Customize both gateway and routes:

```yaml
externalServices:
  - name: "api"
    port: 80
    protocol: "HTTP"
    endpoints: ["api.example.com"]

gateway:
  name: "my-gateway"
  className: "cilium"
  listeners: [...]

routes:
  - name: "api-route"
    gateway: "my-gateway"
    hostnames: ["api.local"]
    rules:
      - matches:
          - path:
              type: "PathPrefix"
              value: "/"
        backendRefs:
          - name: "api"
            port: 80
```

See [AUTO_GENERATION.md](AUTO_GENERATION.md) for detailed examples of all three approaches.

### Prerequisites

- Kubernetes 1.26+
- Helm 3.0+
- Gateway API v1 CRDs installed
- A Gateway Controller (Cilium, Istio, NGINX, Kong, etc.)

### 2. Install Gateway API CRDs

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

### 3. Install a Gateway Controller

Choose one based on your infrastructure:

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
helm install ingress-nginx ingress-nginx/ingress-nginx
```

**Kong:**
```bash
helm repo add kong https://charts.konghq.com
helm install kong kong/kong
```

### 4. Deploy the Chart

**Option A: Simple HTTP service**
```bash
helm install external-gateway . \
  -f ./examples/simple-http.yaml \
  --namespace default \
  --create-namespace
```

**Option B: With custom values**
```bash
helm install external-gateway . \
  -f my-values.yaml \
  --namespace default \
  --create-namespace
```

### 5. Verify Installation

```bash
# Check services
kubectl get services -l app.kubernetes.io/name=external-gateway-loadbalancer

# Check gateway
kubectl get gateway

# Check routes
kubectl get httproute
```

## Usage Examples

### Example 1: Simple HTTP Service

Point a Kubernetes service to an external HTTP endpoint:

```yaml
externalServices:
  - name: "external-api"
    port: 80
    protocol: "HTTP"
    endpoints:
      - "api.example.com"

routes:
  - name: "api-route"
    gateway: "external-gateway"
    hostnames:
      - "api.local"
    rules:
      - backendRefs:
          - name: "external-api"
            port: 80
```

### Example 2: Multiple Services with Path Routing

Route different paths to different external services:

```yaml
externalServices:
  - name: "api-service"
    port: 80
    protocol: "HTTP"
    endpoints:
      - "api.example.com"
  - name: "webhook-service"
    port: 80
    protocol: "HTTP"
    endpoints:
      - "webhooks.example.com"

routes:
  - name: "app-routes"
    gateway: "external-gateway"
    hostnames:
      - "app.local"
    rules:
      - matches:
          - path:
              type: "PathPrefix"
              value: "/api"
        backendRefs:
          - name: "api-service"
            port: 80
      - matches:
          - path:
              type: "PathPrefix"
              value: "/webhooks"
        backendRefs:
          - name: "webhook-service"
            port: 80
```

### Example 3: HTTPS with TLS

```yaml
externalServices:
  - name: "secure-api"
    port: 443
    protocol: "HTTPS"
    endpoints:
      - "secure-api.example.com"

gateway:
  name: "secure-gateway"
  listeners:
    - name: "https"
      protocol: "HTTPS"
      port: 443
      tls:
        mode: "Terminate"
        certificateRefs:
          - name: "gateway-cert"
```

### Example 4: Weighted Load Balancing (Canary)

Route traffic with different weights to multiple versions:

```yaml
routes:
  - name: "canary-route"
    gateway: "external-gateway"
    hostnames:
      - "api.local"
    rules:
      - backendRefs:
          - name: "stable-service"
            port: 80
            weight: 90
          - name: "canary-service"
            port: 80
            weight: 10
```

### Example 5: Multi-Endpoint Load Balancing

Load balance traffic across multiple external endpoints using a single service:

```yaml
externalServices:
  - name: "cluster-service"
    port: 8006
    protocol: "HTTPS"
    endpoints:
      - "node1:8006"
      - "node2:8006"
      - "node3:8006"
      - "node4:8006"
    loadBalanceAcrossEndpoints: true
    description: "Cluster load balanced across 4 nodes"

routes:
  - name: "cluster-route"
    gateway: "external-gateway"
    hostnames:
      - "cluster.local"
    rules:
      - backendRefs:
          - name: "cluster-service"
            port: 8006
```

**How it works**:
1. Chart automatically creates separate ExternalName services for each endpoint
2. HTTPRoute uses weighted backend references with equal distribution
3. Gateway controller distributes traffic across all endpoints

**Real-world use cases**:
- Proxmox VE clusters (multiple hypervisors)
- Kubernetes API server replicas
- Distributed databases or caches
- Any service with multiple redundant endpoints

See [examples/multi-endpoint-loadbalancing.yaml](examples/multi-endpoint-loadbalancing.yaml) for a complete working example.

---

## Advanced Features

```yaml
routes:
  - name: "canary-route"
    gateway: "external-gateway"
    rules:
      - backendRefs:
          - name: "api-stable"
            port: 80
            weight: 90
          - name: "api-canary"
            port: 80
            weight: 10
```

See [examples/README.md](./examples/README.md) for detailed examples and instructions.

## Configuration

All configuration is managed through `values.yaml`. Key sections:

### External Services

Define services pointing to external endpoints:

```yaml
externalServices:
  - name: "service-name"
    port: 80
    protocol: "HTTP"
    endpoints:
      - "endpoint.example.com"
    description: "Service description"
```

### Gateway

Configure the Gateway API gateway:

```yaml
gateway:
  name: "external-gateway"
  className: "cilium"  # or istio, nginx, kong, etc.
  listeners:
    - name: "http"
      protocol: "HTTP"
      port: 80
```

### Routes

Define HTTP routes mapping hostnames to services:

```yaml
routes:
  - name: "route-name"
    gateway: "external-gateway"
    hostnames:
      - "example.local"
    rules:
      - matches:
          - path:
              type: "PathPrefix"
              value: "/"
        backendRefs:
          - name: "service-name"
            port: 80
```

See [values.yaml](./values.yaml) for complete configuration reference.

## Advanced Features

### Path-Based Routing
Route different URL paths to different backend services.

### Header-Based Routing
Route requests based on HTTP headers (e.g., API version).

### Weighted Routing
Distribute traffic using weights (useful for canary deployments).

### TLS/HTTPS
Terminate HTTPS connections at the gateway with certificate management.

### Multi-Service Architecture
Manage multiple services and gateways in a single deployment.

## Testing

### Port Forward to Gateway

```bash
kubectl port-forward svc/cilium-ingress 8080:80
```

### Test a Route

```bash
curl -H "Host: api.local" http://localhost:8080/
```

### Verify Service Connectivity

```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://external-api.default.svc.cluster.local
```

## Troubleshooting

### Routes Not Working

1. **Check Gateway Class:**
   ```bash
   kubectl get gatewayclass
   ```

2. **Verify Routes Attached:**
   ```bash
   kubectl describe httproute route-name
   ```

3. **Check Controller Logs:**
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=cilium
   ```

### TLS Issues

Ensure certificate secret exists:
```bash
kubectl get secret gateway-cert
```

### Gateway Listeners Not Ready

Check gateway status:
```bash
kubectl describe gateway external-gateway
```

## Supported Gateway Controllers

- **Cilium** (recommended for Gateway API)
- **NGINX Ingress Controller**
- **Kong**
- **Cilium**
- **Any Gateway API-compliant controller**

## Chart Customization

### Override Values

```bash
helm install external-gateway . \
  --set gateway.className=nginx \
  --set global.namespace=custom-ns \
  -f values.yaml
```

### Selective Enablement

Enable/disable resources:

```yaml
enabled:
  services: true
  gateway: true
  routes: true
```

## Production Checklist

- [ ] Install Gateway API CRDs v1.0+
- [ ] Install and configure Gateway Controller
- [ ] Create TLS certificates for HTTPS endpoints
- [ ] Configure external service endpoints
- [ ] Set appropriate resource limits
- [ ] Enable monitoring and observability
- [ ] Test failover scenarios
- [ ] Document your configuration
- [ ] Set up backup/restore procedures

## Performance Considerations

- **ExternalName Services**: Lightweight, no proxying overhead
- **Weighted Routing**: Requires controller support, minimal overhead
- **TLS Termination**: Adds CPU overhead, consider offloading if needed

## Security Notes

- Ensure TLS certificates are properly managed
- Use network policies to restrict access
- Monitor external endpoint availability
- Implement rate limiting if needed
- Use RBAC to restrict chart deployment

## Uninstallation

```bash
helm uninstall external-gateway --namespace default
```

Note: This only removes Helm-managed resources. Gateway API CRDs and Gateway Controller must be uninstalled separately if desired.

## Contributing

Contributions are welcome! Please:

1. Test your changes
2. Update documentation
3. Follow Kubernetes best practices
4. Ensure backwards compatibility

## Support & Documentation

- **Examples Guide**: [examples/README.md](./examples/README.md)
- **Quick Start**: [QUICKSTART.md](./QUICKSTART.md)
- **Architecture**: [ARCHITECTURE.md](./ARCHITECTURE.md)
- **Configuration**: [values.yaml](./values.yaml)
- **Gateway API Docs**: https://gateway-api.sigs.k8s.io/
- **Kubernetes Services**: https://kubernetes.io/docs/concepts/services-networking/service/

## License

See [LICENSE](LICENSE) file for details.
