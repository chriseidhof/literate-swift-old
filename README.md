This is a tool that helps you generate markdown from markdown.

It works like this: all code in `swift` fenced code blocks is gathered and put into a swift file. Then, for each fenced code block with language `print-swift`, the last eval statement is evaluated at the end of the swift code.

For example, if you run `LiterateSwift` on this file:

```swift
let cities = ["London": 8308369
             ,"Berlin": 3387828	
             ,"Madrid": 3228319	
             ]
```

And then the following expression

```print-swift
sort(Array(cities.keys))
```

The above code-block will be replaced by:

```
sort(Array(cities.keys))

> [Berlin, London, Madrid]
```

If the `print-swift` code-block contains a single word, then that word isn't printed.

Also, there's an extra parameter `-swift` which will output only the swift code in fenced code blocks.
