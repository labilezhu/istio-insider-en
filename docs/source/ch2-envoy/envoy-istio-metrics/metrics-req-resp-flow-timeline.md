# Metrics on Envoy request and response timing lines

:::{figure-md} Figure: Metrics on Envoy request and response timing lines
:class: full-width

<img src="/ch2-envoy/req-resp-flow-timeline/req-resp-flow-timeline.assets/req-resp-flow-timeline.drawio.svg" alt="Figure - Metrics on Envoy request and response timing lines">

*Figure: Metrics on Envoy request and response timing lines*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Freq-resp-flow-timeline.drawio.svg)*


A large portion of the Envoy's metrics are generated on top of its request and response processing timeline. Figure out this timeline, and you'll figure out the metrics. The section {doc}`/ch2-envoy/req-resp-flow-timeline/req-resp-flow-timeline` is dedicated to this timeline, and the metrics on it.