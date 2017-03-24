import ceylon.collection {
	HashMap
}
import ceylon.file {
	Path,
	Directory,
	File,
	Nil
}

import it.feelburst.moeha.image {
	Image,
	ImageVisitor,
	MimeType
}

import java.util.concurrent {
	ExecutorService
}

"Run the module `it.feelburst.moeha`."
shared void run() {
	value options = HashMap<Option,Path|Boolean|Null>();
	{ inDirOption, outDirOption, updateOption }
		.each((Option option) =>
			options.putAll({ option.process(process.arguments) }));
		
	{ inDirOption, outDirOption, updateOption }
		.each((Option option) => option.processDefault(options));
		
	assert (is Path inDirPath = options.get(inDirOption));
	assert (is Path outDirPath = options.get(outDirOption));
	assert (is Boolean updateFlag = options.get(updateOption));
	
	assert (is Directory inDir = inDirPath.resource);
	assert (is Directory outDir = outDirPath.resource);
	
	// Find and retrieve images
	value directoryVisitor = ImageVisitor();
	inDir.path.visit(directoryVisitor);
	{<[MimeType, Integer, Integer]->{Image*}>*} imageListsByMimeWidthHeight = directoryVisitor
		.awaitTermination((ExecutorService executorService) => executorService.shutdown());
	
	// Evaluate duplicates
	value action = DuplicatesAction<Image>(
		imageListsByMimeWidthHeight, 
		(Image original -> [Image*] duplicates) {
			value deleteAndLinkDuplicates = (File original,[File*] duplicates) {
				duplicates.each((File duplicate) {
					value duplicateDeletedFile = duplicate.delete();
					original.createSymbolicLink(duplicateDeletedFile);
					log.info("Duplicate file ``duplicateDeletedFile.path.string`` of ``original.path.string`` deleted and linked.");
				});
			};
			if (outDir.path != inDir.path) {
				value relativePathToInDir = inDir.path.relativePath(original.path);
				value relativePathToOutDir = outDir.path.childPath(relativePathToInDir);
				value resource = relativePathToOutDir.resource;
				assert (is Nil|File resource);
				if (is Nil resource) {
					value originalFile = original.file();
					value copiedFile = originalFile.copy(resource);
					value originalDeletedFile = originalFile.delete();
					copiedFile.createSymbolicLink(originalDeletedFile);
					deleteAndLinkDuplicates(copiedFile,duplicates.collect((Image image) => image.file()));
				} else {
					log.warn("Cannot copy and link file '``original.path.string``' from '``inDir.path.string``' to '``outDir.path.string``'.
					          The resource '``resource.path.string``' already exists. Are both of them the same exact file?");
				}
			} else {
				deleteAndLinkDuplicates(original.file(),duplicates.collect((Image image) => image.file()));
			}
		});
	action.run();
}
