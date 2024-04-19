# Reading interactive book

## Interactive Book

Humanity has evolved to the point where I think it's time for books to expand their definition. As technical knowledge becomes more complex, interactive, electronic presentations may be better suited for in-depth learning of complex technical knowledge. When getting started, one prefers abstraction and simplification, and when going deeper, one prefers to make sense of internal connections.

This is not a "deep dive into xyz source code" type of book. I can even say that I did my best not to post the source code directly in the book. Looking at the source code is a necessary step to grasp the details of the implementation, but navigating through the source code in a book is generally a very poor experience. Instead, a navigation chart of the source code is probably more helpful.

I spend most of my writing time not on words, but on diagrams. So using a PC to read the diagrams is the right way to open the book.
Most of the diagrams here are complex, not like PPT charts. So, basically, they are not suitable for printing out a paper book either. But I will let the diagrams interactive with the reader:

- For original diagrams, most are SVG images made with Draw.io: `*.drawio.svg`.

For complex diagrams, it is recommended to `open with draw.io`:
- Some images provide links to `open with draw.io` for a more interactive browser view: `*.drawio.svg`.
  - In some places (underlined text), links to related documentation and lines of code.
  - In some place(💡 icon on diagrams), When your mouse over, a `hover` window pops up with more information. For example, the contents of a configuration file.

If you don't like draw.io, then look at SVG.
- The proper way to view an SVG image is to right-click on the image in your browser and select `Open Image in New Tab`. For large SVG images, press the middle mouse button and scroll/drag freely.
- SVG images can be clicked on a link to go directly to the corresponding source page (or related documentation), sometimes down to the source line.
- SVGs sometimes have layout problems, especially with embedded snippets in the image, which can only be opened with drawio.

```{hint}
 - For big dragram is recommended to opened with Draw.io The diagram contains a lot of links to the documentation for each component, configuration item, and metric. Sometimes it links to the github code line.
 - Dual screens, one for the diagrams and one for the documentation, is the correct reading position for this book. If you're reading it on your phone, then, ignore me 🤦
```

## Language style
As this article is not intended for print publication. Nor is it an official document of any kind. So language wise I am colloquial. If the reader's expectation is to read a very serious book, they may be disappointed. But not being serious doesn't mean it's not rigorous.  
Because this is the first book I've written, I don't have much experience. I didn't have anyone to proofread and errata with, so if there are any mistakes, readers can raise a Github Issue.


## Drawing styles

The diagrams used in the software engineering industry, such as architecture diagrams, flowcharts, and so on, can be categorized into two styles:
- Neat, beautiful and neat, even pay attention to aesthetics and color and other factors; and limit the complexity of each diagram, can be abstract, do not go deeper. This style is more often seen in PPT and paper books.
- Engineer's diagrams, everything is not detailed, only when the complexity is really more than the maximum human can understand in a plane, then the abstraction. This type of diagram is usually of limited regularity and is more of an engineer's culture. This style is more commonly found in technical electronic documentation.

This book uses both styles of diagrams. However, the latter is more commonly used.



Translated with DeepL.com (free version)