//
//  Shell.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 4/24/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation

struct Shell {
    enum ShellError: Error {
        case shellError(String)
    }
    
    @discardableResult
    static func command(_ command: String) throws -> String {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        
        let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
        if !error.isEmpty {
            let errorMessage = String(data: error, encoding: .utf8)!
            throw ShellError.shellError(errorMessage)
        }
        
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        return output
    }
}
