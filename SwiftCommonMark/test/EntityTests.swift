//
//  EntityTests.swift
//  SwiftCommonMarkTest
//
//  Translated by OOPer in cooperation with shlab.jp, on 2018/1/1.
//  Copyright © 2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on entity_tests.py
 https://github.com/commonmark/cmark/blob/master/test/entity_tests.py
 */

import Foundation

class EntityTests {
    func getEntities() -> [(String, String)] {
        let regex = try! NSRegularExpression(pattern: "^\\{\\(unsigned char\\*\\)\"([^\"]+)\", \\{([^\\}]+)\\}", options: .anchorsMatchLines)
        let testBundle = Bundle(for: type(of: self))
        let path = testBundle.path(forResource: "entities", ofType: "inc")!
        let code = try! String(contentsOfFile: path)
        var entities: [(String, String)] = []
        regex.enumerateMatches(in: code, options: [], range: NSRange(0..<code.utf16.count)) {match, flag, stop in
            let entity = String(code[Range(match!.range(at: 1), in: code)!])
            let bytesStr = String(code[Range(match!.range(at: 2), in: code)!])
            let utf8 = String(cString: bytesStr.split(", ").map{str in UInt8(str)!})
            entities.append((entity, utf8))
        }
        return entities
    }
    
    var verbose: Bool
    init(verbose: Bool = false) {
        self.verbose = verbose
    }
    
    func run() -> (Int, Int, Int) {
        let cmark = CMark(prog: nil)
        
        let entities = getEntities()
        
        var passed = 0
        var errored = 0
        var failed = 0
        
        let exceptions: [String: String] = [
            "quot": "&quot;",
            "QUOT": "&quot;",
            
            //    # These are broken, but I'm not too worried about them.
            "nvlt": "&lt;\u{20D2}", //'<' + COMBINING LONG VERTICAL LINE OVERLAY
            "nvgt": "&gt;\u{20D2}", //'>' + COMBINING LONG VERTICAL LINE OVERLAY
            ]
        
        print("Testing entities:")
        for (entity, utf8) in entities {
            let (rc, actual, err) = cmark.toHtml("&\(entity);")
            let check = exceptions[entity] ?? utf8
            
            if rc != 0 {
                errored += 1
                if verbose {print(entity, "[ERRORED (return code \(rc))]")}
                if verbose {print(err)}
            } else if actual.contains(check) {
                if verbose {print(entity, "[PASSED]")}
                passed += 1
            } else {
                if verbose {print(entity, "[FAILED]")}
                if verbose {debugPrint(actual)}
                failed += 1
            }
        }
        
        print("\(passed) passed, \(failed) failed, \(errored) errored")
        return (passed, failed, errored)
    }
}
