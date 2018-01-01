//
//  SpecTests.swift
//  SwiftCommonMarkTest
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/30.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on spec_tests.py
 https://github.com/commonmark/cmark/blob/master/test/spec_tests.py
 */

import Foundation

class SpecTests {
    var program: String?
    var spec: String = "spec.txt"
    var pattern: String?
    var normalize: Bool = true
    var options: CmarkOptions = .default
    var number: Int?
    
    init(program: String? = nil,
         spec: String = "spec.txt",
         pattern: String? = nil,
         normalize: Bool = true,
         options: CmarkOptions = .default,
         number: Int? = nil) {
        self.program = program
        self.spec = spec
        self.pattern = pattern
        self.normalize = normalize
        self.options = options
        self.number = number
    }
    
    private func printTestHeader(_ t: Test) {
        print("Example \(t.example) (lines \(t.startLine)-\(t.endLine)) \(t.section)")
    }
    
    func doTest(_ converter: (String) -> (Int, String, String), _ test: Test, _ normalize: Bool, _ resultCounts: ResultCounts) {
        let (retcode, actualHtml, err) = converter(test.markdown)
        if retcode == 0 {
            let expectedHtml = test.html
            //let unicodeError: String? = nil
            let passed: Bool
            if normalize {
                passed = normalize_html(actualHtml) == normalize_html(expectedHtml)
            } else {
                passed = actualHtml == expectedHtml
            }
            if passed {
                resultCounts.pass += 1
            } else {
                //TODO: show better 'Failed' info like diff in the original code
                printTestHeader(test)
                print("***** Failed *****")
                debugPrint(test.markdown)
                if normalize {
                    debugPrint(normalize_html(expectedHtml))
                    debugPrint(normalize_html(actualHtml))
                } else {
                    debugPrint(expectedHtml)
                    debugPrint(actualHtml)
                }
                print()
                resultCounts.fail += 1
            }
        } else {
            printTestHeader(test)
            print("program returned error code \(retcode)")
            print(err, to: &stderr)
            resultCounts.error += 1
        }
    }
    
    struct Test: Encodable {
        var markdown: String
        var html: String
        var example: Int
        var startLine: Int
        var endLine: Int
        var section: String
    }
    private enum State {
        case regularText
        case markdownExample
        case htmlOutput
    }
    func getTests(_ specfile: String) -> [Test] {
        var lineNumber = 0
        var startLine = 0
        var endLine = 0
        var exampleNumber = 0
        var markdownLines: [String] = []
        var htmlLines: [String] = []
        var state: State = .regularText
        var headertext = ""
        var tests: [Test] = []
        
        let headerRe = try! NSRegularExpression(pattern: "#+ ")
        
        doLabel: do {
            guard let specf = TextReader(filePath: specfile, encoding: .utf8) else {break doLabel}
            while let line = specf.next() {
                lineNumber += 1
                let l = line.strip()
                if l == "`" * 32 + " example" {
                    state = .markdownExample
                } else if l == "`" * 32 {
                    state = .regularText
                    exampleNumber += 1
                    endLine = lineNumber
                    tests.append(Test(
                        markdown: "".join(markdownLines).replace("→", "\t"),
                        html: "".join(htmlLines).replace("→", "\t"),
                        example: exampleNumber,
                        startLine: startLine,
                        endLine: endLine,
                        section: headertext))
                    startLine = 0
                    markdownLines = []
                    htmlLines = []
                } else if l == "." {
                    state = .htmlOutput
                } else if state == .markdownExample {
                    if startLine == 0 {
                        startLine = lineNumber - 1
                    }
                    markdownLines.append(line)
                } else if state == .htmlOutput {
                    htmlLines.append(line)
                } else if state == .regularText && headerRe.match(line) != nil {
                    headertext = headerRe.sub("", line).strip()
                }
            }
        }
        return tests
    }
    
    public func debugNormalization() {
        //        out(normalize_html(sys.stdin.read()))
        //        exit(0)
        //TODO: Do you need this?
    }
    
    public class ResultCounts {
        public var pass: Int
        public var fail: Int
        public var error: Int
        public var skip: Int
        
        init(pass: Int, fail: Int, error: Int, skip: Int) {
            self.pass = pass
            self.fail = fail
            self.error = error
            self.skip = skip
        }
    }
    func filterTests(_ allTests: [Test]) -> [Test] {
        let patternRe: NSRegularExpression
        if let pattern = pattern {
            do {
                patternRe = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            } catch {
                patternRe = try! NSRegularExpression(pattern: ".")
            }
        } else {
            patternRe = try! NSRegularExpression(pattern: ".")
        }
        let tests = allTests.filter{test in patternRe.search(test.section) != nil && (number == nil || test.example == number)}
        return tests
    }
    
    public func dumpTests() {
        let allTests = getTests(spec)
        let tests = filterTests(allTests)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(tests)
        print(String(data: data, encoding: .utf8)!, terminator: "")
    }
    
    open func run() -> ResultCounts {
        let allTests = getTests(spec)
        let tests = filterTests(allTests)
        let skipped = allTests.count - tests.count
        let converter = CMark(prog: program, options: options).toHtml
        let resultCounts = ResultCounts(pass: 0, fail: 0, error: 0, skip: skipped)
        for test in tests {
            doTest(converter, test, normalize, resultCounts)
        }
        print("\(resultCounts.pass) passed, \(resultCounts.fail) failed, \(resultCounts.error) errored, \(resultCounts.skip) skipped")
        return resultCounts
    }
}

