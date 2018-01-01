//
//  main.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/16.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on main.c
 https://github.com/commonmark/cmark/blob/master/src/main.c
 */

import Foundation

enum WriterFormat {
    case none
    case html
    case xml
    case man
    case commonmark
    case latex
}

func printUsage() {
    print("""
    Usage:   cmark [FILE*]
    Options:
      --to, -t FORMAT  Specify output format (html, xml, man, commonmark, latex)
      --width WIDTH    Specify wrap width (default 0 = nowrap)
      --sourcepos      Include source position attribute
      --hardbreaks     Treat newlines as hard line breaks
      --nobreaks       Render soft line breaks as spaces
      --safe           Suppress raw HTML and dangerous URLs
      --smart          Use smart punctuation
      --validate-utf8  Replace UTF-8 invalid sequences with U+FFFD
      --help, -h       Print usage information
      --version        Print version
    """)
}

private func printDocument(_ document: CmarkNode, _ writer: WriterFormat,
    _ options: CmarkOptions, _ width: Int) {
    var result: String

    switch writer {
    case .html:
        result = document.renderHtml(options)
    case .xml:
        result = document.renderXml(options)
    case .man:
        result = document.renderMan(options, width)
    case .commonmark:
        result = document.renderCommonmark(options, width)
    case .latex:
        result = document.renderLatex(options, width)
    default:
        print("Unknown format \(writer)", to: &stderr)
        exit(1)
    }
    print(result)
}

private let argv = CommandLine.arguments
private let argc = argv.count
private var files: [Int] = []
private let bufferSize = 4096
private var width: Int = 0
private var writer: WriterFormat = .html
private var options: CmarkOptions = .default

private var i: Int = 1
while i < argc {
    switch argv[i] {
    case "--version":
        print("cmark \(CMARK_VERSION_STRING)")
        print(" - CommonMark converter\n(C) 2014-2016 John MacFarlane")
        exit(0)
    case "--sourcepos":
        options.formUnion(.sourcepos)
    case "--hardbreaks":
        options.formUnion(.hardbreaks)
    case "--nobreaks":
        options.formUnion(.nobreaks)
    case "--smart":
        options.formUnion(.smart)
    case "--safe":
        options.formUnion(.safe)
    case "--validate-utf8":
        options.formUnion(.validateUTF8)
    case "--help", "-h":
        printUsage()
        exit(0)
    case "--width":
        i += 1
        if i < argc {
            if let w = Int(argv[i]) {
                width = w
            } else {
                print("failed parsing width '\(argv[i])'", to: &stderr)
                exit(1)
            }
        } else {
            print("--width requires an argument", to: &stderr)
            exit(1)
        }
    case "-t", "--to":
        i += 1
        if i < argc {
            switch argv[i] {
            case "man":
                writer = .man
            case "html":
                writer = .html
            case "xml":
                writer = .xml
            case "commonmark":
                writer = .commonmark
            case "latex":
                writer = .latex
            default:
                print("Unknown format \(argv[i])", to: &stderr)
                exit(1)
            }
        } else {
            print("No argument provided for \(argv[i - 1])", to: &stderr)
            exit(1)
        }
    case let arg where arg.starts(with: "-"):
        printUsage()
        exit(1)
    default: // treat as file argument
        files.append(i)
    }
    i += 1
}

private let parser = CmarkParser(options: options)
for file in files {
    guard let fp = FileHandle(forReadingAtPath: argv[file]) else {
        print("Error opening file \(argv[file])", to: &stderr)
        exit(1)
    }
    defer {fp.closeFile()}

    while true {
        let buffer = fp.readData(ofLength: bufferSize)
        parser.feed(buffer)
        if buffer.count < bufferSize {
            break
        }
    }

}

if files.count == 0 {

    while true {
        let buffer = FileHandle.standardInput.readData(ofLength: bufferSize)
        parser.feed(buffer)
        if buffer.count < bufferSize {
            break
        }
    }
}

private let document = parser.finish()
parser.free()

printDocument(document, writer, options, width)

document.free()

exit(0)

