import ceylon.collection {
	HashMap,
	MutableMap
}
import ceylon.file {
	File,
	Path
}

import java.awt.image {
	BufferedImage
}
import java.io {
	JFile=File
}

import javax.imageio {
	ImageIO
}
import javax.imageio.stream {
	ImageInputStream,
	FileImageInputStream
}

shared class Image(shared Path path) satisfies Comparable<Image> {
	
	variable MimeType? cachedMimeType = null;
	variable Integer|Exception? cachedWidth = null;
	variable Integer|Exception? cachedHeight = null;
	variable MutableMap<String,Comparison> cachedComparisons = HashMap<String,Comparison>();
	
	shared MimeType mimeType =>
		if (exists cmt = cachedMimeType)
		then cmt
		else
			let (mimeType = () {
					"Path [[path]] is not a file"
					assert (is File fileInternal = path.resource);
					"Content type of file [[fileInternal]] cannot be determined"
					assert (fileInternal.contentType exists);
					"File [[fileInternal]] is not an image"
					assert (exists mimeTypeInternal = fromFile(fileInternal));
					return mimeTypeInternal;
				})
				(cachedMimeType = mimeType());
	
	shared File file() {
		assert (is File file = path.resource);
		return file;
	}
	
	ImageInputStream imageInputStream() => FileImageInputStream(JFile(path.string));
	
	[Integer, Integer]|Exception dimensions {
		value iis = imageInputStream();
		try {
			value imageReaders = ImageIO.getImageReaders(iis);
			if (imageReaders.hasNext()) {
				value imageReader = imageReaders.next();
				imageReader.input = iis;
				return [imageReader.getWidth(imageReader.minIndex), imageReader.getHeight(imageReader.minIndex)];
			} else {
				return Exception("No reader found for mime type ``mimeType``");
			}
		} finally {
			iis.close();
		}
	}
	
	BufferedImage|Exception bufferedImage {
		try {
			return ImageIO.read(JFile(path.string));
		} catch (Exception e) {
			return e;
		}
	}
	
	shared Integer|Exception width =>
		if (exists cw = cachedWidth)
		then cw
		else
			let (width = () {
					value ds = dimensions;
					if (is [Integer, Integer] ds) {
						return ds[0];
					} else {
						return Exception(ds.message, ds);
					}
				})
				(cachedWidth = width());
	
	shared Integer|Exception height =>
		if (exists ch = cachedHeight)
		then ch
		else
			let (height = () {
					value ds = dimensions;
					if (is [Integer, Integer] ds) {
						return ds[1];
					} else {
						return Exception(ds.message, ds);
					}
				})
				(cachedHeight = height());
	
	shared actual Comparison compare(Image other) =>
		if (exists cc = cachedComparisons[other.path.string])
		then cc
		else
			let (comparison = () {
					if (mimeType == other.mimeType) {
						if (is Exception e = this.width) {
							throw e;
						} else if (is Exception e = other.width) {
							throw e;
						} else if (is Exception e = this.height) {
							throw e;
						} else if (is Exception e = other.height) {
							throw e;
						} else {
							assert (is Integer width = this.width,
								is Integer otherWidth = other.width,
								is Integer height = this.height,
								is Integer otherHeight = other.height);
							if (width == other.width, height == other.height) {
								value thisImage = bufferedImage;
								value otherImage = other.bufferedImage;
								if (is BufferedImage thisImage) {
									if (is BufferedImage otherImage) {
										try {
											for (x in 0:width) {
												for (y in 0:height) {
													value thisPixel = thisImage.getRGB(x, y);
													value otherPixel = otherImage.getRGB(x, y);
													if (thisPixel != otherPixel) {
														return smaller;
													}
												}
											}
										} finally {
											thisImage.flush();
											otherImage.flush();
										}
									} else {
										throw Exception("Cannot compare '``path``' with '``other.path``'. Cannot load image '``other.path``'.", otherImage);
									}
								} else {
									throw Exception("Cannot compare '``path``' with '``other.path``'. Cannot load image '``path``'.", thisImage);
								}
								return equal;
							} else {
								return width*height <=> otherWidth*otherHeight;
							}
						}
					} else {
						return mimeType <=> other.mimeType;
					}
				})
				(cachedComparisons[other.path.string] = comparison());
	
	shared actual Boolean equals(Object that) {
		if (is Image that) {
			return path.string == that.path.string;
		} else {
			return false;
		}
	}
	
	shared actual Integer hash {
		variable value hash = 1;
		hash = 31*hash + path.string.hash;
		return hash;
	}
	
	shared actual String string =>
		if (width is Integer, height is Integer)
		then "``path.string`` - ``width``x``height``"
		else "``path.string``";
}
