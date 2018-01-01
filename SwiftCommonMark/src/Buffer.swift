//
//  Buffer.swift
//  SwiftCommonMark
//
//  Translated by OOPer in cooperation with shlab.jp, on 2017/12/17.
//  Copyright © 2017-2018 OOPer (NAGATA, Atsuyuki). All rights reserved.
//
/*
 Based on buffer.c and buffer.h
 https://github.com/commonmark/cmark/blob/master/src/buffer.c
 https://github.com/commonmark/cmark/blob/master/src/buffer.h
 */

import Foundation

class CmarkStrbuf {
    var ptr: UnsafeMutablePointer<UInt8>
    var asize: Int = 0
    var size: Int = 0
    
    init(ptr: UnsafeMutablePointer<UInt8>, asize: Int, size: Int) {
        self.ptr = ptr
        self.asize = asize
        self.size = size
    }
    convenience init() {
        self.init(ptr: cmark_strbuf__initbuf, asize: 0, size: 0)
    }
}
//
//static CMARK_INLINE const char *cmark_strbuf_cstr(const cmark_strbuf *buf) {
//  return (char *)buf->ptr;
//}
//
//#define cmark_strbuf_at(buf, n) ((buf)->ptr[n])
//

/* Used as default value for cmark_strbuf->ptr so that people can always
 * assume ptr is non-NULL and zero terminated even for new cmark_strbufs.
 */
let cmark_strbuf__initbuf: UnsafeMutablePointer<UInt8> = {
    let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
    ptr.initialize(to: 0)
    return ptr
}()

extension CmarkStrbuf {
    
    /**
     * Initialize a cmark_strbuf structure.
     *
     * For the cases where CMARK_BUF_INIT cannot be used to do static
     * initialization.
     */
    func initialize(initialSize: Int) {
        self.asize = 0
        self.size = 0
        self.ptr = cmark_strbuf__initbuf
        
        if initialSize > 0 {
            grow(to: initialSize)
        }
    }
    convenience init(initialSize: Int) {
        self.init()
        initialize(initialSize: initialSize)
    }
    
    private func grow(by add: Int) {
        grow(to: size + add)
    }
    
    /**
     * Grow the buffer to hold at least `target_size` bytes.
     */
    func grow(to targetSize: Int) {
        assert(targetSize > 0)
        
        if targetSize < self.asize {
            return
        }
        
        if targetSize > Int(Int32.max / 2) {
            print(
                "[cmark] cmark_strbuf_grow requests buffer with size > \(INT32_MAX / 2), aborting"
            )
            abort()
        }
        
        /* Oversize the buffer by 50% to guarantee amortized linear time
         * complexity on append operations. */
        var newSize = targetSize + targetSize/2
        newSize += 1
        newSize = (newSize + 7) & ~7
        
        let newPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: newSize)
        newPtr.initialize(from: self.ptr, count: self.asize)
        (newPtr + self.asize).initialize(to: 0, count: newSize-self.asize)
        self.ptr = newPtr
        self.asize = newSize
    }
}
//
//bufsize_t cmark_strbuf_len(const cmark_strbuf *buf) { return buf->size; }
//
extension CmarkStrbuf {
    func free() {
        
        if ptr != cmark_strbuf__initbuf {
            ptr.deinitialize(count: asize)
            ptr.deallocate(capacity: asize)
        }
        
        initialize(initialSize: 0)
    }
    
    func clear() {
        size = 0
        
        if asize > 0 {
            ptr[0] = "\0"
        }
    }
    
    func set(_ data: UnsafePointer<UInt8>?,
             _ len: Int) {
        if len <= 0 || data == nil {
            clear()
        }
        if data != UnsafePointer(ptr) {
            if len >= asize {
                grow(to: len)
            }
            memmove(ptr, data, len)
        }
        size = len
        ptr[size] = "\0"
    }
    //
    //void cmark_strbuf_sets(cmark_strbuf *buf, const char *string) {
    //  cmark_strbuf_set(buf, (const unsigned char *)string,
    //                   string ? strlen(string) : 0);
    //}
    
    func putc(_ c: UInt8) {
        grow(by: 1)
        ptr[size] = c
        size += 1
        ptr[size] = "\0"
    }
    
    func put(_ data: UnsafePointer<UInt8>, _ len: Int) {
        if len <= 0 {
            return
        }
        
        grow(by: len)
        memmove(self.ptr + size, data, len)
        size += len
        self.ptr[size] = "\0"
    }
    func put(_ buf: CmarkStrbuf) {
        put(buf.ptr, buf.size)
    }
    func put(_ buf: CmarkChunk) {
        put(buf.data, buf.len)
    }
    
