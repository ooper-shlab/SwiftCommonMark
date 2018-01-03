//
//  Re.swift
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

class Re {
    private static var regexPool: [String: NSRegularExpression] = [:]
    private(set) var pattern: String
    
    private var _regex: NSRegularExpression?
    var regex: NSRegularExpression {
        if _regex == nil {
            if let rex = Re.regexPool[pattern] {
                _regex = rex
            } else {
                _regex = try! NSRegularExpression(pattern: pattern, options: [])
                Re.regexPool[pattern] = _regex!
            }
        }
        return _regex!
    }
    
    init(_ pattern: String) {
        self.pattern = pattern
    }
    
    init(literal: String) {
        self.pattern = NSRegularExpression.escapedPattern(for: literal)
    }
    init(caseInsensitive literal: String) {
        self.pattern = "(?i:"+NSRegularExpression.escapedPattern(for: literal)+")"
    }
    init(_ literals: [String]) {
        self.pattern = literals.map{NSRegularExpression.escapedPattern(for: $0)}.joined(separator: "|")
    }
    init(caseInsensitive literals: [String]) {
        self.pattern = "(?i:"+literals.map{NSRegularExpression.escapedPattern(for: $0)}.joined(separator: "|")+")"
    }
    
    var opt: Re {
        return Re("(?:"+pattern+")?")
    }
    
    var cap: Re {
        return Re("("+pattern+")")
    }
    
    public func compile() -> Re {
        _ = self.regex
        return self
    }
}
public class ReEnv {
    var string: String
    var startIndex: String.UnicodeScalarIndex
    var endIndex: String.UnicodeScalarIndex

    ///Represent UTF-16 offset from startIndex to next position to match
    public var current: Int
    
    var matches: [Substring?] = []
    init(_ ptr: UnsafePointer<UInt8>) {
        self.string = String(cString: ptr)
        self.startIndex = string.startIndex
        self.endIndex = string.endIndex
        current = 0
    }
    init(string: String) {
        self.string = string
        self.startIndex = string.startIndex
        self.endIndex = string.endIndex
        current = 0
    }
    public init(_ string: String, _ startIndex: String.UnicodeScalarIndex, _ endIndex: String.UnicodeScalarIndex) {
        self.string = string
        self.startIndex = startIndex
        self.endIndex = endIndex
        current = 0
    }

    ///Returns UTF-8 count from pos to current
    ///pos needs to be some value taken from current
    func size(from pos: Int) -> Int {
        if pos > current {
            return -1
        } else {
            let startIndex = string.utf16.index(self.startIndex, offsetBy: pos)
            let endIndex = string.utf16.index(startIndex, offsetBy: current-pos)
            return string.utf8.distance(from: startIndex, to: endIndex)
        }
    }
}

func ~= (re: Re, env: ReEnv) -> Bool {
    let regex = re.regex
    let start = env.string.utf16.index(env.startIndex, offsetBy: env.current)
    let range = NSRange(start..., in: env.string)
    if let firstMatch = regex.firstMatch(in: env.string, options: .anchored, range: range) {
        env.current += firstMatch.range.length
        env.matches = (0..<firstMatch.numberOfRanges).map{index in
            let nsRange = firstMatch.range(at: index)
            if let range = Range(nsRange, in: env.string) {
                return env.string[range]
            } else {
                return nil
            }
        }
        return true
    } else {
        return false
    }
}

func & (lhs: Re, rhs: Re) -> Re {
    return Re(lhs.pattern+rhs.pattern)
}

func & (string: String, rhs: Re) -> Re {
    return Re(literal: string) & rhs
}

func & (lhs: Re, string: String) -> Re {
    return lhs & Re(literal: string)
}

func | (lhs: Re, rhs: Re) -> Re {
    return Re("(?:"+lhs.pattern+"|"+rhs.pattern+")")
}

func | (string: String, rhs: Re) -> Re {
    return Re(literal: string) | rhs
}

func | (lhs: Re, string: String) -> Re {
    return lhs | Re(literal: string)
}

func / (lhs: Re, rhs: Re) -> Re {
    return Re(lhs.pattern+"(?="+rhs.pattern+")")
}

func / (string: String, rhs: Re) -> Re {
    return Re(literal: string) / rhs
}

func / (lhs: Re, string: String) -> Re {
    return lhs / Re(literal: string)
}

postfix operator *
postfix func * (re: Re) -> Re {
    return Re("(?:"+re.pattern+")*")
}
postfix func * (string: String) -> Re {
    return Re(literal: string)*
}

postfix operator +
postfix func + (re: Re) -> Re {
    return Re("(?:"+re.pattern+")+")
}
postfix func + (string: String) -> Re {
    return Re(literal: string)+
}

extension String {
    var opt: Re {
        return Re([self]).opt
    }
    var i: Re {
        return Re(caseInsensitive: self)
    }
}
extension Array where Element == String {
    var i: Re {
        return Re(caseInsensitive: self)
    }
}
