# Concepts of Service Mesh

As promised, the book is called "Inside xyz", so why talk about basic concepts? Well, for the sake of:
- Integrity of the content.
- Standardize the terminology that going to use.

## Concepts of service invocation relationships

## Upstream & Downstream

From the Envoy's point of view:

- `upstream`: Role in traffic direction: [downstream] --> envoy --> **[upstream]**.
- `downstream`: Role in flow direction: **[downstream]** --> envoy --> [upstream]

```{warning}
 Note that upstream and downstream are concepts relative to observers.

 Scenario: `service A` ⤜ calls ➙ `service B` ⤜ calls ➙ `service C` .

 - If we stand on `service C`, we are calling `service B` downstream.

 - If we're on `service A`, we're calling `service B` upstream.
```

### Upstream Cluster & Downstream Cluster

The `Upstream Cluster` / `Downstream Cluster` are concepts mainly used in Envoy.  

In general, an `Upstream` / `Downstream` refers to a specific host. An `Upstream Cluster` / `Downstream Cluster` refers to a group of hosts running the same service, in the same configuration. In a k8s environment, this is generally all PODs in the same `k8s Deployment`.

### Inbound & Outbound

From a K8s pod perspective:

:::{figure-md} Inbound & Outbound concepts

<img src="service-mesh-base-concept.assets/inbound-outbound-concept.drawio.svg" alt="Inbound and Outbound Concepts">

*Figure: Inbound vs. Outbound Concepts*
:::
[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Finbound-outbound-concept.drawio.svg)



There are 3 services, called bottom-up.

1. client
2. fortio-server:8080
3. fortio-server-l2:8080

Actually the calling relationship is.

> client ➔ fortio-server:8080 ➔ fortio-server-l2:8080

The layout of the above diagram is also intended to directly reflect the literal meanings of **up**stream and **down**stream. The inbound / outbound terminology is the only thing that needs to be explained in the diagram. First, what is `bound`.

- `bound`: literally means boundary. In a real k8s + Istio environment, it can be interpreted as pod / service.
- `inbound`: In a real k8s + istio environment, this is understood as traffic entering the pod from outside the pod, i.e., invoked traffic for the service.
- `outbound`: In a real k8s + istio environment, this is understood as traffic going out of the pod to the outside of the pod.

> Note that for the same call request. It can be an outbound of the caller's service as well as an inbound of the callee, as shown above.

