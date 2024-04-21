---
typora-root-url: ../../..
---

# Flow Control - Flow Control
As with all http proxy software, Envoy takes flow control very seriously. Because CPU/memory resources are limited, it is also important to avoid situations where a single flow can take up too much resources. It is important to note that, as with any software implemented in an asynchronous/threaded multiplexed architecture, flow control is never a simple task.

If someone asked me what was the hardest part of learning the Envoy implementation? My answer must be the flow control part. And there is very little information about it on the web. Or there are readers ask, so difficult, why study, this study has any value? In my opinion, this study has at least the following values:

1. Envoy as an important part of the business traffic must pass through, can not be wrong. Its memory usage should be understood when we do service resource evaluation, so that we can evaluate it scientifically.
2. Understanding the behavior of Envoy and service degradation when traffic is overrun can be a good precaution.
3. because flow control involves all participants in the data flow path, the process of research itself is the process of understanding the relationship of Envoy flow components.


It should be notice that the "flow control" in this section does not mean that we generally do microservice APIs, control API TPS to prevent the service from crashing in the high-frequency API calls to protect the service from such overload. It's more of a `backpressure` based protection to prevent a single connection/http2 stream from using too much memory buffer when the Envoy is processing a data stream such as request body/response body.


Envoy has an [Envoy Flow Control document](https://github.com/envoyproxy/envoy/blob/main/source/docs/flow_control.md) that describes some of these details. In this section, I document the results of some of my study research based on this, but also added a lot of my interpretation.


Traffic control in Envoy is accomplished by limiting each Buffer with `watermark callbacks`. When a Buffer contains more data than the configured limit, a `high watermark callback` is triggered, which triggers a series of events that eventually **notify the data source to stop sending data**. This suppression may be immediate (e.g., stopping reads from sockets) or gradual (e.g., stopping HTTP/2 window updates), so all Buffer limits in the Envoy are considered `soft limits`. 

When the Buffer is finally processed (`drains`) (usually halfway to the high water mark to avoid jittering back and forth), a low water mark callback is triggered to notify the sender that it can resume sending data.


The following is a simple TCP implementation detailing the flow control process, followed by a more complex HTTP2 flow control process.


## Some flow control terms

- `back up` - A situation in which data is congested in one or more intermediate buffers due to slow or poor traffic flow to the destination, resulting in the buffer running out of space.
- `buffers fill up` - the cache space reaches the upper limit.
- `backpressure` - Stream backpressure is a feedback mechanism that allows the system to respond to requests rather than crashing under load when processing capacity is exceeded. This occurs when the rate of incoming data exceeds the rate of processing or outputting data, leading to congestion and potential data loss. For more details, see:[Backpressure explained - the resisted flow of data through software](https://medium.com/@jayphelps/backpressure-explained-the-flow-of-data-through-software-2350b3e77ce7)
- `drained` - The emptying of a Buffer. Generally refers to the processing and draining of a buffer from above the low watermark, down to below the low watermark after consumption, or even empty.
- `HTTP/2 window` - The HTTP/2 standard implementation of flow control that indicates, via the `WINDOW_UPDATE` frame, the number of octets the sender may transmit in addition to the existing flow control window. See "[Hypertext Transfer Protocol Version 2 (HTTP/2) - 5.2. Flow Control](https://httpwg.org/specs/rfc7540.html#FlowControl) for details. "
- `http stream` - The HTTP/2 standard for streams. For details, see "[Hypertext Transfer Protocol Version 2 (HTTP/2) - 5. Streams and Multiplexing](https://httpwg.org/specs/rfc7540.html#StreamsLayer)"
- High/Low Watermark - High and low watermark design patterns for controlling memory or buffer consumption but not wanting to trigger control operations with frequent high-frequency jitter, see "[What are high and low water marks in bit streaming](https://stackoverflow.com/questions/45489405/what-are-high-and-low-water-marks-in-bit-streaming)" for details.



## TCP flow control implementation
Flow control for TCP and `TLS endpoints` is handled through the coordination between the `Network::ConnectionImpl` Write Buffer and the `Network::TcpProxy` Filter.

The flow control for `Downstream` is as follows.
- Downstream `Network::ConnectionImpl::write_buffer_` buffers too much data. It calls `Network::ConnectionCallbacks::onAboveWriteBufferHighWatermark()`.
- `Network::TcpProxy::DownstreamCallbacks` receives `onAboveWriteBufferHighWatermark()` and calls `readDisable(true)` on the Upstream connection.
- When the Downstream is finished processing (`drained`), it calls `Network::ConnectionCallbacks::onBelowWriteBufferLowWatermark()` on the Upstream connection.
- `Network::TcpProxy::DownstreamCallbacks` receives `onBelowWriteBufferLowWatermark()` and calls `readDisable(false)` on the Upstream connection.
The flow control for `Upstream` is roughly the same.
- Upstream `Network::ConnectionImpl::write_buffer_` buffers too much data. It calls `Network::ConnectionCallbacks::onAboveWriteBufferHighWatermark()`.
- `Network::TcpProxy::UpstreamCallbacks` receives `onAboveWriteBufferHighWatermark()` and calls `readDisable(true)` on the Downstream connection.
- When the Upstream has finished processing (`drained`), it calls `Network::ConnectionCallbacks::onBelowWriteBufferLowWatermark()` on the Downstream connection.
- `Network::TcpProxy::UpstreamCallbacks` receives `onBelowWriteBufferLowWatermark()` and calls `readDisable(false)` on Downstream connections.


The subsystem and Callback mechanism can be found in this book in the section: {ref}`ch2-envoy/arch/oop/oop:Callback design pattern`.



## HTTP2 Flow Control Implementation
Because the various Buffers in the HTTP/2 technology stack are quite cumbersome, each segment of the path from Buffer exceeding the `Watermark` limit to pausing data from the data source is described in a separate Envoy document.


```{note}
Readers who don't know much about Envoy's http-connection-manager and http filter chain are advised to read the following section of this book: {doc}`/ch2-envoy/arch/http/http-connection-manager/http-connection-manager` section. The following assumes that the reader already knows this.
```


### HTTP2 flow control general flow




#### Simplest Upstream connection congestion scenario


> For HTTP/2, when filters, streams, or connections back up, the end result is `readDisable(true)` being called on the source stream. This results in the stream ceasing to consume window, and so not sending further flow control window updates to the peer. This will result in the peer eventually stopping sending data when the available window is consumed (or nghttp2 closing the connection if the peer violates the flow control limit) and so limiting the amount of data Envoy will buffer for each stream. 


:::{figure-md} Figure Upstream connection back up and backpressure

<img src="/ch2-envoy/arch/flow-control/flow-control-1-upstream-backs-up-simple.drawio.svg" alt="Figure: Upstream connection back up and backpressure">

*Figure: Upstream connection back up and backpressure*
:::
*[Open with Draw.io 4](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fflow-control-1-upstream-backs-up-simple.drawio.svg)*




:::{figure-md} Upstream connection 拥塞与背压

<img src="/ch2-envoy/arch/flow-control/flow-control-1-upstream-backs-up-simple.drawio.svg" alt="Upstream connection 拥塞与背压">

*Upstream connection 拥塞与背压*
:::
*[用 Draw.io 打开](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fflow-control-1-upstream-backs-up-simple.drawio.svg)*





The `Unbounded buffer` above does not mean that the buffer does not have a limit, it means that the limit is a `soft limit`.


#### Upstream connection and Upstream http stream back-up at the same time


> When `readDisable(false)` is called, any outstanding unconsumed data is immediately consumed, which results in resuming window updates to the peer and the resumption of data.


```c++
void ConnectionImpl::StreamImpl::readDisable(bool disable) {
  ENVOY_CONN_LOG(debug, "Stream {} {}, unconsumed_bytes {} read_disable_count {}",
                 parent_.connection_, stream_id_, (disable ? "disabled" : "enabled"),
                 unconsumed_bytes_, read_disable_count_);
  if (disable) {
    ++read_disable_count_;
  } else {
    ASSERT(read_disable_count_ > 0);
    --read_disable_count_;
    if (!buffersOverrun()) {
      scheduleProcessingOfBufferedData(false);
      if (shouldAllowPeerAdditionalStreamWindow()) {
        grantPeerAdditionalStreamWindow();
      }
    }
  }
}
```

> Note that `readDisable(true)` on a stream may be called by multiple entities. It is called when any filter buffers too much, when the stream backs up and has too much data buffered, or the connection has too much data buffered. Because of this, `readDisable()` maintains a count of the number of times it has been called to both enable and disable the stream, resuming reads when each caller has called the equivalent low watermark callback. 

> For example, if the TCP window upstream fills up and results in the network buffer backing up, all the streams associated with that connection will `readDisable(true)` their downstream data sources. 
>
> When the HTTP/2 flow control window fills up an individual stream may use all of the window available and call a second `readDisable(true)` on its downstream data source. 
>
> When the upstream TCP socket drains, the connection will go below its low watermark and each stream will call `readDisable(false)` to resume the flow of data. The stream which had both a network level block and a H2 flow control block will still not be fully enabled. 
>
> Once the upstream peer sends window updates, the stream buffer will drain and the second `readDisable(false)` will be called on the downstream data source, which will finally result in data flowing from downstream again.


Example:
1. if the upstream TCP Write Buffer window fills and causes the network buffer to be full, all `streams` associated with that `connection` will `readDisable(true)` their Downsteam data source.
2. At the same time, if the HTTP/2 flow control window fills up, a single stream may use all available windows and call a second `readDisable(true)` on its Downstream datasource. 
3. Then, as the Upstream TCP Write Buffer continues to send and drain (drains), the `connection` will fall below its low water mark and each stream will call `readDisable(false)` to resume the data flow. However, a `stream` with both network-level hangs and H2 flow control-level hangs will still not be fully enabled. 
4. Once the Upstream peer sends the HTTP2 window update, the `stream` buffer will empty and the Downstream data source will call a second `readDisable(false)`, which will eventually cause the data to flow out of the Downstream again.



:::{figure-md} Figure: Upstream connection and Upstream http stream back-up at the same time

<img src="/ch2-envoy/arch/flow-control/flow-control-2-upstream-backs-up-counter.drawio.svg" alt="Figure: Upstream connection and Upstream http stream back-up at the same time">

*Figure: Upstream connection and Upstream http stream back-up at the same time*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fflow-control-2-upstream-backs-up-counter.drawio.svg)*

#### Collaboration of Router::Filter during Upstream back-up


> The two main parties involved in flow control are the router filter (`Envoy::Router::Filter`) and the connection manager (`Envoy::Http::ConnectionManagerImpl`). The router is responsible for intercepting watermark events for its own buffers, the individual upstream streams (if codec buffers fill up) and the upstream connection (if the network buffer fills up). It passes any events to the connection manager, which has the ability to call `readDisable()` to enable and disable further data from downstream. 


:::{figure-md} Figure: Collaboration of Router::Filter during Upstream back-up

<img src="/ch2-envoy/arch/flow-control/flow-control-3-upstream-backs-up-router.drawio.svg" alt="Figure: Collaboration of Router::Filter during Upstream back-up">

*Figure: Collaboration of Router::Filter during Upstream back-up*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fflow-control-3-upstream-backs-up-router.drawio.svg)*

