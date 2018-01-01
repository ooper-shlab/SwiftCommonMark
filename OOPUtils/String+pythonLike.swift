//
//  String+pythonLike.swift
//  OOPUtils
//
//  Created by OOPer in cooperation with shlab.jp, on 2017/12/31.
//
//
/*
 Copyright (c) 2017-2018, OOPer(NAGATA, Atsuyuki)
 All rights reserved.
 
 Use of any parts(functions, classes or any other program language components)
 of this file is permitted with no restrictions, unless you
 redistribute or use this file in its entirety without modification.
 In this case, providing any sort of warranties or not is the user's responsibility.
 
 Redistribution and use in source and/or binary forms, without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

extension String {
    func rstrip(_ charSet: CharacterSet = CharacterSet.whitespacesAndNewlines) -> String {
        var index = self.unicodeScalars.endIndex
        while self.startIndex < index {
            let beforeIndex = self.unicodeScalars.index(before: index)
            if !charSet.contains(self.unicodeScalars[beforeIndex]) {break}
            index = beforeIndex
        }
        return String(self[..<index])
    }
    func rstrip(_ chars: String) -> String {
        return rstrip(CharacterSet(charactersIn: chars))
    }
    
    func lstrip(_ charSet: CharacterSet = CharacterSet.whitespacesAndNewlines) -> String {
        var index = self.unicodeScalars.startIndex
        while index < self.unicodeScalars.endIndex {
            if !charSet.contains(self.unicodeScalars[index]) {break}
            index = self.index(after: index)
        }
        return String(self[index...])
    }
    func lstrip(_ chars: String) -> String {
        return lstrip(CharacterSet(charactersIn: chars))
    }
    
    func strip(_ charSet: CharacterSet = CharacterSet.whitespacesAndNewlines) -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func strip(_ chars: String) -> String {
        return strip(CharacterSet(charactersIn: chars))
    }
    
    func replace(_ replaced: String, _ with: String) -> String {
        return self.replacingOccurrences(of: replaced, with: with)
    }
    
    func join(_ parts: [String]) -> String {
        return parts.joined(separator: self)
    }
    
    func split(_ separator: String) -> [String] {
        return self.components(separatedBy: separator)
    }
    
    func cgiEscape(quote: Bool = false) -> String {
        var result = ""
        for ch in self {
            switch ch {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"":
                if quote {
                    result += "&quot;"
                } else {
                    result.append(ch)
                }
            default:
                result.append(ch)
            }
        }
        return result
    }
    
    func urllibUnquote() -> String {
        return self.removingPercentEncoding ?? self
    }
    
    func urllibQuote(safe: String = "/") -> String {
        let safeChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyaABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._"+safe)
        return self.addingPercentEncoding(withAllowedCharacters: safeChars) ?? self
    }
    
    static func * (lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
