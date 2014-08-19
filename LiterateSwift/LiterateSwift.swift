//
//  LiterateSwift.swift
//  LiterateSwift
//
//  Created by Chris Eidhof on 17.07.14.
//  Copyright (c) 2014 Unsigned Integer. All rights reserved.
//

import Foundation

enum Piece {
    case Text(String)
    case CodeBlock(String,String)
    case Evaluated(String)
}

func isFencedCodeBlock(s: String) -> Bool { return s.hasPrefix("```") }

func codeBlock(var lines: [String]) -> Piece? {
    if lines.count == 0 { return nil }
    let firstLine : NSString = lines.removeAtIndex(0)
    let language = firstLine.substringFromIndex(3)
    return Piece.CodeBlock(language, "\n".join(lines))
}

func parseContents(input: String) -> [Piece] {
    var lines = input.lines
    var result: [Piece] = []
    while(lines.count > 0) {
        result.append(Piece.Text("\n".join(lines.removeUntil(isFencedCodeBlock))))
        if lines.count == 0 { break }
        let marker = lines.removeAtIndex(0) // code block marker
        if let code = codeBlock([marker] + lines.removeUntil(isFencedCodeBlock)) {
            result.append(code)
        }
        
        if lines.count > 0 {lines.removeAtIndex(0)} // The current fenced codeblock marker
    }
    return result
}

func prettyPrintContents(pieces: [Piece]) -> String {
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

func codeForLanguage(lang: String, #pieces: [Piece]) -> [String] {
    return pieces.map {
        switch $0 {
        case .CodeBlock(let l, let code) where l == lang: return code
        default: return ""
        }
    }
}

func evaluateSwift(code: String, #expression: String, #workingDirectory: String) -> String {
    var expressionLines: [String] = expression.lines.filter { countElements($0) > 0 }
    let lastLine = expressionLines.removeLast()
    let shouldIncludeLet = expressionLines.filter { $0.hasPrefix("let result___ ") }.count == 0
    let resultIs = shouldIncludeLet ? "let result___ : Any = " : ""
    let contents = "\n".join([code, "", "\n".join(expressionLines), "", "\(resultIs) \(lastLine)", "println(\"\\(result___)\")"])
    
    let basename = NSUUID.UUID().UUIDString.stringByAppendingPathExtension("swift")
    let filename = "/tmp".stringByAppendingPathComponent(basename!)
    
    contents.writeToFile(filename)
    var arguments: [String] =  "--sdk macosx -r swift".words
    arguments.append(filename)
    arguments += ["--", workingDirectory]
    let (stdout, stderr) = exec(commandPath:"/usr/bin/xcrun", workingDirectory:filename.stringByDeletingLastPathComponent, arguments:arguments)
    printstderr(stderr)
    return stdout
}

let weaveRegex = NSRegularExpression(pattern: "//\\s+<<(.*)>>", options: nil, error: nil)
let expansionRegex = NSRegularExpression(pattern: "//\\s+=<<(.*)>>", options: nil, error: nil)

func pieceName(piece: String) -> (name: String, rest: String)? {
    let firstLine : String = piece.lines[0]
    let match = weaveRegex.firstMatchInString(firstLine, options: nil, range: firstLine.range)
    let range = match.rangeAtIndex(1)
    if range.length > 0 {
        let name = (firstLine as NSString).substringWithRange(range)
        let rest = piece.lines[1..<piece.lines.count]
        let contents = "\n".join(rest)
        return (name: name, rest: contents)
    }
    return nil
}

func code(piece: Piece) -> String? {
    switch piece {
    case .CodeBlock(_, let code): return code
    default: return nil
    }
}

func expansions(code: String) -> [String] {
    let nsStringCode : NSString = code
    let matches = expansionRegex.matchesInString(code, options: nil, range: code.range) as [NSTextCheckingResult]
    return matches.map { match in
        nsStringCode.substringWithRange(match.rangeAtIndex(1))
    }
}

infix operator  |> { associativity left }

func |> <A, B, C>(func1: B -> C, func2: A -> B) -> (A -> C) {
    return { func1(func2($0)) }
}

func weave(pieces: [Piece]) -> [Piece] {
    let name = { piece in
        flatMap(code(piece), pieceName)
    }
    let dict : [String:String] = fromList(catMaybes(pieces.map(name)))

    let usedNames : [String] = flatMap(pieces) { piece in
        switch piece {
        case .CodeBlock(_, let code):
            return expansions(code)
        default:
            return []
        }
    }
    let usedNamesDict = fromList(usedNames.map { ($0,1) })

    return pieces.map { piece in
        switch piece {
        case .CodeBlock(let language, let code):
            if let (name, rest) = pieceName(code) {
                if usedNamesDict[name] == nil {
                    return .CodeBlock(language, rest)
                } else {
                    return .CodeBlock(language, "")
                }
            } else {
                var result = code
                for (key,value) in dict {
                    result = result.stringByReplacingOccurrencesOfString("// =<<\(key)>>", withString: value, options: nil, range: nil)
                }
                return .CodeBlock(language, result)
            }
        default:
            return piece
        }
    }
}

func stripHTMLComments(input: String) -> String {
    // only remove comments with whitespace, otherwise it might be marked directives
    let regex = NSRegularExpression.regularExpressionWithPattern("<!--(.*?)-->", options: NSRegularExpressionOptions.DotMatchesLineSeparators, error: nil)!
    //if regex { println("Error: \(error)") }
    let range = NSRange(0..<countElements(input))
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
        case .CodeBlock("print-swift", let code):
            let result = evaluateSwift(swiftCode,expression: code,workingDirectory: workingDirectory)
            let filteredCode = unlines(code.lines.filter {!$0.hasPrefix("let result___") })
            let shouldDisplayCode = code.words.count > 1 || contains(code.words[0],"(")
            let start = shouldDisplayCode ? [Piece.CodeBlock("swift", filteredCode)] : []
            return start + [Piece.Evaluated(prefix(result,"> "))]
        case .CodeBlock("highlight-swift", let code):
            return [Piece.CodeBlock("swift", code)]
        case .CodeBlock("swift", let code):
            if let (name, code) = pieceName(code) {
                return [Piece.CodeBlock("swift", code)]
            } else {
                return [piece]
            }
        default:
            return [piece]
        }
    }
}

let playgroundPieces: [Piece] -> [Piece] = { parsed in
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
