//
//  main.swift
//  LiterateSwift
//
//  Created by Chris Eidhof on 21.06.14.
//  Copyright (c) 2014 Unsigned Integer. All rights reserved.
//

import Foundation

var arguments = Process.arguments

//let cwd =

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

let contents : String = {
    if (useStdIn) {
        let input = NSFileHandle.fileHandleWithStandardInput()!
        let data: NSData = input.readDataToEndOfFile()!
        return NSString(data:data, encoding:NSUTF8StringEncoding)
    } else {
        let filename = useStdIn ? "" : arguments[1]
        return String.stringWithContentsOfFile(filename, encoding: NSUTF8StringEncoding, error: nil)!
    }
}()

let parsed: [Piece] = parseContents(contents)
let swiftCode = "\n".join(weave(codeForLanguage("swift", pieces: parsed)))

if swift {
  println(swiftCode)
} else if (prepareForPlayground) {
  let result = prettyPrintContents(playgroundPieces(parsed))
  let stripped = stripHTML ? stripHTMLComments(result) : result
  println(stripped)
} else {
    let cwd = NSFileManager.defaultManager().currentDirectoryPath
  let result = prettyPrintContents(evaluate(parsed, workingDirectory: cwd))
  let stripped = stripHTML ? stripHTMLComments(result) : result
  println(stripped)
}