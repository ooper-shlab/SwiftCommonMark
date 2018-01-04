//
//  HTMLParser.swift
//  HtmlNormalizer
//
//  Created by OOPer in cooperation with shlab.jp, on 2017/12/31.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//

import Foundation

private let entityDict: [String: String] = {
    var dict: [String: String] = [:]
    for entry in cmark_entities {
        dict[entry.name] = entry.characters
    }
    return dict
}()

private class EntityReplacingRegex: NSRegularExpression {
    override func replacementString(for result: NSTextCheckingResult, in string: String, offset: Int, template templ: String) -> String {
        if
            let range = Range(result.range(at: 1), in: string),
            let ch = decodeNumericEntity(String(string[range]))
        {
            return ch
        } else if
            let range = Range(result.range(at: 2), in: string),
            let value = decodeNamedEntity(String(string[range]))
        {
            return value
        } else {
            return super.replacementString(for: result, in: string, offset: offset, template: templ)
        }
    }
}

func decodeNumericEntity(_ name: String) -> String? {
    if
        name.hasPrefix("x"),
        let codePoint = UInt32(name.dropFirst(), radix: 16),
        let us = UnicodeScalar(codePoint)
    {
        return String(us)
    } else if
        let codePoint = UInt32(name),
        let us = UnicodeScalar(codePoint)
    {
        return String(us)
    } else {
        return nil
    }
}

func decodeNamedEntity(_ name: String) -> String? {
    if let ch = entityDict[name] {
        return ch
    } else {
        return nil
    }
}

class HTMLParserError: Error {
    
}
@objc public class HTMLParser: NSObject {
    
    public weak var delegate: HTMLParserDelegate?
    
    public var isSelfClosing: Bool = false
    
    private var reEnv: ReEnv
    
    public var string: String {
        return reEnv.string
    }

    public init(string: String) {
        self.reEnv = ReEnv(string: string)
    }
    
    static let atEnd = Re("$").compile()
    static let _doctypeName = Re("[a-zA-Z_][a-zA-Z0-9_.-]*")
    static let _tagName = Re("[a-zA-Z_][a-zA-Z0-9_.-]*")
    static let _attrName = Re("[a-zA-Z_][a-zA-Z0-9_.-]*")
    static let _targetName = Re("[a-zA-Z_][a-zA-Z0-9_.-]*")
    static let _numericEntity = Re("&#(?:[0-9]{1,8}|x[0-9a-fA-F]{1,8});")
    static let _namedEntity = Re("&[a-zA-Z_][a-zA-Z0-9_.-]*;")
    static let _dqValue = "\"" & (Re("[^\"&]") | _numericEntity | _namedEntity)* & "\""
    static let _sqValue = "'" & (Re("[^'&]") | _numericEntity | _namedEntity)* & "'"
    static let _attrValue = _dqValue | _sqValue
    static let _attribute = _attrName & Re("\\s*") & "=" & Re("\\s*") & _attrValue
    static let startTag = ("<" & _tagName.cap & (Re("\\s+") & (_attribute & (Re("\\s*") & _attribute)*).cap).opt & Re("\\s*") & Re("/").cap.opt & ">").compile()
    static let endTag = ("</" & _tagName.cap & Re("\\s*") & ">").compile()
    static let attributeCap = (_attrName.cap & Re("\\s*") & "=" & Re("\\s*") & _attrValue.cap).compile()
    static let characters = Re("[^<&]+").compile()
    static let comment = ("<!--" & Re("(?:[^-]|-[^-])*").cap & "-->").compile()
    static let cdata = ("<![CDATA[".i & Re("(?:[^\\]]|\\][^\\]]|\\]\\][^>])*").cap & "]]>").compile()
    static let doctype = ("<!DOCTYPE" & Re("\\s+") & _doctypeName.cap &
        (Re("\\s+") & "PUBLIC".i & Re("\\s*") & Re("\"[^\"]*\"").cap
            & Re("\\s*") & Re("\"[^\"]*\"").cap).opt & Re("\\s*>")).compile()
    static let processingInstruction = "<?" & Re("(?!(?i:xml))") & _targetName.cap & Re("\\s+(?:[^<]|<[^?])*").cap.opt & "?>"
    static let numericEntity = "&#" & Re("(?:[0-9]{1,8}|x[0-9a-fA-F]{1,8})").cap & ";"
    static let namedEntity = "&" & Re("[a-zA-Z_][a-zA-Z0-9_.-]*").cap & ";"
    static let entityCap = numericEntity | namedEntity
    
    private func getEnclosedValue<S:StringProtocol>(_ valueStr: S) -> String
        where S.SubSequence: StringProtocol
    {
        let start = valueStr.index(after: valueStr.startIndex)
        let end = valueStr.index(before: valueStr.endIndex)
        return decodeEntities(String(valueStr[start..<end]))
    }
    
