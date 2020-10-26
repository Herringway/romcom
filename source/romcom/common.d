module romcom.common;

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
