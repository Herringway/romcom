module romcom.snes;

import romcom.common;

struct SNESROMDetectionResult {
	bool hasHalfBanks;
	bool headered;
}
auto detectSNESROMType(const scope ubyte[] fileData) @safe pure {
	import std.range : only, zip;
    foreach (halfSized, headered, base; zip(only(true, true, false, false), only(false, true, false, true), only(0x7FB0, 0x81B0, 0xFFB0, 0x101B0))) {
        const checksum = (cast(const ushort[])fileData[base + 46 .. base + 48])[0];
        const checksumComplement = (cast(const ushort[])fileData[base + 44 .. base + 46])[0];
        if ((checksum ^ checksumComplement) == 0xFFFF) {
        	return SNESROMDetectionResult(halfSized, headered);
        }
    }
    throw new Exception("Not an SNES ROM?");
}

auto getSNESHashes(HashType)(const scope ubyte[] fileData) @safe pure {
	import std.format : format;
	import std.range : chunks, enumerate;
	Hashes!HashType result;
	const detected = detectSNESROMType(fileData);
    const data = detected.headered ? fileData[0x200 .. $] : fileData;
	result.primary.start();
	result.primary.put(data);
	foreach (idx, bank; data.chunks(detected.hasHalfBanks ? 0x8000 : 0x10000).enumerate) {
		HashType bankHash;
		bankHash.start();
		bankHash.put(bank);
		result.subHashes[format!"Bank %02X"(idx)] = bankHash;
	}
	return result;
}
auto getSNESDifferences(const scope ubyte[] fileData1, const scope ubyte[] fileData2) @safe pure {
	import std.format : format;
	import std.range : chunks, enumerate, only, zip;
	Differences result;
	const detected1 = detectSNESROMType(fileData1);
	const detected2 = detectSNESROMType(fileData2);
    const data = detected1.headered ? fileData1[0x200 .. $] : fileData1;
    const data2 = detected2.headered ? fileData2[0x200 .. $] : fileData2;
    result.primary.totalBytes = data.length;
	foreach (idx, bank; zip(data.chunks(detected1.hasHalfBanks ? 0x8000 : 0x10000), data2.chunks(detected2.hasHalfBanks ? 0x8000 : 0x10000)).enumerate) {
		SectionCompared section;
		foreach (b1, b2; zip(bank[0], bank[1])) {
			if (b1 != b2) {
				result.primary.differentBytes++;
				section.differentBytes++;
			}
		}
		section.totalBytes = bank[0].length;
		result.subDifferences[format!"Bank %02X"(idx)] = section;
	}
	return result;
}