    private func decodeEntities(_ stringWithEntities: String) -> String {
        let regex = try! EntityReplacingRegex(pattern: HTMLParser.entityCap.pattern)
        return regex.stringByReplacingMatches(in: stringWithEntities, options: [], range: NSRange(0..<stringWithEntities.utf16.count), withTemplate: "$0")
    }
    
    public func parse() {
        delegate?.parserDidStartDocument?(self)
        mainLoop: while true {
            switch reEnv {
            case HTMLParser.atEnd:
                break mainLoop
            case HTMLParser.startTag:
                let tagName = reEnv.matches[1]!.lowercased()
                var attrs: [String: String] = [:]
                if let attributes = reEnv.matches[2] {
                    let attrString = String(attributes)
                    HTMLParser.attributeCap.regex.enumerateMatches(in: attrString, options: [], range: NSRange(0..<attributes.utf16.count)) {result, flags, stop in
                        let attrNameRange = Range(result!.range(at: 1), in: attrString)!
                        let attrValueRange = Range(result!.range(at: 2), in: attrString)!
                        let attrName = attrString[attrNameRange].lowercased()
                        let attrValue = getEnclosedValue(attrString[attrValueRange])
                        attrs[attrName] = attrValue
                    }
                }
                let selfEnding = reEnv.matches[2] != nil
                if !selfEnding {
                    delegate?.parser?(self, didStartElement: tagName, attributes: attrs)
                } else {
                    isSelfClosing = true
                    delegate?.parser?(self, didStartElement: tagName, attributes: attrs)
                    delegate?.parser?(self, didEndElement: tagName)
                    isSelfClosing = false
                }
            case HTMLParser.endTag:
                let tagName = reEnv.matches[1]!.lowercased()
                delegate?.parser?(self, didEndElement: tagName)
            case HTMLParser.characters:
                let chars = reEnv.matches[0]!
                delegate?.parser?(self, foundCharacters: String(chars))
            case HTMLParser.cdata:
                let data = reEnv.matches[1]!
                delegate?.parser?(self, foundCDATA: String(data))
            case HTMLParser.comment:
                let comment = reEnv.matches[1]!
                delegate?.parser?(self, foundComment: String(comment))
            case HTMLParser.doctype:
                let name = reEnv.matches[1]!.lowercased()
                let publicID = reEnv.matches[2].map{String($0)}
                let systemID = reEnv.matches[3].map{String($0)}
                delegate?.parser?(self, foundDoctypeDeclarationWithName: name, publicID: publicID, systemID: systemID)
            case HTMLParser.processingInstruction:
                let target = String(reEnv.matches[1]!)
                let data = reEnv.matches[2].map{String($0)}
                delegate?.parser?(self, foundProcessingInstructionWithTarget: target, data: data)
            case HTMLParser.numericEntity:
                let value = String(reEnv.matches[1]!)
                delegate?.parser?(self, foundNumericEntity: value, character: decodeNumericEntity(value))
            case HTMLParser.namedEntity:
                let value = String(reEnv.matches[1]!)
                delegate?.parser?(self, foundNamedEntity: value, character: decodeNamedEntity(value))
            default:
                let error = HTMLParserError()
                delegate?.parser?(self, parseErrorOccurred: error)
                break mainLoop
            }
        }
        delegate?.parserDidEndDocument?(self)
    }
}

@objc public protocol HTMLParserDelegate {
    
    
    @objc optional func parserDidStartDocument(_ parser: HTMLParser)
    
    
    @objc optional func parserDidEndDocument(_ parser: HTMLParser)
    
    
    @objc optional func parser(_ parser: HTMLParser, foundDoctypeDeclarationWithName name: String, publicID: String?, systemID: String?)
    
    
    @objc optional func parser(_ parser: HTMLParser, didStartElement elementName: String, attributes attributeDict: [String : String])
    
    
    @objc optional func parser(_ parser: HTMLParser, didEndElement elementName: String)
    
    
    @objc optional func parser(_ parser: HTMLParser, foundCharacters string: String)
    
    
    @objc optional func parser(_ parser: HTMLParser, foundNumericEntity name: String, character: String?)
    
    
    @objc optional func parser(_ parser: HTMLParser, foundNamedEntity name: String, character: String?)
    
    
    @objc optional func parser(_ parser: HTMLParser, foundComment comment: String)
    
    
    @objc optional func parser(_ parser: HTMLParser, foundCDATA CDATABlock: String)
    
    
    @objc optional func parser(_ parser: HTMLParser, foundProcessingInstructionWithTarget target: String, data: String?)
    
    
    @objc optional func parser(_ parser: HTMLParser, parseErrorOccurred parseError: Error)
}


