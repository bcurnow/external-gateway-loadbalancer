# Prompt History

This file documents the prompts used to build the external-gateway-loadbalancer Helm chart. Each prompt represents a major feature or change request that shaped the final implementation.

## Prompt 1: Initial Project Creation (Comprehensive Specification)

**Date Created**: Initial Build

**Status**: ✅ Completed

**Content**:

```
Build a production-ready Helm chart that accomplishes the following:

1. CREATE EXTERNAL GATEWAY WITH KUBERNETES GATEWAY API
   - Use the Kubernetes Gateway API (v1, requires K8s 1.26+)
   - Support Cilium as the primary Gateway Controller (also support Istio, NGINX, Kong)
   - Create Gateway resources with HTTP/HTTPS listener support
   - Support TLS termination with certificate management

2. EXTERNAL SERVICES INTEGRATION
   - Create ExternalName Kubernetes services pointing to external HTTP/HTTPS endpoints
   - Support multiple external services with different protocols and ports
   - Each service can point to single or multiple external endpoints
   - Implement automatic load balancing when multiple endpoints are specified

3. MULTI-ENDPOINT LOAD BALANCING
   - When a service has multiple endpoints, automatically create separate ExternalName services (one per endpoint)
   - Configure HTTPRoute with weighted backend references for equal traffic distribution
   - Make this configurable per service with a loadBalanceAcrossEndpoints flag
   - Example use case: Load balance across 4 Proxmox VE nodes (pve1-4 on port 7480)

4. INTELLIGENT ROUTING WITH HTTPRoute
   - Create HTTPRoute resources for flexible traffic routing
   - Support path-based routing (e.g., /api, /webhooks)
   - Support header-based routing (e.g., X-API-Version header)
   - Support weighted routing for canary deployments (e.g., 90% stable, 10% canary)
   - Support multiple hostnames per route

5. COMPREHENSIVE TEMPLATING
   - Use Helm loops to generate multiple services and routes from values
   - Make the chart configurable through a single values.yaml file
   - Support enabling/disabling resources (services, gateway, routes)
   - Add custom labels and annotations to all resources
   - Include helper templates for common label functions

6. DOCUMENTATION AND EXAMPLES
   - Main README with overview, architecture, quick start, and usage examples
   - ARCHITECTURE.md explaining design decisions and data flow
   - QUICKSTART.md for 5-minute setup with multiple deployment options
   - COMPLETION_SUMMARY.md providing project overview
   - DELIVERABLES.md with comprehensive feature checklist

7. WORKING EXAMPLES (6 total)
   - Simple HTTP: Basic single endpoint service
   - HTTPS with TLS: Service with certificate termination
   - Multi-Service Path Routing: Route different paths to different services
   - Header-Based Routing: Route based on HTTP headers
   - Weighted Load Balancing: Canary deployment pattern (90/10 split)
   - Multi-Endpoint Load Balancing: Load balance across multiple endpoints (e.g., 4 Proxmox nodes)

8. INTERACTIVE SETUP SCRIPT
   - Create setup.sh with:
     - Gateway Controller selection (Cilium first, then Istio, NGINX, Kong)
     - Example configuration selection
     - Automatic namespace creation
     - Deployment verification steps

9. PROJECT STRUCTURE
   - Make the workspace root the Helm chart root (no nested directories)
   - Standard Helm chart layout: Chart.yaml, values.yaml, templates/, examples/
   - All files at root level for clean navigation

10. ADDITIONAL FEATURES
    - Support for multiple gateway listeners on different ports
    - Flexible backend reference configuration
    - Namespace isolation support
    - Service affinity configuration

Deliverables:
- Complete, production-ready Helm chart
- 6 working examples with comprehensive documentation
- 5 documentation files
- Interactive setup script
- All code ready for immediate use
- Full backward compatibility as features are added
```

**Result**: Fully functional Helm chart with Gateway API integration, ExternalName services, flexible routing, load balancing, documentation, examples, and setup automation.

