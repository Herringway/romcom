module romcom.plain;

import romcom.common;

auto getPlainHashes(HashType)(const scope ubyte[] fileData) @safe pure {
	Hashes!HashType result;
	result.primary.start();
	result.primary.put(fileData);
	return result;
}
auto getPlainDifferences(const scope ubyte[] fileData1, const scope ubyte[] fileData2) @safe pure {
	import std.range : zip;
	Differences result;
    result.primary.totalBytes = fileData1.length;
	foreach (b1, b2; zip(fileData1, fileData2)) {
		if (b1 != b2) {
			result.primary.differentBytes++;
		}
	}
	return result;
}
