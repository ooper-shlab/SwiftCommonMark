//
//  PathologicalTests.swift
//  SwiftCommonMarkTest
//
//  Translated by OOPer in cooperation with shlab.jp, on 2018/1/1.
//  Copyright © 2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//

import Foundation

class PathologicalTests {
    class Results {
        var passed: [String] = []
        var failed: [String] = []
        var errored: [String] = []
        var ignored: [String] = []
    }
    
    let prog: String?
    let verbose: Bool
    let exclude: Set<String>
    let cmark: CMark
    let allowedFailures: Set<String>
    var pathological: [String: (String, NSRegularExpression)] = [:]
    //let whitespaceRe: NSRegularExpression
    let results: Results
    
    init(prog: String? = nil, verbose: Bool = false, allowed: Set<String> = ["many references"], exclude: Set<String> = []) {
        self.prog = prog
        self.verbose = verbose
        self.exclude = exclude
        self.allowedFailures = allowed
        
        cmark = CMark(prog: prog)
        
        //# list of pairs consisting of input and a regex that must match the output.
        //    # note - some pythons have limit of 65535 for {num-matches} in re.
        pathological["nested strong emph"] =
            (("*a **a " * 65000) + "b" + (" a** a*" * 65000),
             try! NSRegularExpression(pattern: "(<em>a <strong>a ){65000}b( a</strong> a</em>){65000}"))
        
        pathological["many emph closers with no openers"] =
            (("a_ " * 65000),
             try! NSRegularExpression(pattern: "(a[_] ){64999}a_"))
        
        pathological["many emph openers with no closers"] =
            (("_a " * 65000),
             try! NSRegularExpression(pattern: "(_a ){64999}_a"))
        
        pathological["many link closers with no openers"] =
            (("a]" * 65000),
             try! NSRegularExpression(pattern: "(a\\]){65000}"))
        
        pathological["many link openers with no closers"] =
            (("[a" * 65000),
             try! NSRegularExpression(pattern: "(\\[a){65000}"))
        
        pathological["mismatched openers and closers"] =
            (("*a_ " * 50000),
             try! NSRegularExpression(pattern: "([*]a[_] ){49999}[*]a_"))
        
        pathological["openers and closers multiple of 3"] =
            (("a**b" + ("c* " * 50000)),
             try! NSRegularExpression(pattern: "a[*][*]b(c[*] ){49999}c[*]"))
        
        pathological["link openers and emph closers"] =
            (("[ a_" * 50000),
             try! NSRegularExpression(pattern: "(\\[ a_){50000}"))
        
        pathological["hard link/emph case"] =
            ("**x [a*b**c*](d)",
             try! NSRegularExpression(pattern: "\\*\\*x <a href=\"d\">a<em>b\\*\\*c</em></a>"))
        
        pathological["nested brackets"] =
            (("[" * 50000) + "a" + ("]" * 50000),
             try! NSRegularExpression(pattern: "\\[{50000}a\\]{50000}"))
        
        pathological["nested block quotes"] =
            ((("> " * 50000) + "a"),
             try! NSRegularExpression(pattern: "(<blockquote>\n){50000}"))
        
        pathological["U+0000 in input"] =
            ("abc\u{0000}de\u{0000}",
             try! NSRegularExpression(pattern: "abc\u{fffd}?de\u{fffd}?"))
        
        //### may take 10 minutes...
        pathological["backticks"] =
            ("".join((1...10000).map{x in ("e" + "`" * x)}),
             try! NSRegularExpression(pattern: "^<p>[e`]*</p>\n$"))
        
        //### may take 20 minutes...
        pathological["unclosed links A"] =
            ("[a](<b" * 50000,
             try! NSRegularExpression(pattern: "(\\[a\\]\\(&lt;b){50000}"))
        
        pathological["unclosed links B"] =
            ("[a](b" * 50000,
             try! NSRegularExpression(pattern: "(\\[a\\]\\(b){50000}"))
        
        //### Consumes 2.5GB of memory and could not find when to finish...
        //let n = 50000, m = 16
        //### 50MB, 1 minute
        let n = 10000, m = 1
        pathological["many references"] =
            ((1...n*m).lazy.map{x in ("[\(x)]: u\n")}.joined(separator: "") + "[0] " * n,
             try! NSRegularExpression(pattern: "(\\[0\\] ){\(n-1)}"))
        
        //whitespaceRe = try! NSRegularExpression(pattern: "\\s+")
        
        results = Results()
    }
    
    private func run_pathological_test(description: String, results: Results) {
        if exclude.contains(description) {
            if verbose {print(description, "[EXCLUDED]")}
            results.ignored.append(description)
            return
        }
        if verbose {print(description, "[TESTING]")}
        let (inp, regex) = pathological[description]!
        let (rc, actual, err) = cmark.toHtml(inp)
        //    extra = ""
        if rc != 0 {
            if verbose {print(description, "[ERRORED (return code \(rc))]")}
            if verbose {print(err)}
            if allowedFailures.contains(description) {
                results.ignored.append(description)
            } else {
                results.errored.append(description)
            }
        } else if regex.search(actual) != nil {
            if verbose {print(description, "[PASSED]")}
            results.passed.append(description)
        } else {
            if verbose {print(description, "[FAILED]")}
            if verbose {debugPrint(actual)}
            if allowedFailures.contains(description) {
                results.ignored.append(description)
            } else {
                results.failed.append(description)
            }
        }
    }
    
    func run() -> (passed: Int, failed: Int, errored: Int, ignored: Int) {
        print("Testing pathological cases:")
        for description in pathological.keys {
            //### Currently our Swift version of cmark is thread-unsafe...
            run_pathological_test(description: description, results: results)
            //    p = multiprocessing.Process(target=run_pathological_test,
            //              args=(description, results,))
            //    p.start()
            //    # wait 4 seconds or until it finishes
            //    p.join(4)
            //    # kill it if still active
            //    if p.is_alive():
            //        print(description, '[TIMEOUT]')
            //        if allowed_failures[description]:
            //            results['ignored'].append(description)
            //        else:
            //            results['errored'].append(description)
            //        p.terminate()
            //        p.join()
        }
        
        let passed = results.passed.count
        let failed = results.failed.count
        let errored = results.errored.count
        let ignored = results.ignored.count
        
        print("\(passed) passed, \(failed) failed, \(errored) errored", terminator: "")
        if ignored > 0 {
            if verbose {
                print()
                print("Ignoring these allowed failures:")
                for x in results.ignored {
                    print(x)
                }
            } else {
                print(" \(ignored) ignored")
            }
        }
        return (passed, failed, errored, ignored)
    }
}
