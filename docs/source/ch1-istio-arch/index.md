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




## Istio Overall Architecture

The overall architecture of Istio is not the focus of this book. I'm sure that those who are interested in reading this book have already learned about it.
The main purpose of this section is to review the overall architecture. I'm sure the reader is an Istio user, or even an experienced Istio user. But sometimes, when you get too deeply involved in something, it's easy to forget the whole picture.  

This is also a good place to explain the focus of the rest of the book. After all, I have limited energy and interest, so I'm only going to focus on some parts of Istio.


:::{figure-md} Istio's overall architecture.

<img src="index.assets/istio-arch.svg" alt="Istio overall architecture">

Figure : Istio architecture  
From: https://istio.io/latest/docs/ops/deployment/architecture/  
:::


- Proxy 
  This should not need much introduction. The most important component of the data plane. It is also the focus of this book. Because I'm more interested in the data plane than the control plane. Note that the Proxy here is the `istio-proxy` container, which, as you know, has at least two components:
  - `pilot-agent` which belongs to the control plane. 
  - The `Envoy Proxy`, which belongs to the data plane.This is the first focus of the book.
- istiod  
  Nickname: control plane brain, strategic-level command center, authoritative certification authority.


Okay, that's enough of the high level chart for now. After that, we'll start disassembling these components, and analyzing their interactions. Let's go!


```{toctree}
:hidden.
service-mesh-base-concept
istio-ports-components
istio-data-panel-arch
```

