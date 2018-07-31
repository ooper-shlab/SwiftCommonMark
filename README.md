 # SwiftCommonMark
 
 An experimental translation of cmark into Swift.
 (Or should be called as an _excercise_.)

Translated by OOPer in cooperation with shlab.jp, on 2018/1/1.

Based on
<https://github.com/commonmark/cmark>
(Latest commit 5c3ef83c785793c13614f7aec4c376937885a180).

As this is a line-by-line translation from the original code and many files are copies as-is from the original repository,
please take care about those original licenses shown in COPYING.orig.
Some faults caused by my translation may exist. Not all features tested.
You should not contact to the original authors or commonmark.org or SHLab(jp) about any faults caused by my translation.

### Some notes

- Command line interface is not tested.
- This is not so fast as the original cmark. One reason is removing re2c dependent codes (I could not have found re2swift!).
 (And the goal is not making this code faster than the original C-version. I want to make this project more Swifty and fast enough as a native Swift app.)
 - Current status of this project is sort of _a new C-dialect called Swift_. Please do not expect too much.

## Requirements

### Build

Xcode 9.4.1, macOS SDK 10.13.

### Runtime

macOS 10.12 or above.
