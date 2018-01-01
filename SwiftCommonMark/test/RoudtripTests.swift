//
//  RoudtripTests.swift
//  SwiftCommonMarkTest
//
//  Translated by OOPer in cooperation with shlab.jp, on 2018/1/1.
//  Copyright © 2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on roundtrip_tests.py
 https://github.com/commonmark/cmark/blob/master/test/roundtrip_tests.py
 */

import Foundation

class RoundtripTests: SpecTests {
    
    private func converter(_ md: String) -> (Int, String, String) {
        let cmark = CMark(prog: nil)
        let (ec, result, err) = cmark.toCommonmark(md)
        if ec == 0 {
            let (ec2, html, err2) = cmark.toHtml(result)
            if ec2 == 0 {
                //        # In the commonmark writer we insert dummy HTML
                //        # comments between lists, and between lists and code
                //        # blocks.  Strip these out, since the spec uses
                //        # two blank lines instead:
                return (ec2, html.replace("<!-- end list -->\n", ""), "")
            } else {
                return (ec2, html, err2)
            }
        } else {
            return (ec, result, err)
        }
    }
    
    override func run() -> SpecTests.ResultCounts {
        let allTests = getTests(spec)
        let tests = filterTests(allTests)
        let skipped = allTests.count - tests.count
        let resultCounts = ResultCounts(pass: 0, fail: 0, error: 0, skip: skipped)
        for test in tests {
            doTest(converter, test, normalize, resultCounts)
        }
        
        print("\(resultCounts.pass) passed, \(resultCounts.fail) failed, \(resultCounts.error) errored, \(resultCounts.skip) skipped")
        return resultCounts
    }
}
