This is a tool that helps you generate markdown from markdown. It's great when you're writing a presentation (for example, with [Deckset](http://www.decksetapp.com))

It works like this: all code in `swift` fenced code blocks is gathered and put into a swift file. Then, for each fenced code block with language `print-swift`, the last eval statement is evaluated at the end of the swift code.

For example, if you run `LiterateSwift` on this file:

```swift
let cities = ["London": 8308369
             ,"Berlin": 3387828	
             ,"Madrid": 3228319	
             ]
```

And then the following expression (if you're reading this on GitHub: please view the source)

```print-swift
sort(Array(cities.keys))
```

The above code-block will be replaced by:

```
sort(Array(cities.keys))

> [Berlin, London, Madrid]
```

If you want to highlight swift code, but not have it executed by literate swift, specify `highlight-swift` as your languge:

```swift
removeAllFiles()
```

If the `print-swift` code-block contains a single word, then that word isn't printed.

Also, there's an extra parameter `-swift` which will output only the swift code in fenced code blocks.

If your run this with `-stdin`, the contents is read from STDIN instead of a file.

### Weaving

When evaluating code, the Swift interpret currently cares about the order of the definitions. For example, the following code will not compile:


```swift
let greeting = hello("Chris")

func hello(x: String) -> String {
  return "Hello, " + x
}
```

Instead, we can let the code be weaved (letting LiterateSwift shuffle it around), and write our example like this:


```swift
// <<example1>>
let greeting = hello("Chris")

func hello(x: String) -> String {
  return "Hello, " + x
}
// =<<example1>>
```

Now, when evaluating the code, the entire first block will be cut out, and pasted at the place of `// =<example1>`. This allows you to present your code-blocks in a readable way, but still let the compiler verify that your code is working.

## Installation

Build the LiterateSwift target, and put it into your PATH. Additionally, there's a target 'CopyToBin' that copies the binary to `~/.bin`.