#### Collaboration of Http::ConnectionManagerImpl when Downstream back-up



> On the reverse path, when the downstream connection backs up, the connection manager collects events for the downstream streams and the downstream connection. It passes events to the router filter via `Envoy::Http::DownstreamWatermarkCallbacks` and the router can then call `readDisable()` on the upstream stream. Filters opt into subscribing to `DownstreamWatermarkCallbacks` as a performance optimization to avoid each watermark event on a downstream HTTP/2 connection resulting in "number of streams * number of filters" callbacks. Instead, only the router filter is notified and only the "number of streams" multiplier applies. Because the router filter only subscribes to notifications when it has an upstream connection, the connection manager tracks how many outstanding high watermark events have occurred and passes any on to the router filter when it subscribes.

:::{figure-md} Figure: Collaboration of Http::ConnectionManagerImpl when Downstream back-up

<img src="/ch2-envoy/arch/flow-control/flow-control-4-downstream-conn-backs-up.drawio.svg" alt="Figure: Collaboration of Http::ConnectionManagerImpl when Downstream back-up">

*Figure: Collaboration of Http::ConnectionManagerImpl when Downstream back-up*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fflow-control-4-downstream-conn-backs-up.drawio.svg)*



### HTTP decode/encode filter flow control detail

> Each HTTP and HTTP/2 filter has an opportunity to call `decoderBufferLimit()` or `encoderBufferLimit()` on creation. No filter should buffer more than the configured bytes without calling the appropriate watermark callbacks or sending an error response.
>
> Filters may override the default limit with calls to `setDecoderBufferLimit()` and `setEncoderBufferLimit()`. These limits are applied as filters are created so filters later in the chain can override the limits set by prior filters. It is recommended that filters calling these functions should generally only perform increases to the buffer limit, to avoid potentially conflicting with the buffer requirements of other filters in the chain.
>
> Most filters do not buffer internally, but instead push back on data by returning a FilterDataStatus on `encodeData()`/`decodeData()` calls. If a buffer is a streaming buffer, i.e. the buffered data will resolve over time, it should return `FilterDataStatus::StopIterationAndWatermark` to pause further data processing, which will cause the `ConnectionManagerImpl` to trigger watermark callbacks on behalf of the filter. If a filter can not make forward progress without the complete body, it should return `FilterDataStatus::StopIterationAndBuffer`. In this case if the `ConnectionManagerImpl` buffers more than the allowed data it will return an error downstream: a 413 on the request path, 500 or `resetStream()` on the response path.


