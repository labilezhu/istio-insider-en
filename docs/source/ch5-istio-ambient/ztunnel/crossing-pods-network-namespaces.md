# Deep dive into Istio Ambient implement cross pods hub by network namespace trick

The so-called `Sidecarless` of Istio Ambient is, strictly speaking, a change from a `sidecar container of pod` to a `sidecar pod of pods on a worker node`. Note that I'm introducing the term `sidecar pod` here. To implement pods on the same worker node share a sidecar pod, you need to solve the problem of redirecting traffic from all pods to the sidecar pod.



The solution to this problem has gone through two versions during the development of Istio Ambient.
1. redirecting pod traffic to the `sidecar pod` via the worker node
2. have the `sidecar pod` "join" each pod's network namespace, and redirect traffic to the `sidecar pod` within the network namespace (pod traffic does not need to be routed through a worker node).



The Istio Ambient project team has explained the reason for this change in Istio Ambient at a relatively high level:


[Maturing Istio Ambient: Compatibility Across Various Kubernetes Providers and CNIs - By Ben Leggett - Solo.io, Yuval Kohavi - Solo.io, Lin Sun - Solo.io](https://istio.io/latest/blog/2024/inpod-traffic-redirection-ambient/)



The official Istio Ambient documentation also describes the latest implementation:

- [Istio’s in-pod traffic redirection model](https://istio.io/latest/docs/ambient/architecture/traffic-redirection/)


In this article, I try to deep dive into the implementation of the traffic environment setup process and the related background technologies from the low level. To record my curiosity. I also hope to satisfy the curiosity of a small number of readers.



## kernel fundamentals

The section "kernel fundamentals" has a lot of background on TL;DR, which I found to be a bit of a brain fart when I wrote this article. If you just want to know the results, skip straight to the " Istio Ambient's Curiosities" section.

### network namespace basics


From [Few notes about network namespaces in Linux](https://sgros.blogspot.com/2016/02/few-notes-about-network-namespaces-in.html) :

> ##### Kernel API for NETNS
>
> Kernel offers two system calls that allow management of network namespaces. 
>
> - The first one is for creating a new network namespace, [unshare(2)](http://linux.die.net/man/2/unshare). The first approach is for the process that created new network namespace to fork other processes and each forked process would share and inherit the parent's process network namespace. The same is true if exec is used.
>
> 
>
> - The second system call kernel offers is [setns(int fd, int nstype)](http://man7.org/linux/man-pages/man2/setns.2.html). To use this system call you have to have a `file descriptor` that is somehow related to the network namespace you want to use. There are two approaches how to obtain the file descriptor.
>
>   The first approach is to know the process that lives currently in the required network namespace. Let's say that the PID of the given process is $PID. So, to obtain file descriptor you should **open** the file `/proc/$PID/ns/net` file and that's it, pass file descriptor to `setns(2)` system call to switch network namespace. This approach always works.
>
>   Also, to note is that network namespace is per-thread setting, meaning if you set certain network namespace in one thread, this won't have any impact on other threads in the process.
>
>   Notice: from the documentation of [setns(int fd, int nstype)](http://man7.org/linux/man-pages/man2/setns.2.html):
>
>   > The setns() system call allows the calling **thread** to move into different namespaces
>
>   Note that it is **thead**, not the entire process. This is very, very important!
>
>   The second approach works only for iproute2 compatible tools. Namely, `ip` command when creating new network namespace creates a file in /var/run/netns directory and bind mounts new network namespace to this file. So, if you know a name of network namespace you want to access (let's say the name is NAME), to obtain file descriptor you just need to open(2) related file, i.e. /var/run/netns/NAME.
>
>   Note that there is no system call that would allow you to remove some existing network namespace. Each network namespace exists as long as there is at least one process that uses it, or there is a mount point.
>
>   Having said so much above, the key point I want to quote in this article is that [setns(int fd, int nstype)](http://man7.org/linux/man-pages/man2/setns.2.html) can switch the `current network namespace of the thread` for the calling thread 。
>
>   #### Socket API behavior
>
> First, **each socket handle you create is bound to whatever network namespace was active at the time the socket was created**. That means that you can set one network namespace to be active (say NS1) create socket and then immediately set another network namespace to be active (NS2). The socket created is bound to NS1 no matter which network namespace is active and socket can be used normally. In other words, when doing some operation with the socket (let's say bind, connect, anything) you don't need to activate socket's own network namespace before that!
>



Having said so much above, the main point I want to quote in those articles is that a socket actually binding to a network namespace. This binding occurs when the socket is created, and it is not changed by the current network namespace of the creator thread.

If you don’t know much about network namespace, you can take a look at:

- [A deep dive into Linux namespaces, part 4](https://ifeanyi.co/posts/linux-namespaces-part-4/)

- [Unprivileged Linux Network Namespaces, Part 1](https://blog.0x1b.me/posts/unprivileged-linux-netns-pt1/)

- [Deep dive into Linux network namespace - kernel source code level](https://hustcat.github.io/deep-dive-into-net-namespace/)



### Use Unix Domain Sockets to transfer File Descriptor between processes

Use Unix Domain Sockets to transfer File Descriptor between processes:[File Descriptor Transfer over Unix Domain Sockets](https://copyconstruct.medium.com/file-descriptor-transfer-over-unix-domain-sockets-dcbbf5b3b6ec)



New method for new kernel (5.6 and above): [Seamless file descriptor transfer between processes with pidfd and pidfd_getfd](https://copyconstruct.medium.com/seamless-file-descriptor-transfer-between-processes-with-pidfd-and-pidfd-getfd-816afcd19ed4)

Some references:

- [pidfd_open(2) — Linux manual page](https://man7.org/linux/man-pages/man2/pidfd_open.2.html)

- [pidfd_getfd(2) — Linux manual page](https://man7.org/linux/man-pages/man2/pidfd_getfd.2.html)

- [Grabbing file descriptors with pidfd_getfd()](https://lwn.net/Articles/808997/)



## Network namespace magic of Istio Ambient

Finally, about the trick way Istio Ambient puts it all together.

[Ztunnel Lifecyle On Kubernetes](https://github.com/istio/istio/blob/master/architecture/ambient/ztunnel-cni-lifecycle.md) describe the high level design:



> ![ztunnel-cni-lifecycle.png](crossing-pods-network-namespaces.assets/ztunnel-cni-lifecycle.png)

> The CNI Plugin is a binary installed as a [CNI plugin](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/) on the node. The container runtime is responsible for invoking this when a Pod is being started (before the containers run). When this occurs, the plugin will call out to the CNI Agent to program the network. This includes setting up networking rules within both the pod network namespace and the host network. For more information on the rules, see the [CNI README](https://github.com/istio/istio/blob/master/cni/README.md). This is done by an HTTP server running on `/var/run/istio-cni/pluginevent.sock`.
>
> An alternative flow is when a pod is enrolled into ambient mode after it starts up. In this case, the CNI Agent is watching for Pod events from the API server directly and performing the same setup. Note this is done while the Pod is running, unlike the CNI plugin flow which occurs before the Pod starts.
>
> Once the network is configured, the CNI Agent will signal to Ztunnel to start running within the Pod. This is done by the [ZDS](https://github.com/istio/istio/blob/master/pkg/zdsapi/zds.proto) API. This will send some identifying information about the Pod to Ztunnel, and, importantly, the **Pod's network namespace file descriptor.**
>
> **Ztunnel will use this to enter the Pod network namespace and start various listeners (inbound, outbound, etc).**
>
> Note:
>
> **While Ztunnel runs as a single shared binary on the node, each individual pod gets its own unique set of listeners within its own network namespace.**





:::{figure-md} Figure: Istio CNI and Istio ztunnel sync pod network namespace high level

<img src="crossing-pods-network-namespaces.assets/istio-cni-ztunnel-high-level.drawio.svg" alt="Figure: Istio CNI and Istio ztunnel sync pod network namespace high level">

*Figure: Istio CNI and Istio ztunnel sync pod network namespace high level*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fistio-cni-ztunnel-high-level.drawio.svg)*



The diagram already contains a lot of information. I won’t write much comment. :)

Here are some implementation details:

:::{figure-md} Figure: Istio CNI and Istio ztunnel sync pod network namespace

<img src="crossing-pods-network-namespaces.assets/ztunnel-inpod-net-ns-hub.drawio.svg" alt="Figure: Istio CNI and Istio ztunnel sync pod network namespace">

*Figure: Istio CNI and Istio ztunnel sync pod network namespace*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fztunnel-inpod-net-ns-hub.drawio.svg)*




The diagram already contains a lot of information. I won’t write much comment. :)



## Encapsulation in ztunnel



[InpodNetns::run(...)](https://github.com/istio/ztunnel/blob/d80323823cfd3afb3304c642682684c6752dda2d/src/inpod/netns.rs#L78)

```rust
//src/inpod/netns.rs

pub struct NetnsID {
    pub inode: libc::ino_t,
    pub dev: libc::dev_t,
}

struct NetnsInner {
    cur_netns: Arc<OwnedFd>,
    netns: OwnedFd,
    netns_id: NetnsID,
}

pub struct InpodNetns {
    inner: Arc<NetnsInner>,
}

impl InpodNetns {
    pub fn run<F, T>(&self, f: F) -> std::io::Result<T>
    where
        F: FnOnce() -> T,
    {
        setns(&self.inner.netns, CloneFlags::CLONE_NEWNET)
            .map_err(|e| std::io::Error::from_raw_os_error(e as i32))?;
        let ret = f();
        setns(&self.inner.cur_netns, CloneFlags::CLONE_NEWNET).expect("this must never fail");
        Ok(ret)
    }
```

[InPodSocketFactory::run_in_ns(...)](https://github.com/istio/ztunnel/blob/d80323823cfd3afb3304c642682684c6752dda2d/src/inpod/config.rs#L68-L69)

```rust
//src/inpod/config.rs

pub struct DefaultSocketFactory;

impl SocketFactory for DefaultSocketFactory {
    fn new_tcp_v4(&self) -> std::io::Result<TcpSocket> {
        TcpSocket::new_v4().and_then(|s| {
            s.set_nodelay(true)?;
            Ok(s)
        })
    }
}

impl InPodSocketFactory {

    fn run_in_ns<S, F: FnOnce() -> std::io::Result<S>>(&self, f: F) -> std::io::Result<S> {
        self.netns.run(f)?
    }

    fn configure<S: std::os::unix::io::AsFd, F: FnOnce() -> std::io::Result<S>>(
        &self,
        f: F,
    ) -> std::io::Result<S> {
        let socket = self.netns.run(f)??;

        if let Some(mark) = self.mark {
            crate::socket::set_mark(&socket, mark.into())?;
        }
        Ok(socket)
    }   
    ...
}


impl crate::proxy::SocketFactory for InPodSocketFactory {
    fn new_tcp_v4(&self) -> std::io::Result<tokio::net::TcpSocket> {
        self.configure(|| DefaultSocketFactory.new_tcp_v4())
    }

    fn tcp_bind(&self, addr: std::net::SocketAddr) -> std::io::Result<socket::Listener> {
        let std_sock = self.configure(|| std::net::TcpListener::bind(addr))?;
        std_sock.set_nonblocking(true)?;
        tokio::net::TcpListener::from_std(std_sock).map(socket::Listener::new)
    }
}
```



Reference:

- [std::net::TcpListener::bind(addr) docume](https://doc.rust-lang.org/std/net/struct.TcpListener.html#method.bind)



[Inbound](https://github.com/istio/ztunnel/blob/d80323823cfd3afb3304c642682684c6752dda2d/src/proxy/inbound.rs#L62)

```rust
//src/proxy/inbound.rs

impl Inbound {
    pub(super) async fn new(pi: Arc<ProxyInputs>, drain: DrainWatcher) -> Result<Inbound, Error> {
        let listener = pi
            .socket_factory
            .tcp_bind(pi.cfg.inbound_addr)
            .map_err(|e| Error::Bind(pi.cfg.inbound_addr, e))?;
        let enable_orig_src = super::maybe_set_transparent(&pi, &listener)?;
```

[InPodConfig](https://github.com/istio/ztunnel/blob/d80323823cfd3afb3304c642682684c6752dda2d/src/inpod/config.rs#L39)

```rust
//src/inpod/config.rs

impl InPodConfig {
    pub fn new(cfg: &config::Config) -> std::io::Result<Self> {
        Ok(InPodConfig {
            cur_netns: Arc::new(InpodNetns::current()?),
            mark: std::num::NonZeroU32::new(cfg.packet_mark.expect("in pod requires packet mark")),
            reuse_port: cfg.inpod_port_reuse,
        })
    }
    pub fn socket_factory(
        &self,
        netns: InpodNetns,
    ) -> Box<dyn crate::proxy::SocketFactory + Send + Sync> {
        let sf = InPodSocketFactory::from_cfg(self, netns);
        if self.reuse_port {
            Box::new(InPodSocketPortReuseFactory::new(sf))
        } else {
            Box::new(sf)
        }
    }
```



If you are curious about what listeners ztunnel has, you can see: [ztunnel Architecture](https://github.com/istio/ztunnel/blob/master/ARCHITECTURE.md)



## Istio CNI

[ztunnelserver.go](https://github.com/istio/istio/blob/afdad15000541f1a4c82f58918868511553e1a87/cni/pkg/nodeagent/#L460)

```go
func (z *ZtunnelConnection) sendDataAndWaitForAck(data []byte, fd *int) (*zdsapi.WorkloadResponse, error) {
	var rights []byte
	if fd != nil {
		rights = unix.UnixRights(*fd)
	}
	err := z.u.SetWriteDeadline(time.Now().Add(readWriteDeadline))
	if err != nil {
		return nil, err
	}

	_, _, err = z.u.WriteMsgUnix(data, rights, nil)
	if err != nil {
		return nil, err
	}

	// wait for ack
	return z.readMessage(readWriteDeadline)
}
```



See:

- [Istio CNI Node Agent](https://github.com/istio/istio/blob/master/cni/README.md)
- [Source code analysis: What happens behind the scenes when K8s creates pods (V) (2021)](https://arthurchiao.art/blog/what-happens-when-k8s-creates-pods-5-zh/)
- [Experiments with container networking: Part 1](https://logingood.github.io/kubernetes/cni/2016/05/14/netns-and-cni.html)



## End words

Is it over engineering? I don’t have an answer to this question. The so-called over engineering is mostly an evaluation after the fact. If you succeed and the software has a great influence, it is called “it is a feature not a bug”. Otherwise, it is called “it is a bug not a feature”.



> Overengineering (or over-engineering) is **the act of designing a product or providing a solution to a problem that is complicated in a way that provides no value or could have been designed to be simpler**.
>
> -- [Overengineering - Wikipedia](https://en.wikipedia.org/wiki/Overengineering#:~:text=Overengineering (or over-engineering),been designed to be simpler.)



## Reference

- [Testing a Kubernetes Networking Implementation Without Kubernetes - howardjohn's blog](https://blog.howardjohn.info/posts/ztunnel-testing/)
- [Istio Ambient is not a "Node Proxy" - howardjohn's blog](https://blog.howardjohn.info/posts/ambient-not-node-proxy/)
- [NSocker the namespaced socket server](https://github.com/rkapl/nsocker)



