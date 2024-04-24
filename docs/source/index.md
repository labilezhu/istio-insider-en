![Book Cover](./book-cover-mockup.jpg)

# Foreword

## Overview of this book

This book is called Istio & Envoy Insider. It is a book in progress, now in draft stage.

### What this book is about

This book includes: Envoy source code deep dive, in-depth Envoy fundamentals  analysis , Istio fundamentals analysis. But it's not a traditional "deep dive xyz source code" type of book. on the contrary, I have done my best not to directly paste source code in the book. Reading source code is a necessary step to grasp the details of the implementation, but browsing source code in a book is generally a very bad experience. So, this book uses source code navigation diagrams to let readers understand the full picture of the implementation, rather than getting lost in the details of fragmented source code snippets and forgetting the whole picture.

In this book, I've tried to think as systematically as possible from a design and implementation perspective:
- The design and implementation details of Envoy
- Why Istio is what it is
- The Truth Behind Those Magic Configurations: Linux + Envoy
  - How traffic is intercepted to the Envoy using Linux's netfilter technology.
  - How istiod programs the Envoy to fulfill the traffic policies of the Service Mesh.
- What Istio might look like in the future


The book is just a collection of thoughts and notes after I've been researching and using Istio for a while. I've just been troubleshooting some Istio/Envoy related functionality and performance issues, and browsing and debugging some Istio/Envoy code.

While diving into Istio. I found that there is a lot of valuable information on the Internet. However, either it is mainly from the user's point of view, but does not talk about the implementation mechanism; or it does talk about the mechanism, but the content lacks systematization and consistency.

### What this book is not

This book is not a user's manual. It does not teach how to learn Istio from a user's point of view, it does not preach how powerful Istio is, and it does not teach how to use Istio, there are too many excellent books, articles, and documents on this topic.

> 🤷 : [Yet, another](https://en.wikipedia.org/wiki/Yet_another) Istio User Guide?  
> 🙅 : No!



### Target Audience

This book focuses on the design and implementation mechanism of Istio/Envoy. It is assumed that the reader already has some experience in using Istio and is interested in further studying its implementation mechanism.

### Book access address
- [https://istio-insider.mygraphql.com](https://istio-insider.mygraphql.com/en)
- [https://istio-insider.readthedocs.io](https://istio-insider.readthedocs.io/en)
- [https://istio-insider.rtfd.io](https://istio-insider.rtfd.io/en)


### About the Author
My name is Mark Zhu, a middle-aged programmer with little hair. I'm not an Istio expert, not even an Istio Committer, not even an employee of a major Internet company.

Why do I learn from others and write a book when my level is limited? Because of this sentence:
> You don't need to be great to get started, but you do need to get started to be great.



In order to facilitate readers to follow the book's updates:
- Blog(English, RSS subscription supported): [https://blog.mygraphql.com/en/](https://blog.mygraphql.com/en/)  
- Medium: [Mark Zhu](https://mark-zhu.medium.com/)
- Blog(Chinese): [https://blog.mygraphql.com/](https://blog.mygraphql.com/)  
- WeChat public number: Mark's full of paper sugar cube words

:::{figure-md} WeChat subscription: Mark的滿紙方糖言

<img src="_static/my-wechat-blog-qr.png" alt="my-wechat-blog-qr.png">

*WeChat: Mark的滿紙方糖言*.
:::




### Participate in writing
If you are also interested in writing this book, feel free to contact me.


#### Thanks to the fellow who suggested the Issue 🌻
- [tanjunchen](https://github.com/tanjunchen): lots of very good comments on the reading experience and typography.

### Dedication 💞
First, to my dear parents, for showing me how to live a happy
and productive life. To my dear wife and our amazing kid - thanks for all your love and patience.

### Copyleft Disclaimer
If you reproduce or modify any text or image, please give credit to the original source.

### Feedback
As this is an open source interactive book, feedback from readers is of course very important. If you find a mistake in the book, or have a better suggestion, you may want to submit an Issue:
[https://github.com/labilezhu/istio-insider/issues](https://github.com/labilezhu/istio-insider/issues)



## Chinese version

There is a Chinese version: [中文版](https://istio-insider.mygraphql.com/zh-cn/latest) .


![](wechat-reward-qrcode.jpg)


## Catalog


```{toctree}
:caption: Catalog
:maxdepth: 5
:includehidden: 

ch0/index
ch1-istio-arch/index
ch2-envoy/index
performance/performance.md
disruptions/disruptions.md
observability/observability.md
troubleshooting/troubleshooting.md
dev-istio/dev-istio.md
```

## Appendix

```{toctree}
:caption: Appendix
:maxdepth: 5
:includehidden: 

appendix-lab-env/index.md
```

