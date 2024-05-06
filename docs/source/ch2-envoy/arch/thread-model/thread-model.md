# Thread model

If you were given an open source middleware and asked to analyze its implementation, what would you start with? The answer might be:
- Source code modules
- Abstract concepts and design patterns
- Threads

For modern open source middleware, I think the thread/process model is most importance. This is because modern middleware basically uses multi-processing or multi-threading to fully utilize hardware resources. No matter how well the abstraction is encapsulated or how elegantly the design patterns are applied, the program has to run on the cpu as a thread. And how multi-threading is divided by function, how to synchronize the communication between threads, these things are the difficulty and focus.


Simply put, Envoy uses the thread design pattern of non-blocking + Event Driven + Multi-Worker-Thread. In the history of software design, there are many names for similar design patterns, such as:
- [staged event-driven architecture (SEDA)](https://en.wikipedia.org/wiki/Staged_event-driven_architecture)
- [Reactor pattern](https://en.wikipedia.org/wiki/Reactor_pattern)
- [Event-driven architecture (EDA)](https://en.wikipedia.org/wiki/Event-driven_architecture)

> This section assumes that the reader has been introduced to Envoy's event-driven model. If not, you can read the book's {doc}`/ch2-envoy/arch/event-driven/event-driven`.
> This section references: [Envoy threading model - Matt Klein](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310)

Unlike the single thread of Node.JS, Envoy supports multiple Worker Threads to run their own independent event loops in order to take full advantage of multi-Core CPUs. This design comes at a cost, because multiple worker threads / main threads are not completely independent from each other. They need to share some data, such as:

- Upstream Cluster's endpoints, health status...
- Various monitoring statistical metrics



## Threading overview

![image-20240506232521005](./thread-model.assets/threading-overview.png)

*Figure : Threading overview*

*Source: [Envoy threading model - Matt Klein](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310)*



> Envoy uses some different types of threads, as shown above. The two importance threads are selected below for illustration:
>
> - **Main**: This thread owns server startup and shutdown, all [xDS API](https://lyft.github.io/envoy/docs/intro/arch_overview/dynamic_configuration.html) handling (including [DNS](https://lyft.github.io/envoy/docs/intro/arch_overview/service_discovery.html), [health checking](https://lyft.github.io/envoy/docs/intro/arch_overview/health_checking.html), and general [cluster management](https://lyft.github.io/envoy/docs/intro/arch_overview/cluster_manager.html)), [runtime](https://lyft.github.io/envoy/docs/intro/arch_overview/runtime.html), stat flushing, admin, and general process management (signals, [hot restart](https://lyft.github.io/envoy/docs/intro/arch_overview/hot_restart.html), etc.). Everything that happens on this thread is asynchronous and “non-blocking.” In general the main thread coordinates all critical process functionality that does not require a large amount of CPU to accomplish. This allows the majority of management code to be written as if it were single threaded.
> - **Worker**: By default, Envoy spawns a worker thread for every hardware thread in the system. (This is controllable via the `--concurrency`[ option](https://lyft.github.io/envoy/docs/operations/cli.html)). Each worker thread runs a “non-blocking” event loop that is responsible for listening on every listener (there is currently no listener sharding), accepting new connections, instantiating a filter stack for the connection, and processing all IO for the lifetime of the connection. Again, this allows the majority of connection handling code to be written as if it were single threaded.







## Thread Local



> Because of the way Envoy separates main thread responsibilities from worker thread responsibilities, there is a requirement that complex processing can be done on the main thread and then made available to each worker thread in a highly concurrent way. This section describes Envoy’s Thread Local Storage (TLS) system at a high level. In the next section I will describe how it is used for handling cluster management.





![image-20240506233017636](./thread-model.assets/thread-local-storage-system.png)



*Source: [Envoy threading model - Matt Klein](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310)*

*Figure : Thread Local Storage (TLS) system*







![image-20240506233250458](./thread-model.assets/cluster-manager-threading.png)

*Source: [Envoy threading model - Matt Klein](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310)*

*Figure : Cluster manager threading*







If the shared data is locked for write and read access, the concurrency will definitely decrease. So the Envoy author referred to the Linux kernel's [read-copy-update (RCU)] (https://en.wikipedia.org/wiki/Read-copy) under the condition that the real-time consistency requirements for data synchronization updates are not high. They have implemented a set of Thread Local data synchronization mechanism. The underlying implementation is based on C++11's `thread_local` function and libevent's `libevent::event_active(&raw_event_, EV_TIMEOUT, 0)`.

The following diagram, based on [Envoy threading model - Matt Klein](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310), attempts to illustrate how Envoy uses the Thread Local mechanism to share data between threads.

:::{figure-md} Figure: ThreadLocal Classes

<img src="/ch2-envoy/arch/thread-model/thread-local-classes.drawio.svg" alt="Figure - ThreadLocal Classes">

*Figure: ThreadLocal Classes*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fthread-local-classes.drawio.svg)*


## Ref

- [Envoy threading model - Matt Klein](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310)