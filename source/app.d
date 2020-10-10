
import std.algorithm;
import std.digest;
import std.digest.md;
import std.digest.sha;
import std.exception;
import std.file;
import std.format;
import std.getopt;
import std.path;
import std.range;
import std.stdio;

void main(string[] args) {
	auto opts = getopt(args);

	if (opts.helpWanted || (args.length < 2) || (args.length > 4)) {
		defaultGetoptPrinter("Usage: romcom <romfile> [romfile2]", opts.options);
		return;
	}
	Hashes!SHA1[string] results;

	const filenames = args[1 .. $];
	ubyte[][] files;
	foreach (filename; filenames) {
		files ~= cast(ubyte[])read(filename);
		results[filename] = getSNESHashes!SHA1(files[$ - 1]);
	}
	if (filenames.length == 1) {
		static void printResult(string type, string hash) {
			writefln!"%s: % 40s"(type, hash);
		}
		writefln!"             % 40s"(filenames[0].baseName);
		printResult("Full Hash  ", results[filenames[0]].primary.finish().toHexString);
		foreach (kind; results[filenames[0]].subHashes.keys.sort) {
			printResult(format!"% 11s"(kind), results[filenames[0]].subHashes[kind].finish().toHexString);
		}

	} else if (filenames.length == 2) {
		auto diffs = getSNESDifferences(files[0], files[1]);
		static void printCompare(string type, string hash1, string hash2, size_t differences, size_t total) {
			const equal = (hash1 == hash2) ? "==" : "!=";
			const colour = (hash1 == hash2) ? "32" : "31";
			writefln!"%s: \u001b[%sm% 40s % 2s % 40s (%s/%s - %.1f%%)\u001b[0m"(type, colour, hash1, equal, hash2, differences, total, cast(double)(total - differences) / cast(double)total * 100.0);
		}
		writefln!"             % 40s % 40s"(filenames[0].baseName, filenames[1].baseName);
		printCompare("Full Hashes", results[filenames[0]].primary.finish().toHexString, results[filenames[1]].primary.finish().toHexString, diffs.primary.differentBytes, diffs.primary.totalBytes);
		foreach (kind; results[filenames[0]].subHashes.keys.sort) {
			printCompare(format!"% 11s"(kind), results[filenames[0]].subHashes[kind].finish().toHexString, results[filenames[1]].subHashes[kind].finish().toHexString, diffs.subDifferences[kind].differentBytes, diffs.subDifferences[kind].totalBytes);
		}
	} else {
		assert(0, "unimplemented");
	}

}

struct Hashes(HashType) {
	HashType primary;
	HashType[string] subHashes;
}

struct SectionCompared {
	size_t differentBytes;
	size_t totalBytes;
}

struct Differences {
	SectionCompared primary;
	SectionCompared[string] subDifferences;
}


struct SNESROMDetectionResult {
	bool hasHalfBanks;
	bool headered;
}
auto detectSNESROMType(const scope ubyte[] fileData) @safe pure {
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
	Differences result;
	const detected1 = detectSNESROMType(fileData1);
	const detected2 = detectSNESROMType(fileData2);
    const data = detected1.headered ? fileData1[0x200 .. $] : fileData1;
    const data2 = detected2.headered ? fileData2[0x200 .. $] : fileData2;
    result.primary.totalBytes = fileData1.length;
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
