# Architecture & Design

## Overview

The External Gateway Load Balancer is a Kubernetes Helm chart that bridges external HTTP/HTTPS services with the Kubernetes Gateway API. It enables declarative management of external service access with advanced routing capabilities.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            Gateway API Resources                     │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │                                                       │   │
│  │  Gateway                   HTTPRoute                 │   │
│  │  ┌────────────────────┐   ┌─────────────────────┐   │   │
│  │  │ name: external-gw  │   │ name: api-route     │   │   │
│  │  │ port: 80, 443      │──▶│ hostnames: *.local  │   │   │
│  │  │ listeners: http/s  │   │ rules: path, header │   │   │
│  │  └────────────────────┘   └─────────────────────┘   │   │
│  │           ▲                         ▲                │   │
│  │           │ deploys                 │ routes to     │   │
│  │           │ (GatewayClass=cilium)   │               │   │
│  │           │                         │               │   │
│  └──────────────────────────────────────────────────────┘   │
│           │                                 │                │
│           ▼                                 ▼                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Kubernetes Services                          │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │                                                       │   │
│  │  Service: external-api (ExternalName)               │   │
│  │  ├─ Type: ExternalName                              │   │
│  │  ├─ externalName: api.example.com                   │   │
│  │  └─ Port: 80                                         │   │
│  │                                                       │   │
│  │  Service: webhook-service (ExternalName)            │   │
│  │  ├─ Type: ExternalName                              │   │
│  │  ├─ externalName: webhooks.example.com              │   │
│  │  └─ Port: 80                                         │   │
│  │                                                       │   │
│  └──────────────────────────────────────────────────────┘   │
│           │                        │                        │
│           └────────────────────────┴────────────────────┐   │
│                                                         │   │
│                   DNS Resolution                        │   │
│                   (CoreDNS)                             │   │
└─────────────────────────────────────────────────────────────┘
                      │                    │
        ┌─────────────┘                    └──────────────┐
        │                                                  │
        ▼                                                  ▼
    ┌────────────────┐                          ┌─────────────────┐
    │ api.example.com│                          │webhooks.example│
    │ (External)     │                          │.com (External)  │
    └────────────────┘                          └─────────────────┘
```

## Component Details

### 1. ExternalName Services

**Role**: Provide service discovery for external endpoints

- **Type**: `ExternalName`
- **Function**: DNS alias to external services
- **No Proxying**: Direct DNS resolution, minimal overhead
- **Created by**: `templates/services.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: api.example.com
  ports:
    - port: 80
      targetPort: 80
```

### 2. Gateway

**Role**: Accepts inbound traffic and applies routing rules

- **API**: `gateway.networking.k8s.io/v1`
- **Listeners**: Define ports and protocols (HTTP, HTTPS)
- **TLS**: Terminate HTTPS connections
- **Controller**: Gateway controller implements actual routing (Cilium, Istio, NGINX, Kong)
- **Created by**: `templates/gateway.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: external-gateway
spec:
  gatewayClassName: cilium
  listeners:
    - name: http
      protocol: HTTP
      port: 80
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: gateway-cert
```

### 3. HTTPRoute

**Role**: Define routing rules for HTTP traffic

- **API**: `gateway.networking.k8s.io/v1`
- **Hostnames**: Route based on incoming Host header
- **Matching**: Path prefix, HTTP method, headers
- **Backend References**: Which services to route to
- **Weights**: Traffic distribution percentages
- **Created by**: `templates/httproutes.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: api-route
spec:
  parentRefs:
    - name: external-gateway
  hostnames:
    - "api.local"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: "/api"
      backendRefs:
        - name: external-api
          port: 80
```

## Data Flow

### Request Processing

```
1. External Client Request
   │
   ├─ Host: api.local
   ├─ Path: /api/users
   └─ Port: 80 (HTTP)
       │
       ▼
2. Reaches Gateway (via ingress)
   │
   ├─ Check listener (port 80, HTTP)
   ├─ Extract hostname and path
   └─ Lookup matching HTTPRoute
       │
       ▼
