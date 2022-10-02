## Book overview

### What this book is not

This book is not a manual. Not from the user's point of view, teaching how to learn Istio in simple terms. It won't preach how powerful Istio is, let alone teach how to use Istio. There are already too many excellent books, articles, and documents on the Internet.

> 🤷 : [Yet, another](https://en.wikipedia.org/wiki/Yet_another) Istio User Guide?
> 🙅 : No!


### What is this book

In this book, I try to think systematically as much as possible from the perspective of design and implementation:
- Why is Istio the way it is?
- The truth behind those magic configs: Linux + Envoy
- What Istio might look like in the future


What the book says is just my thinking and recording after researching and using Istio for a period of time. I'm not an expert, much less an Istio Committer. Not even the employees of big Internet companies. I just checked some Istio/Envoy related functions and performance issues, browsed and debugged some Istio/Envoy codes.

In the process of researching Istio. There is a lot of valuable information on the Internet. However, either it is mainly based on the user, and the implementation mechanism is not mentioned; or the mechanism is said, and it is well said, but the content is less systematic and coherent.

### Reader object
This book mainly talks about the design and implementation mechanism of Istio/Envoy. It is assumed that the reader already has some experience with Istio.

### Book access address
- [https://istio-insider.mygraphql.com](https://istio-insider.mygraphql.com)
- [https://istio-insider.readthedocs.io](https://istio-insider.readthedocs.io)
- [https://istio-insider.rtfd.io](https://istio-insider.rtfd.io)


### About the author
My name is Mark Zhu, a middle-aged programmer with little hair.

Blog: [https://blog.mygraphql.com/](https://blog.mygraphql.com/)


### Important: style, style, interactive reading of this article 📖

#### Interactive Books

It can be said that most of my writing time is not spent writing, but drawing. Therefore, using a computer to read the pictures is the correct way to open this book. Mobile phones are just a conspiracy to drain traffic.
Most of the diagrams here are more complex, not PPT big pie charts. Therefore, it is basically not suitable for printing out paper books. But I'll let the graph interact with the reader:

- Original drawings, mostly SVG images made with Draw.io: `*.drawio.svg`.

For complex diagrams, it is recommended to `open with draw.io`:
- Some images provide a `Open with draw.io` link, which can be viewed in a more interactive way in the browser:
  - Where there is (underlined text), links to related documentation and lines of code.
  - Put the mouse on it and a `hover` window will pop up, prompting more information. Such as configuration file content.

If you don't like draw.io then just look at SVG:
- The correct posture to browse SVG images is to right-click on the image in the browser and select `Open Image in New Tab`. Large SVG image, middle mouse button pressed, free scroll/drag.
- SVG images can click the link to directly jump to the corresponding source page (or related documents), sometimes accurate to the source line.

#### language style
As this article is not intended for print publication. Nor is it official documentation. So language-wise I am colloquial. If the reader's expectation is to read a very serious book, they may be disappointed. But not serious does not mean not rigorous.

### Involved in the preparation
If you are also interested in writing this book, please contact me. The starting point of this book is not to brush a resume, nor does it have this ability. Moreover, such non-`short and fast` and `TL;DR` books are destined to be a niche product.


### Dedication 💞
First, to my dear parents, for showing me how to live a happy
and productive life. To my dear wife and our amazing kid – thanks for all your love and patience.


### Copyleft Statement
Whether it is text or pictures, if reproduced or modified, please indicate the original source.