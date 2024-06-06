---
typora-root-url: ../../..
---

## Network Filter

## Network Filter Chains
In the {ref}`Figure: Example of Envoy Inbound Configuration in Istio` in the previous chapter, it can be seen that a Listener can contain multiple `Network Filter Chains`. Each of these chains has its own `filter_chain_match`, which is used to configure the policy of the `Network Filter Chain` selected by the newly created `Inbound Connection`.

Each `Network Filter Chain` has its own name. *Note that duplicate `Network Filter Chain` names are allowed.*

Each `Network Filter Chain` consists of sequential `Network Filters`. 

## Network Filter Overview

Envoy uses a multi-layer plug-in design pattern to ensure scalability. The `Network Filter` is the L2 / L3 (IP/TCP) layer component. For example, in the {ref}`Figure: Example of Envoy Inbound Configuration in Istio` above, there are, in order, the following:
1. istio.metadata_exchange `Network Filter`
2. envoy.filters.network.http_connection_manager `Network Filter`

Two network filters, of course, the heavy HTTP proxy tasks is done on `http_connection_manager` network filter.

### Network Filter Framework Design Concepts

As I was learning about Envoy's Network Filter framework design, I realized that it is very different from what I thought a Filter design would be. It was even a bit counter-intuitive. See the following diagram:

:::{figure-md} Figure: Model of Network Filter Framework

<img src="/ch2-envoy/arch/network-filter/network-filter-framework-concept.drawio.svg" alt="Figure - Model of Network Filter Framework">

*Figure: Model of Network Filter Framework*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fnetwork-filter-framework-concept.drawio.svg)*

Here's just a word in terms of `ReadFilter`:

`My intuition Ideal model` is:
 1. the concept of `Upstream` exists in the Filter framework layer.
 2. the output data and events of one Filter will be the input data and events of the next Filter. Since this is called Chain, it should be similar to Linux's `cat myfile | grep abc | grep def`. 
 3. The Buffer between Filters should be isolated.


In the `realistic model`, there is no `framework` level.
1. at the framework level, there is no concept of `Upstream`, the Filter implementation implements or does not implement `Upstream`, including connection establishment and data read/write, event notification. So, at the framework level, there is no concept of Cluster / Connection Pool, etc. 
2. See the following item
3. Filters share the Buffer with each other, if the previous Filter reads the Buffer without `drained`, the following Filter will read the data repeatedly. The previous Filter can also insert new data into the Buffer. And this stateful Buffer will be passed to the later Filter.
4. Since "at the framework level, there is no concept of `Upstream`", `WriteFilter` is not a module that intuitively writes Request/Data to `Upstream`, but a module that writes Response/Data to `Downstream`.

### Network Filter object relationships

Now that I've written this, it's time to look at the code. But not directly. Let's look at the C++ class diagram first.


:::{figure-md} Figure: Network Filter object relationships

<img src="/ch2-envoy/arch/network-filter/network-filter-hierarchy.drawio.svg" alt="Figure - Network Filter object relationships">

*Figure: Network Filter Object Relationships*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fnetwork-filter-hierarchy.drawio.svg)*


As you can see, `WriteFilter` is not commonly used in our daily life :) .


### Network Filter Framework Design Details
At the code implementation level, the Network Filter framework has the following collaboration between abstract objects:

:::{figure-md} Figure: Network Filter framework abstraction collaboration

<img src="/ch2-envoy/arch/network-filter/network-filter-framework.drawio.svg" alt="Figure - Network Filter framework abstraction collaboration">

*Figure: Network Filter framework abstraction collaboration*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fnetwork-filter-framework.drawio.svg)*


Below, the classic TCP Proxy Filter is used as an example.


:::{figure-md} Figure : Network Filter Framework - TCP Proxy Filter Example

<img src="/ch2-envoy/arch/network-filter/network-filter-tcpproxy.drawio.svg" alt="Figure - Network Filter Framework - TCP Proxy Filter Example">

*Figure : Network Filter Framework - TCP Proxy Filter Example*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fnetwork-filter-tcpproxy.drawio.svg)*


#### Network Filter - ReadFilter Collaboration

:::{figure-md} Figure : Network Filter - ReadFilter Collaboration

<img src="/ch2-envoy/arch/network-filter/network-filter-readfilter.drawio.svg" alt="Figure - Network Filter - ReadFilter Collaboration">

*Figure : Network Filter - ReadFilter Collaboration*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fnetwork-filter-readfilter.drawio.svg)*

The `ReadFilter` collaboration is a bit more complex and is the core logic of the Network Filter Framework. That's why it's important to talk about it in detail.
As mentioned before, the Framework itself does not directly provide the Upstream / Upstream Connection Pool / Cluster / Route abstractions and related events. Instead, we'll refer to these as `External Objects and Events`, and the Filter implementation needs to create or get these `External Objects` and listen for these `External Events` itself. External events may include:

- Upstream Domain Name Interpretation Completed
- Upstream Connection Pool connection available
- Upstream socket read ready
- Upstream write buffer full
- ...




#### Network Filter - WriteFilter Collaboration

:::{figure-md} Figure: Network Filter - WriteFilter Collaboration

<img src="/ch2-envoy/arch/network-filter/network-filter-writefilter.drawio.svg" alt="Figure - Network Filter - WriteFilter Collaboration">

*Figure: Network Filter - WriteFilter Collaboration*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fnetwork-filter-writefilter.drawio.svg)*

Since `WriteFilter` has limited usage scenarios in Envoy, only MySQLFilter / PostgresFilter / KafkaBrokerFilter and Istio's MetadataExchangeFilter. So I won't expand on that here.

## Extended Reading

If you are interested in studying the implementation details of Listener, I recommend checking out my blog posts:
 - [Reverse Engineering and Cloud Native Field Analysis Part2 -- eBPF Trace Istio/Envoy Startup, Listening and Thread Load Balancing](https://blog.mygraphql.com/zh/posts/low-tec/trace/trace-istio/trace-istio-part2/)
 - [Reverse Engineering and Cloud Native Field Analysis Part3 -- eBPF Trace Istio/Envoy Event-Driven Model, Connection Establishment, TLS Handshake and Filter_Chain Selection](https://blog.mygraphql.com/zh/posts/low-tec/trace/trace-istio/trace-istio-part3/)
 - [Taming a Network Filter](https://blog.envoyproxy.io/taming-a-network-filter-44adcf91517)