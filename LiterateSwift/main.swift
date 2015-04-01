//
//  main.swift
//  LiterateSwift
//
//  Created by Chris Eidhof on 21.06.14.
//  Copyright (c) 2014 Unsigned Integer. All rights reserved.
//

import Foundation

var arguments = Process.arguments

let programName = arguments.removeAtIndex(0)

if arguments.count < 1 {
    println("Expected a .md file as input, or -stdin as flag")
    exit(-1)
}

let argRegEx = NSRegularExpression(pattern: "^-(.+?)(?:=(.+))?$", options: .CaseInsensitive, error: nil)!

func findArgument(name: String) -> (String, String)? {
    for arg in arguments {
        if let match = argRegEx.matchesInString(arg, options: NSMatchingOptions(), range: arg.range).first as? NSTextCheckingResult {
            let res: [String] = Array(1...2).map { idx in
                let range = match.rangeAtIndex(idx)
                if range.location != NSNotFound {
                    return (arg as NSString).substringWithRange(range)
                }
                return ""
            }
            if res[0] == name {
                arguments.removeAtIndex(find(arguments, arg)!)
                return (res[0], res[1])
            }
        }
    }
    return nil
}

func existsArgument(name: String) -> Bool {
    return findArgument(name) != nil
}

let swift = existsArgument("swift")
let useStdIn = existsArgument("stdin")
let stripHTML = existsArgument("stripComments")
let prepareForPlayground = existsArgument("playground")
let standardLibrary = existsArgument("stdlib")
let latexResults = existsArgument("latex")
let outputPath = findArgument("o")?.1

func readFile(filename : String) -> String {
    var error: NSError?
    let res = String(contentsOfFile: filename, encoding: NSUTF8StringEncoding, error: &error)!
    if let e = error { println(e) }
    return res
}

let contents : String = {
    if (useStdIn) {
        let input = NSFileHandle.fileHandleWithStandardInput()
        let data: NSData = input.readDataToEndOfFile()
        return NSString(data:data, encoding:NSUTF8StringEncoding)! as String
    } else {
        return readFile(arguments[0])
    }
}()

let startIndex = useStdIn ? 0 : 1 // TODO hack

let parsed: [Piece] = parseContents(contents)
let otherFiles = Array(arguments[startIndex..<arguments.count])


let otherPieces = otherFiles.flatMap { filename in
    parseContents(readFile(filename))
}
let allPieces = parsed + otherPieces

let allNamedCode = namedCode(allPieces)

let prettyPrintOptions: [PrettyPrintOption] = latexResults ? [.Latex] : prepareForPlayground ? [.Playground] : []

var res: String?
var ref: String?
if swift {
    res = "\n".join(codeForLanguage("swift", pieces: weave(parsed, allNamedCode)))
} else if (prepareForPlayground) {
    let (pieces, referencedCode) = extractReferencedCode(parsed, allNamedCode)
    let result = prettyPrintContents(playgroundPieces(pieces), prettyPrintOptions)
    res = stripHTML ? stripHTMLComments(result) : result
    ref = "\n\n".join(referencedCode.map { unlines($0) })
} else if (standardLibrary) {
    res = prettyPrintContents(weave(parsed,allNamedCode), prettyPrintOptions)
} else {
    assert(false, "Unsupported LiterateSwift mode")
}


func createPlayground(url: NSURL, content: String, lib: String?) {
    let fm = NSFileManager.defaultManager()
    fm.createDirectoryAtURL(url, withIntermediateDirectories: true, attributes: nil, error: nil)
    let sourcesDir = url.URLByAppendingPathComponent("Sources")
    fm.createDirectoryAtURL(sourcesDir, withIntermediateDirectories: true, attributes: nil, error: nil)
    content.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!.writeToURL(url.URLByAppendingPathComponent("contents.swift"), atomically: true)
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<playground version='5.0' target-platform='osx' auto-termination-delay='10' display-mode='rendered' />".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)?.writeToURL(url.URLByAppendingPathComponent("contents.xcplayground"), atomically: true)
    ref?.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)?.writeToURL(sourcesDir.URLByAppendingPathComponent("lib.swift"), atomically: true)
}


if let f = outputPath,
    url = NSURL(fileURLWithPath: f),
    res1 = res
{
    if prepareForPlayground {
        createPlayground(url, res1, ref)
    } else {
        let data = res1.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        data.writeToFile(f, atomically: true)
    }
} else if let r = res {
    println(r)
}