#### Decoder filters

> For filters which do their own internal buffering, filters buffering more than the buffer limit should call `onDecoderFilterAboveWriteBufferHighWatermark` if they are streaming filters, i.e. filters which can process more bytes as the underlying buffer is drained. This causes the downstream stream to be readDisabled and the flow of downstream data to be halted. The filter is then responsible for calling `onDecoderFilterBelowWriteBufferLowWatermark` when the buffer is drained to resume the flow of data.
>
> Decoder filters which must buffer the full response should respond with a 413 (Payload Too Large) when encountering a response body too large to buffer.
>
> The decoder high watermark path for streaming filters is as follows:
>
> - When an instance of `Envoy::Router::StreamDecoderFilter` buffers too much data it should call `StreamDecoderFilterCallback::onDecoderFilterAboveWriteBufferHighWatermark()`.
> - When `Envoy::Http::ConnectionManagerImpl::ActiveStreamDecoderFilter` receives `onDecoderFilterAboveWriteBufferHighWatermark()` it calls `readDisable(true)` on the downstream stream to pause data.
>
> And the low watermark path:
>
> - When the buffer of the `Envoy::Router::StreamDecoderFilter` drains should call `StreamDecoderFilterCallback::onDecoderFilterBelowWriteBufferLowWatermark()`.
> - When `Envoy::Http::ConnectionManagerImpl` receives `onDecoderFilterAboveWriteBufferHighWatermark()` it calls `readDisable(false)` on the downstream stream to resume data.


