# HTTP/1.1 Stream (draft)

The concept of Stream only exists in HTTP/2. However, for the sake of consistency in implementing program logic, Envoy has also encapsulated the concept of Steam in its implementation of HTTP/1.1. Just one HTTP/1.1 Request & Response process corresponds to one Stream.

> See: https://www.envoyproxy.io/docs/envoy/latest/faq/configuration/timeouts#stream-timeouts
> Stream timeouts apply to individual streams carried by an HTTP connection. Note that a stream is an HTTP/2 and HTTP/3 concept, however <mark>internally Envoy maps HTTP/1 requests to streams</mark> so in this context request/stream is interchangeable.

