module app;

import std.algorithm.sorting;
import std.digest.sha;
import std.file;
import std.format;
import std.getopt;
import std.path;
import std.stdio;

import romcom.common;
import romcom.nes;
import romcom.snes;
import romcom.plain;

enum Type {
	snes,
	nes,
	plain
}

void main(string[] args) {
	Type type = Type.snes;

	auto opts = getopt(args,
		"type|t", "Type of ROM being compared", &type);

	if (opts.helpWanted || (args.length < 2) || (args.length > 4)) {
		defaultGetoptPrinter("Usage: romcom <romfile> [romfile2]", opts.options);
		return;
	}
	Hashes!SHA1[string] results;

	const filenames = args[1 .. $];
	ubyte[][] files;
	foreach (filename; filenames) {
		files ~= cast(ubyte[])read(filename);
		results[filename] = getHashes!SHA1(type, files[$ - 1]);
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
		auto diffs = getDifferences(type, files[0], files[1]);
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

auto getHashes(Hash)(Type type, const scope ubyte[] file) {
	final switch (type) {
		case Type.snes: return getSNESHashes!Hash(file);
		case Type.nes: return getNESHashes!Hash(file);
		case Type.plain: return getPlainHashes!Hash(file);
	}
}

auto getDifferences(Type type, const scope ubyte[] file1, const scope ubyte[] file2) {
	final switch (type) {
		case Type.snes: return getSNESDifferences(file1, file2);
		case Type.nes: return getNESDifferences(file1, file2);
		case Type.plain: return getPlainDifferences(file1, file2);
	}
}
