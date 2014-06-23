//
//  Library.swift
//  LiterateSwift
//
//  Created by Chris Eidhof on 21.06.14.
//  Copyright (c) 2014 Unsigned Integer. All rights reserved.
//

import Foundation

extension String {
    var lines: String[] {
    return self.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
    }
    
    var words: String[] {
      return self.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    }
    
    func writeToFile(destination: String) {
        writeToFile(destination, atomically: true, encoding: NSUTF8StringEncoding, error: nil)
    }
}

extension Array {
    mutating func removeUntil(f: T -> Bool) -> T[] {
        var removed: T[] = []
        for el in self {
            if f(el) {
                break
            } else {
                removed += el
            }
        }
        for i in 0..removed.count {
            //            println("removing \(i) in \(self)")
            removeAtIndex(0)
        }
        return removed
    }
}

func exec(#commandPath: String, #workingDirectory: String?, #arguments: String[]) -> String {
    let task = NSTask()
    task.currentDirectoryPath = workingDirectory
    task.launchPath = commandPath
    task.arguments = arguments
    task.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"]
    
    let stdout = NSPipe()
    task.standardOutput = stdout
    let stderr = NSPipe()
    task.standardError = stderr
    
    task.launch()
    
    func read(pipe: NSPipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return NSString(data: data, encoding: NSUTF8StringEncoding)
    }
    let stdoutoutput : String = read(stdout)
    let stderroutput : String = read(stderr)
    if countElements(stderroutput) > 0 {
//        println(<#object: T#>, &<#target: TargetStream#>)
//        println("stdout: \(stdoutoutput)")
        println("stderr: \(stderroutput)")
        
    }
    
    task.waitUntilExit()
    
    return stdoutoutput
}