3. Route Matching
   │
   ├─ Match hostname: api.local ✓
   ├─ Match path: /api ✓
   ├─ No header constraints
   └─ Route found: api-route
       │
       ▼
4. Backend Selection
   │
   ├─ Service: external-api
   ├─ Port: 80
   └─ No weights (single backend)
       │
       ▼
5. DNS Resolution
   │
   ├─ Query: external-api.default.svc.cluster.local
   ├─ Response: CNAME to api.example.com
   └─ CoreDNS resolves to external IP
       │
       ▼
6. Connection Established
   │
   └─ Traffic flows to api.example.com:80
```

## Configuration Hierarchy

```
values.yaml (Global Configuration)
    │
    ├─ externalServices[]
    │   ├─ name, port, protocol
    │   ├─ endpoints[] (single or multiple)
    │   └─ loadBalanceAcrossEndpoints (enable/disable LB)
    │
    ├─ gateway
    │   ├─ name, className
    │   └─ listeners[] (HTTP/HTTPS configuration)
    │
    ├─ routes[]
    │   ├─ Host-based routing (hostnames)
    │   ├─ Path-based routing (path matches)
    │   ├─ Header-based routing (header matches)
    │   └─ Weighted routing (traffic distribution)
    │
    └─ enabled
        ├─ services (create ExternalName services)
        ├─ gateway (create Gateway)
        └─ routes (create HTTPRoutes)
```

## Multi-Endpoint Load Balancing

When a service has multiple endpoints with `loadBalanceAcrossEndpoints: true`, the chart automatically creates multiple ExternalName services and configures load balancing:

```
Single Service Definition (values.yaml):
    cluster-service:
      endpoints:
        - node1:8006
        - node2:8006
        - node3:8006
        - node4:8006
      loadBalanceAcrossEndpoints: true
        │
        ▼
Chart generates:
    Service: cluster-service-0 → node1:8006
    Service: cluster-service-1 → node2:8006
    Service: cluster-service-2 → node3:8006
    Service: cluster-service-3 → node4:8006
        │
        ▼
HTTPRoute backend refs (weighted):
    backendRefs:
      - cluster-service-0 (weight: 25)
      - cluster-service-1 (weight: 25)
      - cluster-service-2 (weight: 25)
      - cluster-service-3 (weight: 25)
        │
        ▼
Gateway Controller Distribution:
    Cilium distributes traffic equally across all weighted refs
```

### How It Works

1. **Chart Expansion**: Single service with N endpoints → N ExternalName services
2. **Automatic Weighting**: Equal weight to each endpoint (100/N per endpoint)
3. **Gateway Distribution**: Controller distributes traffic based on weights
4. **No External LB Needed**: All logic contained in Kubernetes

### When to Use

- **Kubernetes HA**: Multiple API servers
- **Distributed Services**: Database replicas, caches
- **Hypervisor Clusters**: Proxmox VE, VMware ESXi clusters
- **Service Mesh**: Multiple service instances

### Configuration Example

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

routes:
  - name: "pve-route"
    rules:
      - backendRefs:
          - name: "proxmox-cluster"
            port: 8006
```

## Template Processing

```
Chart Templates:
    │
    ├─ templates/services.yaml
    │   └─ For each service in externalServices[]:
    │       ├─ If loadBalanceAcrossEndpoints && multiple endpoints:
    │       │   └─ Create Service per endpoint (service-0, service-1, ...)
    │       └─ Else:
    │           └─ Create single Service from first endpoint
    │
    ├─ templates/gateway.yaml
    │   └─ Creates: Single Gateway resource
    │       Uses: gateway config + listeners[]
    │
    ├─ templates/httproutes.yaml
    │   └─ For each route in routes[]:
    │       ├─ For each backendRef:
    │       │   ├─ If service has multiple endpoints:
    │       │   │   └─ Create weighted refs for all endpoint services
    │       │   └─ Else:
    │       │       └─ Create single backendRef
    │       └─ Create: HTTPRoute resource
    │
    └─ templates/_helpers.tpl
        └─ Common labels, selectors, utility functions
```

