# Chart Simplification: Presence-Based Enablement

## Summary of Changes

The chart has been updated to use **presence-based enablement**, making it significantly simpler to use and configure.

### What Changed

**Before (Explicit Flags)**:
```yaml
externalServices:
  - name: "api"
    port: 80
    endpoints: ["api.example.com"]

gateway:
  name: "my-gateway"
  className: "cilium"
  # ... listener config ...

routes:
  - name: "api-route"
    gateway: "my-gateway"
    # ... routing rules ...

enabled:  # ← Required before
  services: true
  gateway: true
  routes: true
```

**After (Presence-Based)**:
```yaml
externalServices:
  - name: "api"
    port: 80
    endpoints: ["api.example.com"]

gateway:
  name: "my-gateway"
  className: "cilium"
  # ... listener config ...

routes:
  - name: "api-route"
    gateway: "my-gateway"
    # ... routing rules ...

# No enabled section needed! Just omit sections you don't want.
```

### How It Works

- **Services are created** if `externalServices` is defined and not empty
- **Gateway is created** if `gateway` is defined and not empty
- **Routes are created** if `routes` is defined and not empty
- Simply **omit any section** you don't need - it won't be created

### Files Updated

#### Templates
- `templates/services.yaml`: Changed condition from `if .Values.enabled.services` to `if .Values.externalServices`
- `templates/gateway.yaml`: Changed condition from `if .Values.enabled.gateway` to `if .Values.gateway`
- `templates/httproutes.yaml`: Changed condition from `if .Values.enabled.routes` to `if .Values.routes`

#### Configuration
- `values.yaml`: Removed the entire `enabled` section and added documentation about presence-based enablement

#### Examples
- Updated all 7 example files to remove `enabled` section:
  - `simple-http.yaml`
  - `https-with-tls.yaml`
  - `https-gateway-with-http-backends.yaml`
  - `multi-service-path-routing.yaml`
  - `header-based-routing.yaml`
  - `weighted-load-balancing.yaml`
  - `multi-endpoint-loadbalancing.yaml`

#### New Example
- Added `services-only.yaml`: Demonstrates creating just services without gateway/routes

#### Documentation
- `README.md`: Added "Simplified Configuration" to key features, documented presence-based enablement
- `QUICKSTART.md`: Added section on simplified usage model
- `examples/README.md`: Added explanation of presence-based enablement at the top, added new services-only example

### Use Cases

#### 1. Services Only (Internal Use)
```yaml
externalServices:
  - name: "database-replica"
    port: 5432
    endpoints: ["db.example.com"]
# Services created, no gateway/routes
```

Deploy with:
```bash
helm install external-gateway . -f examples/services-only.yaml
```

#### 2. Complete Setup (External Access)
```yaml
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
    rules: [...]
```

Deploy with:
```bash
helm install external-gateway . -f examples/simple-http.yaml
```

#### 3. Services + Custom Gateway (No Routes)
```yaml
externalServices:
  - name: "api"
    port: 80
    endpoints: ["api.example.com"]

gateway:
  name: "my-gateway"
  className: "cilium"
  listeners: [...]

# routes section omitted - HTTPRoutes won't be created
```

### Backward Compatibility

⚠️ **Breaking Change**: The `enabled` section in `values.yaml` and examples has been removed. 

If you have custom configurations using the `enabled` section, you need to:
1. Remove the `enabled` section entirely
2. If you don't need a component, simply omit that section
3. Components are created based on presence, not flags

### Benefits

1. **Simpler Configuration**: No boolean flags to manage
2. **More Intuitive**: Configuration reflects what gets deployed
3. **Less Boilerplate**: Only define what you need
4. **Easier to Understand**: Clearer relationship between config and output
5. **Flexible Deployment**: Easy to mix and match components

### Migration Guide

For existing deployments:

**Old values.yaml**:
```yaml
externalServices: [...]
gateway: {...}
routes: [...]
enabled:
  services: true
  gateway: true
  routes: true
```

**New values.yaml**:
```yaml
externalServices: [...]
gateway: {...}
routes: [...]
# Remove the enabled section entirely
```

For partial deployments (e.g., services only):

**Old way**:
```yaml
externalServices: [...]
gateway: null
routes: null
enabled:
  services: true
  gateway: false
  routes: false
```

**New way**:
```yaml
externalServices: [...]
# Just omit gateway and routes sections entirely
```

### Examples Updated

All 7 examples in the `examples/` directory have been updated and tested:
- ✅ simple-http.yaml
- ✅ https-with-tls.yaml
- ✅ https-gateway-with-http-backends.yaml
- ✅ multi-service-path-routing.yaml
- ✅ header-based-routing.yaml
- ✅ weighted-load-balancing.yaml
- ✅ multi-endpoint-loadbalancing.yaml
- ✅ services-only.yaml (NEW)

All examples removed their `enabled` section and are ready to deploy as-is.
