module romcom.nes;

import romcom.common;

private enum Mapper : ubyte {
	MMC3_6 = 4,
}

private struct ROMDetectionResult {
	Mapper mapper;
}

private auto detectROMType(const scope ubyte[] fileData) @safe pure {
	if ((fileData.length <= 16) || (fileData[0 .. 3] != "NES")) {
	    throw new Exception("Not an NES ROM?");
	}
	return ROMDetectionResult(cast(Mapper)(fileData[6]>>4));
}

auto getNESHashes(HashType)(const scope ubyte[] fileData) @safe pure {
	import std.format : format;
	import std.range : chunks, enumerate;
	Hashes!HashType result;
	const detected = detectROMType(fileData);
    const data = fileData[0x10 .. $];
	result.primary.start();
	result.primary.put(data);
	switch(detected.mapper) {
		case Mapper.MMC3_6:
			foreach (idx, bank; data.chunks(0x2000).enumerate) {
				HashType bankHash;
				bankHash.start();
				bankHash.put(bank);
				result.subHashes[format!"Bank %02X"(idx)] = bankHash;
			}
			break;
		default:
			break;
	}
	return result;
}
auto getNESDifferences(const scope ubyte[] fileData1, const scope ubyte[] fileData2) @safe pure {
	import std.format : format;
	import std.range : chunks, enumerate, only, zip;
	Differences result;
	const detected1 = detectROMType(fileData1);
	const detected2 = detectROMType(fileData2);
    const data = fileData1[0x10 .. $];
    const data2 = fileData2[0x10 .. $];
    result.primary.totalBytes = fileData1.length;
    switch (detected1.mapper) {
    	case Mapper.MMC3_6:
			foreach (idx, bank; zip(data.chunks(0x2000), data2.chunks(0x2000)).enumerate) {
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
			break;
		default: break;
	}
	return result;
}