#### Encoder filters

> Encoder filters buffering more than the buffer limit should call `onEncoderFilterAboveWriteBufferHighWatermark` if they are streaming filters, i.e. filters which can process more bytes as the underlying buffer is drained. The high watermark call will be passed from the `Envoy::Http::ConnectionManagerImpl` to the `Envoy::Router::Filter` which will `readDisable(true)` to stop the flow of upstream data. Streaming filters which call `onEncoderFilterAboveWriteBufferHighWatermark` should call `onEncoderFilterBelowWriteBufferLowWatermark` when the underlying buffer drains.
>
> Filters which must buffer a full request body before processing further, should respond with a 500 (Server Error) if encountering a request body which is larger than the buffer limits.
>
> The encoder high watermark path for streaming filters is as follows:
>
> - When an instance of `Envoy::Router::StreamEncoderFilter` buffers too much data it should call `StreamEncoderFilterCallback::onEncodeFilterAboveWriteBufferHighWatermark()`.
> - When `Envoy::Http::ConnectionManagerImpl::ActiveStreamEncoderFilter` receives `onEncoderFilterAboveWriteBufferHighWatermark()` it calls `ConnectionManagerImpl::ActiveStream::callHighWatermarkCallbacks()`
> - `callHighWatermarkCallbacks()` then in turn calls `DownstreamWatermarkCallbacks::onAboveWriteBufferHighWatermark()` for all filters which registered to receive watermark events
> - `Envoy::Router::Filter` receives `onAboveWriteBufferHighWatermark()` and calls `readDisable(true)` on the upstream request.
>
> The encoder low watermark path for streaming filters is as follows:
>
> - When an instance of `Envoy::Router::StreamEncoderFilter` buffers drains it should call `StreamEncoderFilterCallback::onEncodeFilterBelowWriteBufferLowWatermark()`.
> - When `Envoy::Http::ConnectionManagerImpl::ActiveStreamEncoderFilter` receives `onEncoderFilterBelowWriteBufferLowWatermark()` it calls `ConnectionManagerImpl::ActiveStream::callLowWatermarkCallbacks()`
> - `callLowWatermarkCallbacks()` then in turn calls `DownstreamWatermarkCallbacks::onBelowWriteBufferLowWatermark()` for all filters which registered to receive watermark events
> - `Envoy::Router::Filter` receives `onBelowWriteBufferLowWatermark()` and calls `readDisable(false)` on the upstream request.


