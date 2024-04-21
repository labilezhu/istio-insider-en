## Envoy main process and concepts

## upstream/upstream

Let's go back to the {doc}`/ch2-envoy/envoy@istio-conf-eg` example:


:::{figure-md}

<img src="/ch1-istio-arch/istio-data-panel-arch.assets/istio-data-panel-arch.drawio.svg" alt="Istio Data Panel Arch">

*Figure:Envoy Configuration in Istio - Deployment*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fistio-data-panel-arch.drawio.svg)*


I will only analyze what is going on inside `fortio-server(pod)` here. In terms of POD traffic, it can be subdivided into two parts:
 - inbound : inbound (called)
 - outbound : outbound (invoked)

But from an Envoy implementation point of view alone, the concepts of `inbound` or `outbound` are rarely used. inbound`/`outbound` are concepts mainly used in Istio. See: {doc}`/ch1-istio-arch/service-mesh-base-concept`.
 section. Envoy uses the concepts of `upstream` and `downstream`.  

For `fortio-server(pod)` inbound.
  - downstream: client pod
  - upstream: app:8080

outbound: downstream: client pod upstream: app:8080 for `fortio-server(pod)`.
 - downstream: app
 - upstream: `fortio-server-l2(pod)`:8080

When I first started learning Istio, the hardest thing to understand was the above concept. The bend was too hard to turn. To wit:

```{attention}
In Istio, from the point of view of the Envoy Proxy within a POD, an app/service process within the same POD is just an ordinary `upstream cluster`. When the app calls a service running on another POD, the target POD is also an `upstream cluster`. It's conceptually the same.
```

:::{figure-md} upstream and downstream abstraction flow from Envoy concepts

<img src="/ch2-envoy/envoy-high-level-flow/envoy-high-level-flow.assets/envoy-high-level-flow-abstract.drawio.svg" alt="Upstream and downstream abstract flows from Envoy concepts. upstream vs. downstream abstract flow">

*upstream and downstream abstraction flows from Envoy concepts*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy-high-level-flow-abstract.drawio.svg)*





