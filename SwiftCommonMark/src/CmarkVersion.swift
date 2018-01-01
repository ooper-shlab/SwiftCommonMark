//
//  CmarkVersion.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on cmark_version.h.in
 https://github.com/commonmark/cmark/blob/master/src/cmark_version.h.in

 Works in combination with cmark_version.s and SwiftCommonMark-BridgingHeader.h.
 (Importing some compile-time options.)
 */

import Foundation

let CMARK_VERSION = ((_PROJECT_VERSION_MAJOR_ << 16) | (_PROJECT_VERSION_MINOR_ << 8)  | _PROJECT_VERSION_PATCH_)
let CMARK_VERSION_STRING = "\(_PROJECT_VERSION_MAJOR_).\(_PROJECT_VERSION_MINOR_).\(_PROJECT_VERSION_PATCH_)"