### HTTP and HTTP/2 codec upstream send buffer

Below I am using [the original document](https://github.com/envoyproxy/envoy/blob/main/source/docs/flow_control.md) directly. However, I have included diagrams that I have drawn to make it easier to understand.


The upstream send buffer `Envoy::Http::Http2::ConnectionImpl::StreamImpl::pending_send_data_` is H2 stream data destined for an Envoy backend. Data is added to this buffer after each filter in the chain is done processing, and it backs up if there is insufficient connection or stream window to send the data. The high watermark path goes as follows:

- When `pending_send_data_` has too much data it calls `ConnectionImpl::StreamImpl::pendingSendBufferHighWatermark()`.
- `pendingSendBufferHighWatermark()` calls `StreamCallbackHelper::runHighWatermarkCallbacks()`
- `runHighWatermarkCallbacks()` results in all subscribers of `Envoy::Http::StreamCallbacks` receiving an `onAboveWriteBufferHighWatermark()` callback.
- When `Envoy::Router::Filter` receives `onAboveWriteBufferHighWatermark()` it calls `StreamDecoderFilterCallback::onDecoderFilterAboveWriteBufferHighWatermark()`.
- When `Envoy::Http::ConnectionManagerImpl` receives `onDecoderFilterAboveWriteBufferHighWatermark()` it calls `readDisable(true)` on the downstream stream to pause data.

For the low watermark path:

- When `pending_send_data_` drains it calls `ConnectionImpl::StreamImpl::pendingSendBufferLowWatermark()`
- `pendingSendBufferLowWatermark()` calls `StreamCallbackHelper::runLowWatermarkCallbacks()`
- `runLowWatermarkCallbacks()` results in all subscribers of `Envoy::Http::StreamCallbacks` receiving a `onBelowWriteBufferLowWatermark()` callback.
- When `Envoy::Router::Filter` receives `onBelowWriteBufferLowWatermark()` it calls `StreamDecoderFilterCallback::onDecoderFilterBelowWriteBufferLowWatermark()`.
- When `Envoy::Http::ConnectionManagerImpl` receives `onDecoderFilterBelowWriteBufferLowWatermark()` it calls `readDisable(false)` on the downstream stream to resume data.


:::{figure-md} Figure: Collaboration of Router::Filter during Upstream back-up(2)

<img src="/ch2-envoy/arch/flow-control/flow-control-3-upstream-backs-up-router.drawio.svg" alt="Figure: Collaboration of Router::Filter during Upstream back-up">

*Figure: Collaboration of Router::Filter during Upstream back-up*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fflow-control-3-upstream-backs-up-router.drawio.svg)*


### HTTP and HTTP/2 network upstream network buffer

