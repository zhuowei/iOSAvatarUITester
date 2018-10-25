//
//  LookupPrivateSymbols.swift
//  Laurelmoji
//
//  Created by Zhuowei Zhang on 2018-10-22.
//  Copyright © 2018 Zhuowei Zhang. All rights reserved.
//

import Foundation
import MachO.loader
import MachO.dyld
import MachO.dyld_images

struct dyld_cache_header
{
    var magic:(CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)
    var mappingOffset:UInt32
    var mappingCount:UInt32
    var imagesOffset:UInt32
    var imagesCount:UInt32
    var dyldBaseAddress:UInt64
    var codeSignatureOffset:UInt64
    var codeSignatureSize:UInt64
    var slideInfoOffset:UInt64
    var slideInfoSize:UInt64
    var localSymbolsOffset:UInt64
    var localSymbolsSize:UInt64
    
}

struct dyld_cache_local_symbols_info
{
    var nlistOffset:UInt32
    var nlistCount:UInt32
    var stringsOffset:UInt32
    var stringsSize:UInt32
    var entriesOffset:UInt32
    var entriesCount:UInt32
}

struct shared_file_mapping_np {
    var address:UInt64
    var size:UInt64
    var file_offset:UInt64
    var max_prot:UInt32
    var init_prot:UInt32
}

struct dyld_cache_local_symbols_entry {
    var dylibOffset:UInt32
    var nlistStartIndex:UInt32
    var nlistCount:UInt32
}

// https://github.com/comex/substitute/blob/master/lib/darwin/find-syms.c
func lookupSymbol(executable: UnsafeRawPointer, sharedCacheStart: UnsafeRawPointer, symbolName: String) -> UnsafeRawPointer? {
    
    // map the extra section from the shared cache
    let cache_fd = open("/System/Library/Caches/com.apple.dyld/dyld_shared_cache_arm64", O_RDONLY)
    if cache_fd < 0 {
        abort()
    }
    // https://gist.github.com/P1kachu/e6b14e92454a87b3f9c66b3163656d09
    
    let shared_cache_info = sharedCacheStart.bindMemory(to: dyld_cache_header.self, capacity: 1)[0]
    // https://github.com/comex/substitute/blob/master/lib/darwin/find-syms.c
    let localSymsMapping = mmap(nil, Int(shared_cache_info.localSymbolsSize), PROT_READ, MAP_PRIVATE, cache_fd, off_t(shared_cache_info.localSymbolsOffset))
    if localSymsMapping == nil {
        abort()
    }
    
    let cacheLocalSymbolsInfo = localSymsMapping!.bindMemory(to: dyld_cache_local_symbols_info.self, capacity: 1)[0]
    let cacheLocalSymbolsEntries = localSymsMapping!.advanced(by: Int(cacheLocalSymbolsInfo.entriesOffset)).bindMemory(to: dyld_cache_local_symbols_entry.self, capacity: Int(cacheLocalSymbolsInfo.entriesCount))
    let cacheLocalNlist = localSymsMapping!.advanced(by: Int(cacheLocalSymbolsInfo.nlistOffset)).bindMemory(to: nlist_64.self, capacity: Int(cacheLocalSymbolsInfo.nlistCount))
    let cacheLocalStringTab = localSymsMapping!.advanced(by: Int(cacheLocalSymbolsInfo.stringsOffset)).bindMemory(to: CChar.self, capacity: Int(cacheLocalSymbolsInfo.stringsSize))
    let offsetInCacheText = Int(bitPattern: executable) - Int(bitPattern: sharedCacheStart)
    var localEntry_:dyld_cache_local_symbols_entry?
    for i in 0..<Int(cacheLocalSymbolsInfo.entriesCount) {
        let entry = cacheLocalSymbolsEntries[i]
        if entry.dylibOffset == offsetInCacheText {
            localEntry_ = entry
            break
        }
    }
    if localEntry_ == nil {
        abort()
    }
    let localEntry = localEntry_!
    
    let shared_cache_header = sharedCacheStart.advanced(by: 0x138).bindMemory(to: shared_file_mapping_np.self, capacity: 3)
    
    for i in 0..<Int(localEntry.nlistCount) {
        let sym = cacheLocalNlist[Int(localEntry.nlistStartIndex) + i]
        if (Int32(sym.n_type) & N_TYPE) != N_SECT {
            continue
        }
        let theString = cacheLocalStringTab.advanced(by: Int(sym.n_un.n_strx))
        let symName = String(cString: theString)
        if symName == symbolName {
            // found the symbol
            return sharedCacheStart.advanced(by: Int(sym.n_value) - Int(shared_cache_header[0].address))
        }
    }
    return nil
}

func findLibraryIndex(name: String) -> UInt32 {
    for i in 0..<_dyld_image_count() {
        let curName = String(cString: _dyld_get_image_name(i))
        // print(curName)
        if curName == name {
            return i
        }
    }
    return ~0
}

func lookupSharedCacheStart() -> UInt {
    // https://raw.githubusercontent.com/saagarjha/WWDC18-Scholarship-Submission/master/InsidePlaygrounds.playground/Contents.swift
    var info = task_dyld_info(all_image_info_addr: 0, all_image_info_size: 0, all_image_info_format: 0)
    var imageCount = mach_msg_type_number_t(MemoryLayout<task_dyld_info_data_t>.size / MemoryLayout<natural_t>.size)
    withUnsafePointer(to: &info) {
        task_info(mach_task_self_, task_flavor_t(TASK_DYLD_INFO), unsafeBitCast($0, to: task_info_t.self), &imageCount)
    }
    let allImageInfos = UnsafePointer<dyld_all_image_infos>(bitPattern: UInt(info.all_image_info_addr))!.pointee
    return allImageInfos.sharedCacheBaseAddress
}

func _findAddressInLibrary(libraryName: String, symName: String) -> UnsafeRawPointer? {
    let libraryIndex = findLibraryIndex(name: libraryName)
    if libraryIndex == ~0 {
        return nil
    }
    // https://blog.lse.epita.fr/articles/82-playing-with-mach-os-and-dyld.html
    let sharedCacheStart = UnsafeRawPointer(bitPattern: lookupSharedCacheStart())!
    return lookupSymbol(executable: _dyld_get_image_header(libraryIndex), sharedCacheStart: sharedCacheStart, symbolName: symName)
}

@objc
class LookupPrivateSymbols: NSObject {
    @objc
    static func findAddressInLibrary(libraryName: String, symName: String) -> UnsafeRawPointer? {
        return _findAddressInLibrary(libraryName: libraryName, symName: symName)
    }
}
