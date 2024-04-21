## Source code design



## Design Patterns and Jargon

From time to time, people ask how to quickly and systematically learn about a domain. In the modern world, most knowledge is publicly accessible. But the annoying thing is that the documentation is all there, the source code is there, every word in the documentation is understood, and every line in the source code seems to be understood. But it is still quite difficult to grasp the mechanics of a system as a whole. Even if you narrow down the scope to learning a software system, or just say, Envoy.

Envoy is an open-source software, and the documentation is very detail that is rare in open-source projects; C++14 is written in a way that is much more approachable than C and C++1998. The readability is close to that of Java, and there are not as many acronyms as when looking at the Linux kernel. But like any other software source code, Envoy has its own design patterns and jargon, and understanding the jargon makes understanding source code more easy.



### Callback design pattern

Gang of Four's (GoF) *Design Patterns* does not have a design pattern called `Callback`. The `Callback design pattern` is actually a variant or application of the [`Observer pattern`](https://en.wikipedia.org/wiki/Observer_pattern).


> The Observer pattern solves the following problems:
>
> - Uncoupling one-to-many dependencies between objects to avoid tight coupling of objects.
> - Automatically update an unlimited number of dependent objects when an object changes state.
> - An object can notify multiple other objects.

Above is an explanation of the `Observer pattern` from [Wkipedia](https://en.wikipedia.org/wiki/Observer_pattern). I think essentially the observer pattern is more of a design pattern that uses `agnosticism` to invert object dependencies.

In Envoy, its main purpose is to allow subsystems to be designed independently of each other. Envoy makes extensive use of this `Callback Design Pattern` and has its own naming convention. This is the hurdle to cross in order to understanding Envoy code.



![*OOP Subsystem Callback Design Pattern*](./oop-subsystem-callback.drawio.svg)



There are two subsystems above, `Network::TransportSocket` and `Network::Connection`. If every subsystem that uses `Network::TransportSocket` had to rely on `Network::TransportSocket` for notifications, the result would be a circular dependency. The Callback design pattern avoids this problem.



## Subsystems

Envoy is designed to be modular, with many subsystems that are independent of each other at compile time. These subsystems interact with each other through explicit dependencies and dependency inversion methods such as Callback glue. In general, each subsystem has its own C++ namespace (several related subsystems share a namespace). The main subsystems are listed below:



- `Buffer` - the buffer block
- `Api` - operating system calls
- `Config` - Configurations such as XDS.
- `Event` - Event-driven
- `Http` - HTTP related
  - `Http::ConnectionPool` - HTTP connection pooling related
  - `Http1` - HTTP/1.1 related
  - `Http2` - HTTP/2 related
- `Network` - IP/TCP/DNS/Socket layer, i.e. OSI L3/L4 related. Includes `Envoy Network Filter`, `Listener`, `Network::Address` and `Listener`.
  - `Network::Address` - IP address related

- `Server` - Envoy's implementation of the Daemon lifecycle as a service.
- `Stats` - monitoring metrics
- `Tcp` - TCP and connection pooling related
- `Upstream` - Upstream related load balancing, health checks, etc.
- ``



Most of these subsystems have their own functional `C++ Class/Interface`, such as `ReadFilter` for `Envoy Network Filter`, and their accompanying Callback interface definitions, such as `ReadFilterCallbacks`.





