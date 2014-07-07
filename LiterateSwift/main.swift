//
//  main.swift
//  LiterateSwift
//
//  Created by Chris Eidhof on 21.06.14.
//  Copyright (c) 2014 Unsigned Integer. All rights reserved.
//

import Foundation

enum Piece {
    case Text(String)
    case CodeBlock(String,String)
    case Evaluated(String)
}

var arguments = Process.arguments

NSFileManager.defaultManager().currentDirectoryPath

if arguments.count < 2 {
    println("Expected a .md file as input")
    exit(-1)
    
}

func findArgument(name: String) -> Bool {
    if let idx = find(arguments, "-" + name) {
        arguments.removeAtIndex(idx)
        return true
    }
    return false
    
}

let swift = findArgument("swift")
let useStdIn = findArgument("stdin")
let stripHTML = findArgument("stripComments")
let prepareForPlayground = findArgument("playground")

let filename = useStdIn ? "" : arguments[1]


func isFencedCodeBlock(s: String) -> Bool { return s.hasPrefix("```") }

func codeBlock(var lines: String[]) -> Piece? {
    if lines.count == 0 { return nil }
    let language = lines.removeAtIndex(0).substringFromIndex(3)
    return Piece.CodeBlock(language, "\n".join(lines))
}

func parseContents(input: String) -> Piece[] {
    var lines = input.lines
    var result: Piece[] = []
    while(lines.count > 0) {
        result += Piece.Text("\n".join(lines.removeUntil(isFencedCodeBlock)))
        if lines.count == 0 { break }
        let marker = lines.removeAtIndex(0) // code block marker
        if let code = codeBlock([marker] + lines.removeUntil(isFencedCodeBlock)) {
            result += code
        }
        
        if lines.count > 0 {lines.removeAtIndex(0)} // The current fenced codeblock marker
    }
    return result
}

func prettyPrintContents(pieces: Piece[]) -> String {
    var result = ""
    for piece in pieces {
        switch piece {
        case .Text(let s): result += s
        case .CodeBlock(let lang, let contents):
            result += "\n".join(["","```\(lang)", contents, "```",""])
        case .Evaluated(let contents):
            result += "\n".join(["","```", contents, "```",""])
        }
    }
    return result
}

func codeForLanguage(lang: String, #pieces: Piece[]) -> String[] {
    return pieces.map {
        switch $0 {
        case .CodeBlock("swift", let code): return code
        default: return ""
        }
    }
}

func evaluateSwift(code: String, expression: String) -> String {
    var expressionLines: String[] = expression.lines.filter { countElements($0) > 0 }
    let lastLine = expressionLines.removeLast()
    let shouldIncludeLet = expressionLines.filter { $0.hasPrefix("let result___ ") }.count == 0
    let resultIs = shouldIncludeLet ? "let result___ : Any = " : ""
    let contents = "\n".join([code, "", "\n".join(expressionLines), "", "\(resultIs) \(lastLine)", "println(\"\\(result___)\")"])
    
    let basename = NSUUID.UUID().UUIDString.stringByAppendingPathExtension("swift")
    let filename = "/tmp".stringByAppendingPathComponent(basename)
    
    contents.writeToFile(filename)
    var arguments: String[] =  "--sdk macosx -r swift -i".words
    arguments += filename
    return exec(commandPath:"/usr/bin/xcrun", workingDirectory:filename.stringByDeletingLastPathComponent, arguments:arguments)
    
}

func unlines(lines: String[]) -> String { return "\n".join(lines) }

func prefix(s: String, prefix: String) -> String {
    return unlines(s.lines.filter { countElements($0) > 0 } .map { prefix + $0 })
}

let contents : String = {
    if (useStdIn) {
        let input = NSFileHandle.fileHandleWithStandardInput()!
        let data: NSData = input.readDataToEndOfFile()!
        return NSString(data:data, encoding:NSUTF8StringEncoding)
    }
    return String.stringWithContentsOfFile(filename, encoding: NSUTF8StringEncoding, error: nil)!
}()

contents.writeToFile("~/Desktop/out.md".stringByExpandingTildeInPath)

let parsed: Piece[] = parseContents(contents)
let swiftCode = "\n".join(codeForLanguage("swift", pieces: parsed))
let evaluate: () -> Piece[] = { parsed.map { (piece: Piece) in
    switch piece {
    case .CodeBlock("print-swift", let code):
        let result = evaluateSwift(swiftCode,code)
        let filteredCode = unlines(code.lines.filter {!$0.hasPrefix("let result___") })
        let shouldDisplayCode = code.words.count > 1 || contains(code.words[0],"(")
        let start = shouldDisplayCode ? filteredCode + "\n\n" : ""
        return Piece.Evaluated(start + prefix(result,"> "))
    case .CodeBlock("highlight-swift", let code):
        return Piece.CodeBlock("swift", code)
    default:
      return piece
    }
    }
}

let playgroundPieces: () -> Piece[] = {
    parsed.map { (piece: Piece) in
        switch piece {
        case .CodeBlock("print-swift", let code):
            let filteredCode = unlines(code.lines.filter {!$0.hasPrefix("let result___") })
            return Piece.CodeBlock("swift", filteredCode)
        case .CodeBlock("highlight-swift", let code):
            return Piece.CodeBlock("", code)
        default:
            return piece
        }
    }

}

func stripHTMLComments(input: String) -> String {
    // only remove comments with whitespace, otherwise it might be marked directives
    let regex = NSRegularExpression.regularExpressionWithPattern("<!--(.*?)-->", options: NSRegularExpressionOptions.DotMatchesLineSeparators, error: nil)
    //if regex { println("Error: \(error)") }
    let range = NSRange(0..countElements(input))
    return regex.stringByReplacingMatchesInString(input, options: NSMatchingOptions(0), range: range, withTemplate: "")
}

if swift {
  println(swiftCode)
} else if (prepareForPlayground) {
    let result = prettyPrintContents(playgroundPieces())
    let stripped = stripHTML ? stripHTMLComments(result) : result
    println(stripped)
    
} else {
  let result = prettyPrintContents(evaluate())
  let stripped = stripHTML ? stripHTMLComments(result) : result
  println(stripped)
}
