//
//  CMark.swift
//  SwiftCommonMarkTest
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/30.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on cmark.py
 https://github.com/commonmark/cmark/blob/master/test/cmark.py
 */

import Foundation

//TODO: not working
func pipe_through_prog(_ prog: String, _ args: [String], _ text: String) -> (Int, String, String) {
    let process = Process()
    process.launchPath = prog
    process.arguments = args
    let stdinForProg = Pipe()
    process.standardInput = stdinForProg
    let stdoutForProg = Pipe()
    process.standardOutput = stdoutForProg
    let stderrForProg = Pipe()
    process.standardError = stderrForProg
    var result = Data()
    var err = Data()
    
    NotificationCenter.default.addObserver(forName: .NSFileHandleReadToEndOfFileCompletion, object: stdoutForProg.fileHandleForReading, queue: OperationQueue.main) {notif in
        result.append(notif.userInfo![NSFileHandleNotificationDataItem] as! Data)
    }
    NotificationCenter.default.addObserver(forName: .NSFileHandleReadToEndOfFileCompletion, object: stderrForProg.fileHandleForReading, queue: OperationQueue.main) {notif in
        err.append(notif.userInfo![NSFileHandleNotificationDataItem] as! Data)
    }
    stdoutForProg.fileHandleForReading.readToEndOfFileInBackgroundAndNotify()
    stderrForProg.fileHandleForReading.readToEndOfFileInBackgroundAndNotify()
    process.launch()
    process.waitUntilExit()
    let returncode = Int(process.terminationStatus)
    return (returncode, String(data: result, encoding: .utf8) ?? "?", String(data: err, encoding: .utf8) ?? "?")
}

private func to_html(_ text: String, _ options: CmarkOptions) -> (Int, String, String) {
    let result = cmark_markdown_to_html(text, options)
    return (0, result, "")
}

private func to_commonmark(_ text: String, _ options: CmarkOptions) -> (Int, String, String) {
    let node = cmark_parse_document(text, options)
    let result = node.renderCommonmark(options, 0)
    return (0, result, "")
}

extension CmarkOptions {
    func commandLineOption(_ additionalOptions: String...) -> [String] {
        var options: [String] = []
        options += additionalOptions
        //TODO:
        return options
    }
}

class CMark {
    private var prog: String?
    private var options: CmarkOptions
    
    let toHtml: (String)->(Int, String, String)
    let toCommonmark: (String)->(Int, String, String)

    init(prog: String?, options: CmarkOptions = .default) {
        self.options = options
        self.prog = prog
        if let prog = prog {
            //TODO: not working
            self.toHtml = {x in pipe_through_prog(prog, options.commandLineOption(), x)}
            self.toCommonmark = {x in pipe_through_prog(prog, options.commandLineOption("-t","commonmark"), x)}
        } else {
            self.toHtml = {x in to_html(x, options)}
            self.toCommonmark = {x in to_commonmark(x, options)}
        }
    }
}
