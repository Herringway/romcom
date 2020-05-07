
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
	foreach (filename; filenames) {
		auto data = cast(ubyte[])read(filename);
		results[filename] = getSNESHashes!SHA1(data);
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
		static void printCompare(string type, string hash1, string hash2) {
			const equal = (hash1 == hash2) ? "==" : "!=";
			const colour = (hash1 == hash2) ? "32" : "31";
			writefln!"%s: \u001b[%sm% 40s % 2s % 40s\u001b[0m"(type, colour, hash1, equal, hash2);
		}
		writefln!"             % 40s % 40s"(filenames[0].baseName, filenames[1].baseName);
		printCompare("Full Hashes", results[filenames[0]].primary.finish().toHexString, results[filenames[1]].primary.finish().toHexString);
		foreach (kind; results[filenames[0]].subHashes.keys.sort) {
			printCompare(format!"% 11s"(kind), results[filenames[0]].subHashes[kind].finish().toHexString, results[filenames[1]].subHashes[kind].finish().toHexString);
		}
	} else {
		assert(0, "unimplemented");
	}

}

struct Hashes(HashType) {
	HashType primary;
	HashType[string] subHashes;
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
