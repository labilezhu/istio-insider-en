# Overview of Istio and Envoy metrics

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
