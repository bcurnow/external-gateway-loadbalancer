# Examples

This directory contains several example configurations for the external-gateway-loadbalancer Helm chart. Each example demonstrates different use cases and features.

## Auto-Generation with Minimal Configuration

The chart now supports **auto-generation** of gateway and routes, making it extremely simple to use:

- **Define only `externalServices`** and the chart auto-generates:
  - A default Gateway listening on all required protocols (HTTP, HTTPS, etc.)
  - Default HTTPRoutes (one per service with auto-generated hostnames like `service-name.local`)
- **Override with custom `gateway` and/or `routes`** when you need non-default behavior
- **Mix and match**: Auto-generate gateway but custom routes, or vice versa

This means you can:
- Minimal config: Just external endpoints → auto-generated gateway + routes (`auto-generated.yaml`)
- Custom gateway: Define external endpoints + custom gateway → auto-generated routes
- Full control: Define external endpoints + custom gateway + custom routes (`https-with-tls.yaml`, etc.)

No boilerplate configuration needed!

## Quick Start

### Prerequisites

1. Install Gateway API CRDs:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

2. Install a Gateway Controller (choose one):
   - **Cilium**: `helm install cilium cilium/cilium --namespace kube-system`
   - **NGINX**: `helm install ingress-nginx ingress-nginx/ingress-nginx`
   - **Kong**: `helm install kong kong/kong`

## Available Examples

### 0. Auto-Generated Gateway and Routes (`auto-generated.yaml`)

**Use case**: Minimal configuration - just define services, everything else is auto-generated

**Features**:
- Only `externalServices` section defined
- Gateway auto-generated with listeners for all protocols used in services
- Routes auto-generated (one per service with auto-generated hostnames)
- Routes reference external endpoints directly using addresses (no intermediate services)

**Perfect for**:
- Simple deployments with default behavior
- Quickly exposing services without complex routing
- Services that don't need custom hostnames or advanced routing

**Install**:
```bash
helm install external-gateway . \
  -f ./examples/auto-generated.yaml \
  --namespace default \
  --create-namespace
```

**Auto-Generated Resources**:
- Gateway: `external-gateway` (Cilium controller)
- Routes: `web-api-route`, `secure-service-route`
- Hostnames: `web-api.local`, `secure-service.local`

**Test**:
```bash
# Port-forward the gateway
kubectl port-forward svc/cilium-ingress 8080:80 8443:443

# Test HTTP service
curl -H "Host: web-api.local" http://localhost:8080/

# Test HTTPS service (note: auto-generated uses default gateway-cert TLS secret)
curl -k -H "Host: secure-service.local" https://localhost:8443/
```

---

### 1. Simple HTTP Service (`simple-http.yaml`)

**Use case**: Basic HTTP service with auto-generated gateway and routes

**Features**:
- Single HTTP external service
- Auto-generated gateway with HTTP listener
- Auto-generated route with hostname `external-api.local`
- Minimal configuration (just externalServices)

**Install**:
```bash
helm install external-gateway . \
  -f ./examples/simple-http.yaml \
  --namespace default \
  --create-namespace
```

**Test**:
```bash
# Port-forward the gateway
kubectl port-forward svc/cilium-ingress 8080:80

# Test the route (hostname is auto-generated)
curl -H "Host: external-api.local" http://localhost:8080/
```

---

### 2. HTTPS with TLS (`https-with-tls.yaml`)

**Use case**: Secure HTTPS service with TLS termination at the gateway

**Features**:
- HTTPS external service
- TLS listener with certificate termination
- Both HTTP and HTTPS listeners

**Prerequisites**:
Create a TLS secret:
```bash
# Using self-signed certificate (development only)
kubectl create secret tls gateway-cert \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
```

Or generate a self-signed cert for testing:
```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
kubectl create secret tls gateway-cert --cert=cert.pem --key=key.pem
```

**Install**:
```bash
helm install external-gateway . \
  -f ./examples/https-with-tls.yaml \
  --namespace default \
  --create-namespace
```

**Test**:
```bash
# HTTP redirect test
curl -H "Host: secure-api.local" http://localhost:8080/

# HTTPS test (with self-signed cert, use -k to ignore verification)
curl -k -H "Host: secure-api.local" https://localhost:8443/
```

---

### 3. HTTPS Gateway with HTTP Backends (`https-gateway-with-http-backends.yaml`)

**Use case**: HTTPS gateway terminating TLS and forwarding to unencrypted HTTP backends

**Features**:
- HTTPS listener (port 443) with TLS termination
- Multiple HTTP backends (no encryption to backend)
- Gateway terminates TLS, backends receive plain HTTP
- Common pattern for exposing internal HTTP services securely
- Two routes pointing to different HTTP backends