    func puts(_ string: UnsafePointer<CChar>) {
        let ptr = UnsafeRawPointer(string).assumingMemoryBound(to: UInt8.self)
        put(ptr, strlen(string))
    }
    func puts(_ bytes: [UInt8]) {
        bytes.withUnsafeBufferPointer {
            put($0.baseAddress!, $0.count)
        }
    }
}
//
//void cmark_strbuf_copy_cstr(char *data, bufsize_t datasize,
//                            const cmark_strbuf *buf) {
//  bufsize_t copylen;
//
//  assert(buf);
//  if (!data || datasize <= 0)
//    return;
//
//  data[0] = '\0';
//
//  if (buf->size == 0 || buf->asize <= 0)
//    return;
//
//  copylen = buf->size;
//  if (copylen > datasize - 1)
//    copylen = datasize - 1;
//  memmove(data, buf->ptr, copylen);
//  data[copylen] = '\0';
//}
//
//void cmark_strbuf_swap(cmark_strbuf *buf_a, cmark_strbuf *buf_b) {
//  cmark_strbuf t = *buf_a;
//  *buf_a = *buf_b;
//  *buf_b = t;
//}

extension CmarkStrbuf {
    func detach() -> String {
        let string = String(cString: ptr)
        
        if self.asize == 0 {
            /* return an empty string */
            return ""
        } else {
            ptr.deinitialize(count: asize)
            ptr.deallocate(capacity: asize)
        }
        
        self.initialize(initialSize: 0)
        return string
    }
    func detachPtr() -> (UnsafeMutablePointer<UInt8>, Int) {
        let data = ptr
        let oldAsize = asize
        
        if self.asize == 0 {
            /* return an empty string */
            let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
            ptr.initialize(to: 0)
            return (ptr, 1)
        }
        
        self.initialize(initialSize: 0)
        return (data, oldAsize)
    }
    //
    //int cmark_strbuf_cmp(const cmark_strbuf *a, const cmark_strbuf *b) {
    //  int result = memcmp(a->ptr, b->ptr, MIN(a->size, b->size));
    //  return (result != 0) ? result
    //                       : (a->size < b->size) ? -1 : (a->size > b->size) ? 1 : 0;
    //}
    //
    //bufsize_t cmark_strbuf_strchr(const cmark_strbuf *buf, int c, bufsize_t pos) {
    //  if (pos >= buf->size)
    //    return -1;
    //  if (pos < 0)
    //    pos = 0;
    //
    //  const unsigned char *p =
    //      (unsigned char *)memchr(buf->ptr + pos, c, buf->size - pos);
    //  if (!p)
    //    return -1;
    //
    //  return (bufsize_t)(p - (const unsigned char *)buf->ptr);
    //}
    //
    //bufsize_t cmark_strbuf_strrchr(const cmark_strbuf *buf, int c, bufsize_t pos) {
    //  if (pos < 0 || buf->size == 0)
    //    return -1;
    //  if (pos >= buf->size)
    //    pos = buf->size - 1;
    //
    //  bufsize_t i;
    //  for (i = pos; i >= 0; i--) {
    //    if (buf->ptr[i] == (unsigned char)c)
    //      return i;
    //  }
    //
    //  return -1;
    //}
    
    func truncate(_ _len: Int) {
        var len = _len
        if len < 0 {
            len = 0
        }
        
        if len < size {
            size = len
            ptr[size] = "\0"
        }
    }
    
    func drop(_ _n: Int) {
        var n = _n
        if n > 0 {
            if n > size {
                n = size
            }
            size -= n
            if size != 0 {
                memmove(ptr, ptr + n, size)
            }
            
            ptr[size] = "\0"
        }
    }
    
    func rtrim() {
        if size == 0 {
            return
        }
        
        while size > 0 {
            if !ptr[size - 1].isSpace {
                break
            }
            
            size -= 1
        }
        
        ptr[size] = "\0"
    }
    
    func trim() {
        var i = 0
        
        if size == 0 {
            return
        }
        
        while i < size && ptr[i].isSpace {
            i += 1
        }
        
        drop(i)
        
        rtrim()
        
    }
    
    // Destructively modify string, collapsing consecutive
    // space and newline characters into a single space.
    func normalizeWhitespace() {
        var lastCharWasSpace = false
        
        var r = 0, w = 0
        while r < size {
            if ptr[r].isSpace {
                if !lastCharWasSpace {
                    ptr[w] = " "
                    w += 1
                    lastCharWasSpace = true
                }
            } else {
                ptr[w] = ptr[r]
                w += 1
                lastCharWasSpace = false
            }
            r += 1
        }
        
        truncate(w)
    }
    
    // Destructively unescape a string: remove backslashes before punctuation chars.
    func unescape() {
        
        var r = 0, w = 0
        while r < size {
            if ptr[r] == "\\" && ptr[r + 1].isPunct {
                r += 1
            }
            
            ptr[w] = ptr[r]
            w += 1
            r += 1
        }
        
        truncate(w)
    }
}
