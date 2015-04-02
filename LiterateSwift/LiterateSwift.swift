//
//  LiterateSwift.swift
//  LiterateSwift
//
//  Created by Chris Eidhof on 17.07.14.
//  Copyright (c) 2014 Unsigned Integer. All rights reserved.
//

import Foundation

struct CodeAttributes: Printable {
    let language: String
    let name: String?
    let remove: Bool?

    var description: String {
        return "Language: \(language), name: \(name), remove: \(remove)"
    }
}

enum Piece : Printable {
    case Text([String])
    case CodeBlock(CodeAttributes, [String])
    case Evaluated(String)

    var description : String {
        switch self {
        case .Text(let s): return "Text(\(s))"
        case .CodeBlock(let attr, let code): return "Code(\(attr), \(code))"
        case .Evaluated(let evaluated): return "Evaluated(\(evaluated))"
        }
    }
}

func isFencedCodeBlock(s: String) -> Bool { return s.hasPrefix("```") }

let weaveRegex = NSRegularExpression(pattern: "//\\s+<<(.*)(!?)>>", options: nil, error: nil)!

func codeName(lines: [String]) -> (name: String, remove: Bool, rest: [String])? {
    if let firstLine = lines.first,
        match = weaveRegex.firstMatchInString(firstLine, options: nil, range: firstLine.range)
    {
        let remove = match.rangeAtIndex(2).length > 0
        let range = match.rangeAtIndex(1)
        if range.length > 0 {
            let name = (firstLine as NSString).substringWithRange(range)
            let rest = Array(lines[1..<lines.count])
            return (name: name, remove: remove, rest: rest)
        }
    }
    return nil
}

func codeBlock(var lines: [String]) -> Piece? {
    if lines.count == 0 { return nil }
    let firstLine : NSString = lines.removeAtIndex(0)
    let language = firstLine.substringFromIndex(3)
    if let (name, remove, rest) = codeName(lines) {
        return Piece.CodeBlock(CodeAttributes(language: language, name: name, remove: remove), rest)
    } else {
        return Piece.CodeBlock(CodeAttributes(language: language, name: nil, remove: nil), lines)
    }
}

func parseContents(input: String) -> [Piece] {
    var lines = input.lines
    var result: [Piece] = []
    while(lines.count > 0) {
        result.append(Piece.Text(lines.removeUntil(isFencedCodeBlock)))
        if lines.count == 0 { break }
        let marker = lines.removeAtIndex(0) // code block marker
        if let code = codeBlock([marker] + lines.removeUntil(isFencedCodeBlock)) {
            result.append(code)
        }
        
        if lines.count > 0 {lines.removeAtIndex(0)} // The current fenced codeblock marker
    }
    return result
}

enum PrettyPrintOption : Equatable {
    case Latex
    case Playground
}

let internalLinksRegEx = NSRegularExpression(pattern: "\\[(.+)\\]\\(#.+\\)", options: .CaseInsensitive, error: nil)!
let playgroundSkipLines = ["<!--", "-->"]

func prettyPrintContents(pieces: [Piece], usedRefs: [String], options: [PrettyPrintOption]) -> String {
    let printLatex = contains(options, .Latex)
    let playground = contains(options, .Playground)
    var result = ""
    for piece in pieces {
        switch piece {
        case .Text(let s) where count(unlines(s)) > 0:
            if playground {
                result += unlines(catMaybes(s.map { line in
                    let trimmedLine = line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                    if contains(playgroundSkipLines, trimmedLine) {
                        return nil
                    }
                    let l = NSMutableString(string: line)
                    internalLinksRegEx.replaceMatchesInString(l, options: NSMatchingOptions(), range: line.range, withTemplate: "$1")
                    return "//: \(l)"
                }))
            } else {
                result += unlines(s)
            }
        case .CodeBlock(let attr, let contents) where count(unlines(contents)) > 0:
            if playground {
                if attr.language == "swift" {
                    if let name = attr.name where contains(usedRefs, name) {
                        result += unlines(["//:", unlines(contents.map { "//:    \($0)" }), "//:"])
                    } else {
                        result += unlines(["", unlines(contents), ""])
                    }
                } else if attr.language == "print-swift" {
                    let filteredCode = contents.filter {!$0.hasPrefix("let result___") }
                    result += unlines(filteredCode)
                } else {
                    result += unlines(["//:", unlines(contents.map { "//:    \($0)" }), "//:"])
                }
            } else {
                result += unlines(["","```\(attr.language)", unlines(contents), "```",""])
            }
        case .Evaluated(let contents):
            if printLatex {
                result += unlines(["\\begin{result}", contents, "\\end{result}"])
            } else {
                if playground {
                    result += unlines(["", contents, ""])
                } else {
                    result += unlines(["","```", contents, "```",""])
                }
            }
        default: ()
        }
        result += "\n"
    }
    return result
}

func codeForLanguage(lang: String, #pieces: [Piece]) -> [String] {
    return pieces.flatMap {
        switch $0 {
        case .CodeBlock(let attr, let code) where attr.language == lang: return code
        default: return [""]
        }
    }
}

