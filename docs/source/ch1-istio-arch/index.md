# Istio Architecture

I remember, when I was a kid, I liked to take apart and put back together any electrical appliance - radio, CD player, computer. But there is always a magical ability to integrate the disassembled things back, and then, understand its structure. However, when I look at my children's generation, I don't think they have the interest or opportunity to do that at all... Think about it... What kind of kid would take a ipad apart... And even if they did, the components are so small and sophisticated that they can't see the mechanism. It's hard to find people who are self-driven learners now.

Technological learning, like learning the mechanics of radio, has two directions:

- From big to small (or top-down)

  From the whole, look at functionality, architectural components, component relationships, external interfaces, and data flow. Such as an HTTP request traveling through the Istio architecture.

- From small to large (or bottom up, or bottom to top)

  For example:

  - iptable / netfilter / conntrack for Istio sidecar traffic interception.
  - Envoy HTTP Filter / Route for Istio Destination Rule and Istio Virtual Service.

But in most cases, it's a combination of these two methods.



```{toctree}
:hidden.
istio-arch-overview
service-mesh-base-concept
istio-ports-components
istio-data-panel-arch
```

