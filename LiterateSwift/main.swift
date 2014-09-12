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
let standardLibrary = findArgument("stdlib")

func readFile(filename : String) -> String {
    return String.stringWithContentsOfFile(filename, encoding: NSUTF8StringEncoding, error: nil)!
}

let contents : String = {
    if (useStdIn) {
        let input = NSFileHandle.fileHandleWithStandardInput()
        let data: NSData = input.readDataToEndOfFile()
        return NSString(data:data, encoding:NSUTF8StringEncoding)
    } else {
        let filename = arguments[0]
        return readFile(filename)
    }
}()

let allPieces = arguments.flatMap { filename in
    parseContents(readFile(filename))
}
let allNamedCode = fromList(catMaybes(catMaybes(allPieces.map(code)).map(pieceName)))
let parsed: [Piece] = parseContents(contents)

if swift {
  let swiftCode = "\n".join(codeForLanguage("swift", pieces: weave(parsed)))
  println(swiftCode)
} else if (prepareForPlayground) {
  let result = prettyPrintContents(playgroundPieces(weave(parsed, allNamedCode)))
  let stripped = stripHTML ? stripHTMLComments(result) : result
  println(stripped)
} else if (standardLibrary) {
  println(prettyPrintContents(weave(parsed,allNamedCode)))
} else {
  let cwd = NSFileManager.defaultManager().currentDirectoryPath
  let result = prettyPrintContents(evaluate(parsed, workingDirectory: cwd))
  let stripped = stripHTML ? stripHTMLComments(result) : result
  println(stripped)
}