# Istio and Envoy Metrics


```{toctree}
:hidden:
:maxdepth: 3
envoy-stat.md
istio-stat.md
envoy-stat-impl.md
metrics-req-resp-flow-timeline.md
```

Metrics monitoring is probably the most important aspect of DevOps monitoring. But it can also be the hardest. You can find Grafana monitoring dashboards for all sorts of systems and middleware on the web, and most of them are beautifully designed to make it feel like the monitoring is already perfect.  

But I don't know if you've had the same experience as me: having a bunch of metrics and monitoring dashboards at hand when your system is experiencing a problem.
- But you don't know which metrics are relevant to the problem.
- Or, the problem is already oriented in a certain direction, only to realize that there are no recorded metrics in that direction.

After all, people have to solve things, and more data, if:
- Do not understand the meaning behind the data
- Do not take the initiative to analyze their own application scenarios and deployment environment what data is needed, just what the system defaults to what to use!

Then the more metrics, the more people get lost in the sea of metrics.

As a mix of back-end jianghu for many years old Cheng (old programmer), there are always a lot of things do not understand, but it is difficult to say. One of them is the meaning of some specific metrics. Let's take two examples.
1. I previously used a tool called `nstat` to locate a network problem under Linux. It outputs a lot of metrics, but many people found that there were no documentation for some metrics. This is also a problem that open source software has always had. It changes quickly, the documentation cannot keep up, and it may even be wrong or out of date and has not been updated.
2. I used a tool called `ss` to locate a TCP connection problem under Linux, it outputs a god metric that search engines can't do anything to explain. In the end, I had to look at the original code. Luckily, I recorded my findings in Blog: ["Probably the most complete description of the TCP connection health metrics tool, ss"](https://blog.mygraphql.com/zh/notes/low-tec/network/tcp-inspect/), so I hope there will be some references for those who come after me.


With that out of the way, let's get back to Istio and Envoy, the main characters in this book. Their metrics documentation is a bit better than that of the older open source software. At least each metric has a line of text, although the text is very short and vague.

## Overview of Istio and Envoy metrics

Istio's istio-proxy data plane metrics are based on the architecture of Envoy metrics. So, I will start with Envoy's metrics architecture.


```{hint}
If you're like me, you're a hothead. Then the image below is Istio & Envoy's metrics map. It illustrates where the metrics are generated. Later content will derive this map step by step.
```

:::{figure-md} Figure: Envoy@Istio metrics

<img src="/ch2-envoy/envoy-istio-metrics/index.assets/envoy-istio-metrics.drawio.svg" alt="Figure - Envoy@Istio metrics">

*Figure: Envoy@Istio metrics*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fenvoy-istio-metrics.drawio.svg)*



:::{figure-md}
:class: full-width

<img src="/ch2-envoy/req-resp-flow-timeline/req-resp-flow-timeline.assets/req-resp-flow-timeline.drawio.svg" alt="Figure - Metrics on the Envoy Request and Response Timeline">

*Figure: Metrics on the Envoy Request and Response Timeline*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Freq-resp-flow-timeline.drawio.svg)*