---

## Prompt 2: Update to Cilium (Controller Preference Change)

**Date Applied**: During build refinement

**Status**: ✅ Completed

**Content**:

```
update to use cilium's gateway implementation not istio
```

**Changes Made**:
- Changed primary Gateway Controller from Istio to Cilium
- Updated all documentation to recommend Cilium first
- Updated values.yaml default className to "cilium"
- Updated setup.sh to offer Cilium as option #1
- Updated examples to use Cilium
- Updated installation instructions across all docs
- Maintained backward compatibility with other controllers

---

## Prompt 3: Multi-Endpoint Load Balancing Feature

**Date Applied**: After initial completion

**Status**: ✅ Completed

**Content**:

```
update to support multiple external end points behind a single gateway with load balancing across the end points. For example, four end points: http://pve1:7480, http://pve2:7480, http://pve3:7480, http://pve4:7480 and then create a single gateway (e.g. http://pve:443) which load balances traffic across the end points.
```

**Implementation Details**:
- Modified templates/services.yaml to create separate ExternalName services per endpoint
- Modified templates/httproutes.yaml to auto-generate weighted backend references
- Added loadBalanceAcrossEndpoints flag to values.yaml
- Created new example: multi-endpoint-loadbalancing.yaml
- Updated values.yaml with cluster-service example
- Updated documentation explaining the feature
- Added comprehensive ARCHITECTURE documentation
- Full backward compatibility maintained

**How It Works**:
1. User specifies multiple endpoints in externalServices with loadBalanceAcrossEndpoints: true
2. Chart automatically creates N ExternalName services (service-0, service-1, ..., service-N)
3. HTTPRoute uses weighted backend references with equal distribution (100/N each)
4. Gateway controller distributes traffic based on weights

---

## Implementation Notes

### Architecture Decisions
1. **ExternalName Services**: Used for direct DNS resolution without proxying overhead
2. **Gateway API**: Modern standard with better multi-protocol support than Ingress
3. **Weighted Backend References**: Leverage Gateway API's native load balancing instead of external LB
4. **Automatic Service Expansion**: Transparent to user - they just list endpoints
5. **Cilium Default**: Modern, efficient, native Kubernetes CNI with Gateway API support

### Backward Compatibility
- All new features are additive
- Old configurations continue to work unchanged
- New flags have sensible defaults
- Single-endpoint services work as before

### Testing Strategy
- Each example is a complete, working configuration
- Examples include testing instructions with curl commands
- Documentation includes verification commands
- Load balancing verified via kubectl get services and kubectl describe httproute

---

## Prompt 4: Add Missing HTTPS Gateway with HTTP Backends Example

**Date Applied**: Latest

**Status**: ✅ Completed

**Content**:

```
Review all examples and ensure they cover these 4 core use cases:
- HTTP gateway with HTTP backends
- HTTP/S gateway with HTTP backends
- HTTP/S gateway with HTTP/S backends
- Single gateway where different URLs point to different backend services

Create the missing "HTTP/S gateway with HTTP backends" example.
```

**Implementation Details**:
- Created new example: `https-gateway-with-http-backends.yaml`
- Gateway listens on HTTPS (port 443) with TLS termination
- Backends are HTTP (port 80) - unencrypted within cluster
- Includes two different HTTP backend services
- Updated examples/README.md with new example documentation
- Renumbered existing examples (7 total now)
- Fixed old file path references in examples README

**Complete Use Case Coverage**:
1. ✅ HTTP gateway with HTTP backends (simple-http.yaml)
2. ✅ HTTPS gateway with HTTP backends (https-gateway-with-http-backends.yaml) - NEW
3. ✅ HTTPS gateway with HTTPS backends (https-with-tls.yaml)
4. ✅ Single gateway with path-based routing (multi-service-path-routing.yaml)

**Additional Examples**:
- Header-based routing
- Weighted load balancing (canary)
- Multi-endpoint load balancing

---

## Future Prompts

(To be updated as new features are added)