func evaluateSwift(code: String, #expression: String, #workingDirectory: String) -> String {
    var expressionLines: [String] = expression.lines.filter { count($0) > 0 }
    let lastLine = expressionLines.removeLast()
    let shouldIncludeLet = expressionLines.filter { $0.hasPrefix("let result___ ") }.count == 0
    let resultIs = shouldIncludeLet ? "let result___ : Any = " : ""
    let contents = "\n".join([code, "", "\n".join(expressionLines), "", "\(resultIs) \(lastLine)", "println(\"\\(result___)\")"])
    
    let base = NSUUID().UUIDString
    let basename = base.stringByAppendingPathExtension("swift")
    let filename = "/tmp".stringByAppendingPathComponent(basename!)
    
    contents.writeToFile(filename)
    var arguments: [String] =  "--sdk macosx swiftc".words
    let objectName = base.stringByAppendingPathExtension("o")!
    ignoreOutputAndPrintStdErr(exec(commandPath:"/usr/bin/xcrun", workingDirectory:"/tmp", arguments:arguments + ["-c", filename]))
    ignoreOutputAndPrintStdErr(exec(commandPath: "/usr/bin/xcrun", workingDirectory: "/tmp", arguments: arguments + ["-o", "app", objectName]))
    let (stdout, stderr) = exec(commandPath: "/tmp/app", workingDirectory: workingDirectory, arguments: [workingDirectory])
    printstderr(stderr)
    return stdout
}

func ignoreOutputAndPrintStdErr(input: (output: String,stderr: String)) -> () {
    printstderr(input.stderr)
}

func code(piece: Piece) -> Piece? {
    switch piece {
    case .CodeBlock(_, let code): return piece
    default: return nil
    }
}

let expansionRegex = NSRegularExpression(pattern: "//\\s+=<<(.*)>>", options: nil, error: nil)!

func refs(code: [String]) -> [String] {
    let joinedCode = unlines(code)
    let matches = expansionRegex.matchesInString(joinedCode, options: nil, range: joinedCode.range) as! [NSTextCheckingResult]
    return matches.map { match in
        (joinedCode as NSString).substringWithRange(match.rangeAtIndex(1))
    }
}

infix operator  |> { associativity left }

func |> <A, B, C>(func1: B -> C, func2: A -> B) -> (A -> C) {
    return { func1(func2($0)) }
}

func codeName(piece: Piece) -> String? {
    switch piece {
    case .CodeBlock(let attr, _): return attr.name
    default: return nil
    }
}

func codeLines(piece: Piece) -> [String]? {
    switch piece {
    case .CodeBlock(_, let lines): return lines
    default: return nil
    }
}

func codeNameAndLines(piece: Piece) -> (name: String, lines: [String])? {
    if let name = codeName(piece), lines = codeLines(piece) { return (name, lines) }
    return nil
}

func namedCode(pieces: [Piece]) -> [String:[String]] {
    return fromList(catMaybes(catMaybes(pieces.map(code)).map(codeNameAndLines)))
}

func weave(pieces: [Piece]) -> [Piece] {
    return weave(pieces, namedCode(pieces))
}

//func stripNames(pieces: [Piece]) -> [Piece] {
//    return pieces.map { piece in
//        switch piece {
//        case .CodeBlock(let language, let code):
//            if let (name,rest) = pieceName(code) {
//                return .CodeBlock(language, rest)
//            }
//            return piece
//        default: return piece
//        }
//    }
//}

func refsInPieces(pieces: [Piece]) -> [String] {
    return flatMap(pieces, refsInPiece)
}

func refsInPiece(piece: Piece) -> [String] {
    switch piece {
    case .CodeBlock(_, let code): return refs(code)
    default: return []
    }
}

func weave(pieces: [Piece], dict: [String: [String]]) -> [Piece] {
    let usedNames = refsInPieces(pieces)
    return pieces.map { weave($0, usedNames, dict).0 }
}

func weave(piece: Piece, usedNames: [String], dict: [String: [String]]) -> Piece {
    switch piece {
    case .CodeBlock(let attr, let code) where attr.name == nil:
        var processedCode = code
        for (key, value) in dict {
            let s = unlines(processedCode)
            let keyString = "// =<<\(key)>>"
            if let r = s.rangeOfString(keyString, options: NSStringCompareOptions(), range: nil, locale: nil) {
                processedCode = s.stringByReplacingOccurrencesOfString(keyString, withString: unlines(value), options: nil, range: nil).lines
            }
        }
        return .CodeBlock(attr, processedCode)
    default:
        return piece
    }
}

func stripHTMLComments(input: String) -> String {
    // only remove comments with whitespace, otherwise it might be marked directives
    let regex = NSRegularExpression(pattern: "<!--(.*?)-->", options: NSRegularExpressionOptions.DotMatchesLineSeparators, error: nil)!
    //if regex { println("Error: \(error)") }
    let range = NSRange(0..<count(input))
    return regex.stringByReplacingMatchesInString(input, options: NSMatchingOptions(0), range: range, withTemplate: "")
}

func flatMap<A,B>(array: [A], f: A -> [B]) -> [B] {
    var result : [B] = []
    for x in array {
        result += f(x)
    }
    return result
}

func evaluate(parsed: [Piece], #workingDirectory: String) -> [Piece] {
    return flatMap(parsed) { (piece: Piece) in
        switch piece {
        case .CodeBlock(let attr, let code) where attr.language == "print-swift":
            let swiftCode = unlines(codeForLanguage("swift", pieces: weave(parsed, allNamedCode)))
            let result = evaluateSwift(swiftCode, expression: unlines(code), workingDirectory: workingDirectory)
            let filteredCode = code.filter {!$0.hasPrefix("let result___") }
            let words = unlines(code).words
            let shouldDisplayCode = words.count > 1 || contains(words[0],"(")
            let start = shouldDisplayCode ? [Piece.CodeBlock(CodeAttributes(language: "swift", name: attr.name, remove: attr.remove), filteredCode)] : []
            return start + [Piece.Evaluated(prefix(result,"> "))]
        case .CodeBlock(let attr, let code) where attr.language == "highlight-swift":
            return [Piece.CodeBlock(CodeAttributes(language: "swift", name: attr.name, remove: attr.remove), code)]
        default:
            return [piece]
        }
    }
}

