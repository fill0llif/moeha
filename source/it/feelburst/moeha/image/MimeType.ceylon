import ceylon.file {
	File
}

shared abstract class MimeType(shared String type) of jpegImage | pngImage | gifImage satisfies Comparable<MimeType> {
	
	shared Boolean typeOf(File file) => let (contentType = file.contentType)
		if (exists contentType)
		then type == contentType
		else false;
	
	shared actual Boolean equals(Object that) {
		if (is MimeType that) {
			return type == that.type;
		} else {
			return false;
		}
	}
	
	shared actual Integer hash => type.hash;
	
	shared actual String string => type;
}

shared object jpegImage extends MimeType("image/jpeg") {
	shared actual Comparison compare(MimeType other) => smaller;
}
shared object pngImage extends MimeType("image/png") {
	shared actual Comparison compare(MimeType other) =>
		if (other == jpegImage)
		then larger
		else smaller;
}
shared object gifImage extends MimeType("image/gif") {
	shared actual Comparison compare(MimeType other) => larger;
}

shared {MimeType*} imageMimeTypes = { jpegImage, pngImage, gifImage };

shared MimeType? fromFile(File file) =>
	imageMimeTypes.find((MimeType mimeType) => mimeType.typeOf(file));