Below I am using [the original document](https://github.com/envoyproxy/envoy/blob/main/source/docs/flow_control.md) directly. However, I have included diagrams that I have drawn to make it easier to understand. **go further, I found a bug in [the original document](https://github.com/envoyproxy/envoy/blob/main/source/docs/flow_control.md) that should be fixed.**



The upstream network buffer is HTTP/2 data for all streams destined for the Envoy backend. If the network buffer fills up, all streams associated with the underlying TCP connection will be informed of the back-up, and the data sources (HTTP/2 streams or HTTP connections) feeding into those streams will be readDisabled.

The high watermark path is as follows:

- When `Envoy::Network::ConnectionImpl::write_buffer_` has too much data it calls `Network::ConnectionCallbacks::onAboveWriteBufferHighWatermark()`.
- When `Envoy::Http::CodecClient` receives `onAboveWriteBufferHighWatermark()` it calls `onUnderlyingConnectionAboveWriteBufferHighWatermark()` on `codec_`.
- When `Http::Http2::ConnectionImpl`*(the original document use `Envoy::Http::ConnectionManagerImpl` incorrectly)* receives `onAboveWriteBufferHighWatermark()` it calls `runHighWatermarkCallbacks()` for each stream of the connection.
- `runHighWatermarkCallbacks()` results in all subscribers of `Envoy::Http::StreamCallback` receiving an `onAboveWriteBufferHighWatermark()` callback.
- When `Envoy::Router::Filter` receives `onAboveWriteBufferHighWatermark()` it calls `StreamDecoderFilterCallback::onDecoderFilterAboveWriteBufferHighWatermark()`.
- When `Envoy::Http::ConnectionManagerImpl` receives `onDecoderFilterAboveWriteBufferHighWatermark()` it calls `readDisable(true)` on the downstream stream to pause data.

The low watermark path is as follows:

- When `Envoy::Network::ConnectionImpl::write_buffer_` is drained it calls `Network::ConnectionCallbacks::onBelowWriteBufferLowWatermark()`.
- When `Envoy::Http::CodecClient` receives `onBelowWriteBufferLowWatermark()` it calls `onUnderlyingConnectionBelowWriteBufferLowWatermark()` on `codec_`.
- When `Envoy::Http::ConnectionManagerImpl` receives `onBelowWriteBufferLowWatermark()` it calls `runLowWatermarkCallbacks()` for each stream of the connection.
- `runLowWatermarkCallbacks()` results in all subscribers of `Envoy::Http::StreamCallback` receiving a `onBelowWriteBufferLowWatermark()` callback.
- When `Envoy::Router::Filter` receives `onBelowWriteBufferLowWatermark()` it calls `StreamDecoderFilterCallback::onDecoderFilterBelowWriteBufferLowWatermark()`.
- When `Envoy::Http::ConnectionManagerImpl` receives `onDecoderFilterBelowWriteBufferLowWatermark()` it calls `readDisable(false)` on the downstream stream to resume data.

As with the downstream network buffer, it is important that as new upstream streams are associated with an existing upstream connection over its buffer limits that the new streams are created in the correct state. To handle this, the `Envoy::Http::Http2::ClientConnectionImpl` tracks the state of the underlying `Network::Connection` in `underlying_connection_above_watermark_`. If a new stream is created when the connection is above the high watermark the new stream has `runHighWatermarkCallbacks()` called on it immediately.



:::{figure-md} Figure: Collaboration of Router::Filter when Upstream connection back-up

<img src="/ch2-envoy/arch/flow-control/flow-control-3-2-upstream-conn-backs-up-router.drawio.svg" alt="Figure: Collaboration of Router::Filter when Upstream connection back-up">

*Figure: Collaboration of Router::Filter when Upstream connection back-up*
:::
*[Open with Draw.io](https://app.diagrams.net/?ui=sketch#Uhttps%3A%2F%2Fistio-insider.mygraphql.com%2Fzh_CN%2Flatest%2F_images%2Fflow-control-3-2-upstream-conn-backs-up-router.drawio.svg)*






## Ref.

> - [Flow control](https://github.com/envoyproxy/envoy/blob/main/source/docs/flow_control.md)
> - [Envoy buffer management & flow control](https://docs.google.com/document/d/1EB3ybx3yTndp158c4AdQ4nutksZA9lL-BQvixhPnb_4/edit?usp=sharing)