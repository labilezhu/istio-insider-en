# Thread model

Simply put, Envoy uses the thread design pattern of non-blocking + Event Driven + Multi-Worker-Thread. In the history of software design, there are many names for similar design patterns, such as:
- [staged event-driven architecture (SEDA)](https://en.wikipedia.org/wiki/Staged_event-driven_architecture)
- [Reactor pattern](https://en.wikipedia.org/wiki/Reactor_pattern)
- [Event-driven architecture (EDA)](https://en.wikipedia.org/wiki/Event-driven_architecture)

> This section assumes that the reader has been introduced to Envoy's event-driven model. If not, you can read the book's {doc}`ch2-envoy/arch/event-driven/event-driven`.

Unlike the single thread of Node.JS, Envoy supports multiple Worker Threads to run their own independent event loops in order to take full advantage of multi-Core CPUs. This design comes at a cost, because multiple worker threads / main threads are not completely independent from each other. They need to share some data, such as:

- Upstream Cluster's endpoints, health status...
- Various monitoring statistical indicators



## Thread Local

If the shared data is locked for write and read access, the concurrency will definitely decrease. So the Envoy author referred to the Linux kernel's [read-copy-update (RCU)] (https://en.wikipedia.org/wiki/Read-copy) under the condition that the real-time consistency requirements for data synchronization updates are not high. They have implemented a set of Thread Local data synchronization mechanism. The underlying implementation is based on C++11's `thread_local` function and libevent's `libevent::event_active(&raw_event_, EV_TIMEOUT, 0)`.

The following diagram, based on [Envoy threading model - Matt Klein](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310), attempts to illustrate how Envoy uses the Thread Local mechanism to share data between threads.

:::{figure-md} Figure: ThreadLocal Classes

<img src="/ch2-envoy/arch/thread-model/thread-local-classes.drawio.svg" alt="Figure - ThreadLocal Classes">

*Figure: ThreadLocal Classes*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fthread-local-classes.drawio.svg)*


## Ref

- [Envoy threading model - Matt Klein](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310)