## Key Design Decisions

### 1. ExternalName Services

**Why**: Provides Kubernetes-native service discovery
- **Pros**: No proxying overhead, simple DNS resolution
- **Cons**: No load balancing, health checks limited
- **Use Case**: Perfect for direct external service access

### 2. Multi-Endpoint Load Balancing via HTTPRoute Weights

**Why**: Leverage Gateway API's native weighted distribution
- **Pros**: No external load balancer needed, controller handles distribution
- **Cons**: Requires Gateway controller support for weights
- **Use Case**: Distributing traffic across multiple endpoints

### 3. Gateway API (not Ingress)

**Why**: Modern, standardized, multi-protocol support
- **Pros**: Native support for HTTP/HTTPS, TLS, advanced routing
- **Cons**: Requires CRDs and controller
- **Use Case**: Enterprise-grade routing with flexibility

### 3. Declarative Configuration

**Why**: Infrastructure as Code approach
- **Pros**: Version control, reproducible, auditable
- **Cons**: Requires Helm knowledge
- **Use Case**: GitOps-friendly deployments

## Security Considerations

### Network Access

```
┌─ TLS Termination at Gateway
│  └─ Client ──HTTPS──▶ Gateway ──HTTP──▶ Service
│
├─ Certificate Management
│  └─ Stored in Kubernetes Secrets
│
├─ Network Policies
│  └─ Can restrict pod-to-pod communication
│
└─ RBAC
   └─ Control who can deploy/modify charts
```

### Best Practices

1. **TLS Certificates**: Use proper CA-signed certificates in production
2. **Network Policies**: Restrict access to gateway only
3. **RBAC**: Limit chart modification to authorized users
4. **Monitoring**: Track all external service access
5. **Secrets**: Never commit credentials to git

## Scalability

### Horizontal Scaling

```
Multiple Gateway Controllers (HA)
    ├─ Cilium: Multiple cilium replicas per node
    ├─ NGINX: Multiple controller replicas
    └─ Kong: Clustered deployment

Load Distribution
    ├─ Gateway load balancing
    ├─ HTTPRoute weighted routing
    └─ External service endpoints
```

### Performance Characteristics

| Component | Latency | Notes |
|-----------|---------|-------|
| ExternalName Service | ~1ms | DNS resolution only |
| Gateway API | ~5-10ms | Controller-dependent |
| TLS Termination | +2-5ms | CPU-intensive |
| Path Matching | <1ms | Fast prefix matching |
| Header Matching | <1ms | Fast string comparison |

## Limitations & Constraints

### Gateway API Constraints

- Requires v1 API (Kubernetes 1.26+)
- Depends on compatible controller
- TLS can only terminate at gateway level
- Backend services must be reachable from cluster

### ExternalName Service Constraints

- No load balancing between multiple endpoints
- Only first endpoint is used
- No health checking
- For HA, use multiple services with separate routes

### Known Limitations

- Cannot modify DNS responses (gateway-level only)
- Limited to L7 (HTTP/HTTPS) routing
- No TCP routing (use separate resources)
- Certificate rotation manual or via operator

## Future Enhancements

1. **TCPRoute Support**: For non-HTTP protocols
2. **GRPCRoute Support**: For gRPC services
3. **Service Discovery**: Dynamic endpoint discovery
4. **Health Checks**: Active health monitoring
5. **Observability**: Built-in metrics/tracing
6. **Certificate Automation**: Let's Encrypt integration
7. **Multiple Services per Route**: Load balancing across external APIs

## References

- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [ExternalName Services](https://kubernetes.io/docs/concepts/services-networking/service/#externalname)
- [HTTPRoute Specification](https://gateway-api.sigs.k8s.io/api-types/httproute/)
- [Gateway Specification](https://gateway-api.sigs.k8s.io/api-types/gateway/)
