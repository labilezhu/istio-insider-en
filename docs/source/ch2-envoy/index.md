# Inside Envoy

To understand Istio in depth, it is important to understand the Envoy Proxy at the heart of the traffic, and there are three levels of understanding here:
1. understanding the native programmable proxy `Envoy Proxy` architecture
2. understand what Istio's `Istio Customized Envoy Proxy`: [github.com/istio/proxy](https://github.com/istio/proxy) does to extend it
3. understand how istiod can programmatically control `Istio's customized Envoy Proxy` to implement Service Grid functionality

```{toctree}
envoy-overview.md
envoy-istio-conf-eg.md
envoy-high-level-flow/envoy-high-level-flow.md
arch/arch.md
req-resp-flow-timeline/req-resp-flow-timeline.md
connection-life/connection-life.md
circuit-breaking/circuit-breaking.md
envoy-istio-metrics/index.md
upstream/upstream.md
```