**Architecture**:
```
Client (HTTPS) 
    ↓ (encrypted)
Gateway (TLS termination)
    ↓ (unencrypted HTTP)
Backend Services (api.example.com:80, webhooks.example.com:80)
```

**Prerequisites**: Create TLS secret (same as example 2)
```bash
kubectl create secret tls gateway-cert --cert=cert.pem --key=key.pem
```

**Install**:
```bash
helm install external-gateway . \
  -f ./examples/https-gateway-with-http-backends.yaml \
  --namespace default \
  --create-namespace
```

**Test**:
```bash
# Test API route via HTTPS
curl -k -H "Host: api.example.local" https://localhost:8443/

# Test webhook route via HTTPS
curl -k -H "Host: webhooks.example.local" https://localhost:8443/

# Verify TLS is working (should show certificate info)
curl -v -k https://localhost:8443/ 2>&1 | grep "SSL\|TLS"
```

---

### 3.5. Cert-Manager TLS Automation (`cert-manager-tls.yaml`)

**Use case**: Automatic TLS certificate management with cert-manager

**Features**:
- Gateway with cert-manager annotations for automatic certificate provisioning
- HTTPS listener with automatic TLS certificate management
- No manual certificate management required
- cert-manager creates and renews certificates automatically

**Architecture**:
```
Client (HTTPS)
    ↓
Gateway (cert-manager annotations)
    ↓
cert-manager → Let's Encrypt → Certificate Secret
    ↓
Backend Service (myapp.example.com:443)
```

