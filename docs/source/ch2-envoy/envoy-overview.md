# Native Programmable Proxy `Envoy Proxy` Architecture

## A little history

```{note}
I'm not particularly fond of talking about the big picture, the big history, all that stuff that everyone knows all the time. But knowing a little bit of history can help us understand the causes of the current situation, and anticipate the consequences of the future.
```


Envoy is created by Matt Klein, who works at Lyft. It was designed to be as a proxy in a Service Mesh. In the early days of Envoy, Matt Klein himself worked very closely with the development team at Google's Istio. It can be said that Istio and Envoy have always been symbiotic relationship (although now Istio can use other agents instead of Envoy). That's why many people can't tell the difference between them.

### Why C++?

"Why implemented Envoy in C++?" This is probably one of the most popular questions asked by people who are new to Envoy. With the popularity of "safe"/"trendy" languages such as Rust/Go, there is a strong disincentive to use an old school, academic, insecure language.

Matt Klein's answer is that it was the best choice when Envoy started. As someone who used C++ more systematically 20 years ago, but has been drinking Java coffee for the last 20 years, I've skimmed through some of the Envoy code, and I think that the Envoy's use of C++11 is already very Java-like. The code is clear and easy to understand, unlike some masters, who write some magic code in an esoteric manner to discourage beginners. This is also a necessary quality for the success of open source projects.


## Envoy Proxy L1 architecture

`L1` is the highest level of architecture, and this is not the L1 of the OSI Model network hierarchy.  
Let's start with Matt Klein:

:::{figure-md} Envoy overall architecture

<img src="index.assets/envoy_arch_l1.png" alt="Envoy overall architecture">

*Figure: Envoy overall architecture  From: Envoy original author Matt Klein, Lyft's [Envoy Internals Deep Dive - Matt Klein, Lyft (Advanced Skill Level)]*
:::

This is an architectural diagram from several years ago, but it doesn't look like much has changed. I'm not going to describe this `Envoy Internals` architecture diagram here. I'd like to start with its surroundings.

```{warning}
Note that I do not intend to analyze the Istio control plane in complete isolation from the Envoy. That would be of limited relevance. If you talk about the Envoy in isolation from Istio, often times you won't understand why the Envoy is designed the way it is. But when we explain the design of the Envoy in the context of Istio's use of the Envoy, it becomes easier to understand why.
```