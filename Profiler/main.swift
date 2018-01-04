//
//  main.swift
//  Profiler
//
//  Created by OOPer in cooperation with shlab.jp, on 2018/1/4.
//  Copyright © 2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//

import Foundation

let pathodologicalTestName: [String: String] = [
    "nested-emph": "nested strong emph",
    "emph-no-opener": "many emph closers with no openers",
    "emph-no-closer": "many emph openers with no closers",
    "link-no-opener": "many link closers with no openers",
    "link-no-closer": "many link openers with no closers",
    "mismatched": "mismatched openers and closers",
    "multiple3": "openers and closers multiple of 3",
    "link-emph": "link openers and emph closers",
    "hard-link-emph": "hard link/emph case",
    "nested-brackets": "nested brackets",
    "nested-block-quites": "nested block quotes",
    "u-0000-input": "U+0000 in input",
    "backticks": "backticks",
    "unclosed-a": "unclosed links A",
    "unclosed-b": "unclosed links B",
    "many-references": "many references",
]

func testPathological(name: String?) {
    //### Some test cases take minitues to hours in the current implementation, better avoid...
    let pt = PathologicalTests(verbose: true, name: name)
    _ = pt.run()
}

if CommandLine.arguments.count >= 3 && CommandLine.arguments[1] == "-p",
    CommandLine.arguments[2] == "all"
{
    testPathological(name: nil)
} else if CommandLine.arguments.count >= 3 && CommandLine.arguments[1] == "-p",
    let name = pathodologicalTestName[CommandLine.arguments[2]]
{
    testPathological(name: name)
} else {
    print("no valid input specified")
}