**Prerequisites**:
- cert-manager installed in cluster
- ClusterIssuer configured (e.g., for Let's Encrypt)
- Gateway API controller with cert-manager integration

**Install**:
```bash
helm install external-gateway . \
  -f ./examples/cert-manager-tls.yaml \
  --namespace default \
  --create-namespace
```

**Test**:
```bash
# Check certificate creation
kubectl get certificates

# Check secret creation
kubectl get secrets secure-app-tls

# Test HTTPS access
curl -H "Host: myapp.example.com" https://your-gateway-ip/
```

---

### 5. Multiple Services with Path-Based Routing (`multi-service-path-routing.yaml`)

**Use case**: Multiple external services routed based on URL paths

**Features**:
- Three different external services
- Path-based routing rules
- `/api` → api-service
- `/webhooks` → webhook-service
- `/auth` → auth-service

**Install**:
```bash
helm install external-gateway . \
  -f ./examples/multi-service-path-routing.yaml \
  --namespace default \
  --create-namespace
```

**Test**:
```bash
# Test API route
curl -H "Host: app.local" http://localhost:8080/api/users

# Test webhooks route
curl -H "Host: app.local" http://localhost:8080/webhooks/github

# Test auth route
curl -H "Host: app.local" http://localhost:8080/auth/login
```

---

### 6. Header-Based Routing (`header-based-routing.yaml`)

**Use case**: Route requests to different services based on HTTP headers

**Features**:
- Two API versions (v1 and v2)
- Routes based on `X-API-Version` header
- Default fallback to v1

**Install**:
```bash
helm install external-gateway . \
  -f ./examples/header-based-routing.yaml \
  --namespace default \
  --create-namespace
```

**Test**:
```bash
# Request v2 API
curl -H "Host: api.local" -H "X-API-Version: v2" http://localhost:8080/

# Request v1 API
curl -H "Host: api.local" -H "X-API-Version: v1" http://localhost:8080/

# Default (no header) - routes to v1
curl -H "Host: api.local" http://localhost:8080/
```

---

### 7. Weighted Load Balancing (`weighted-load-balancing.yaml`)

**Use case**: Canary deployments - gradually roll out new versions

**Features**:
- Two backend services (stable and canary)
- 90% traffic to stable version
- 10% traffic to canary version
- Useful for testing new versions before full rollout

**Install**:
```bash
helm install external-gateway . \
  -f ./examples/weighted-load-balancing.yaml \
  --namespace default \
  --create-namespace
```

**Test**:
```bash
# Send multiple requests to observe distribution
for i in {1..10}; do
  curl -H "Host: api.local" http://localhost:8080/
  echo ""
done
```

---

### 8. Multi-Endpoint Load Balancing (`multi-endpoint-loadbalancing.yaml`)

**Use case**: Load balance traffic across multiple external endpoints using a single service

Perfect for:
- Proxmox VE clusters (multiple hypervisors)
- Kubernetes clusters with multiple API servers
- Any distributed service with multiple nodes

**Features**:
- Single gateway pointing to multiple external endpoints
- Automatic load balancing across all endpoints
- Equal weight distribution by default
- Configurable per service with `loadBalanceAcrossEndpoints` flag

**Example Architecture**:
```
External Endpoints:
├── pve1:8006 (Proxmox node 1)
├── pve2:8006 (Proxmox node 2)
├── pve3:8006 (Proxmox node 3)
└── pve4:8006 (Proxmox node 4)
      ↓
Kubernetes Gateway: pve.example.local (port 443)
      ↓
Cilium Load Balancer (equal distribution)
```

**Install**:
```bash
helm install external-gateway . \
  -f ./examples/multi-endpoint-loadbalancing.yaml \
  --namespace default \
  --create-namespace
```

**Configuration**:

In `values.yaml`, specify multiple endpoints for a service:

```yaml
externalServices:
  - name: "proxmox-cluster"
    port: 8006
    protocol: "HTTPS"
    endpoints:
      - "pve1:8006"
      - "pve2:8006"
      - "pve3:8006"
      - "pve4:8006"
    loadBalanceAcrossEndpoints: true
```

How it works:
1. Chart creates separate ExternalName Kubernetes service for each endpoint
2. HTTPRoute uses weighted backend references (equal weight by default)
3. Cilium distributes traffic equally across all services

**Test**:
```bash
# Enable verbose logging to see load distribution
for i in {1..20}; do
  echo "Request $i:"
  curl -v -H "Host: pve.example.local" https://localhost:443/ 2>&1 | grep -i "Connected"
done

# Check HTTPRoute with load-balanced backend addresses
kubectl get httproutes proxmox-route -o yaml
```

**Manual Weight Configuration**:

To customize weight distribution, modify the route's backendRefs:

```yaml
routes:
  - name: "custom-load"
    rules:
      - backendRefs:
          - name: "service-name"
            port: 8006
            weight: 50  # Custom weight (optional)
```

---

## Common Tasks

### List All Created Resources

```bash
# Check all resources created by the chart
kubectl get gateways,httproutes

# View detailed gateway info
kubectl describe gateway external-gateway
```

### View Route Details

```bash
kubectl describe httproute api-route
```

### Update an Example

```bash
helm upgrade external-gateway . \
  -f https-with-tls.yaml
```

### Remove an Example

```bash
helm uninstall external-gateway --namespace default
```

### Check Gateway Status

```bash
kubectl get gateway external-gateway -o yaml
```

### Debug Route Issues

```bash
# Check if routes are attached to gateway
kubectl get httproutes -o wide

# Check route parentRef status
kubectl get httproutes api-route -o jsonpath='{.status.parents}'

# Check gateway listener status
kubectl get gateways -o jsonpath='{.items[*].status.listeners}'
```

---

## Customization

### Modify Existing Example

Edit any example YAML file and update relevant sections:

```yaml
# Change service endpoint
externalServices:
  - name: "external-api"
    endpoints:
      - "your-api.com"  # Change this

# Change hostname
routes:
  - hostnames:
      - "your-domain.local"  # Change this
```

Then apply:
```bash
helm upgrade external-gateway . -f your-file.yaml
```

### Create Your Own Example

Copy an existing example and modify as needed:

```bash
cp simple-http.yaml my-custom-example.yaml
# Edit my-custom-example.yaml with your values
helm install external-gateway . -f my-custom-example.yaml
```

---

## Troubleshooting

### Routes Not Working

1. Check Gateway Class exists:
```bash
kubectl get gatewayclass
```

2. Verify certificate secret exists (for HTTPS):
```bash
kubectl get secret gateway-cert
```

3. Check route is attached to gateway:
```bash
kubectl describe httproute api-route
```

### Gateway Listeners Not Ready

Check gateway controller logs:
```bash
# For Cilium
kubectl logs -n kube-system -l app.kubernetes.io/name=cilium

# For NGINX
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Test Service Connectivity

```bash
# Test ExternalName service directly
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://external-api.default.svc.cluster.local
```

---

## Gateway Controller-Specific Notes

### Cilium

- Install: `helm install cilium cilium/cilium --namespace kube-system`
- Gateway class name: `cilium`
- Status check: `kubectl get gateways,httproutes` (Gateway API resources)

### Istio

- Install: `istioctl install --set profile=demo`
- Gateway class name: `istio`
- Status check: `kubectl get vs,dr` (Virtual Services and Destination Rules)

### NGINX

- Install: `helm install ingress-nginx ingress-nginx/ingress-nginx`
- Gateway class name: `nginx`
- Requires NGINX Ingress Controller v1.0+

### Kong

- Install: `helm install kong kong/kong`
- Gateway class name: `kong`
- Additional configuration may be needed

---

## Additional Resources

- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [ExternalName Services](https://kubernetes.io/docs/concepts/services-networking/service/#externalname)
- [HTTPRoute Documentation](https://gateway-api.sigs.k8s.io/api-types/httproute/)

