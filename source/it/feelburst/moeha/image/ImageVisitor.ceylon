import ceylon.collection {
	MutableMap,
	HashMap,
	ArrayList
}
import ceylon.file {
	Directory,
	File,
	Visitor
}

import it.feelburst.chihaya.concurrent.lock {
	Lock,
	Condition
}

import java.lang {
	Runnable
}
import java.util.concurrent {
	Future,
	ExecutorService,
	Executors,
	Callable
}

shared class ImageVisitor(ExecutorService executorService = Executors.newCachedThreadPool()) extends Visitor() {
	Lock lock = Lock();
	Condition isTerminated = lock.newCondition();
	variable MutableMap<[MimeType, Integer, Integer],{Image*}> imageLists = HashMap<[MimeType, Integer, Integer],{Image*}>();
	variable Boolean subdirectory = false;
	variable Boolean terminate = false;
	variable {Future<{<[MimeType, Integer, Integer]->{Image*}>*}>*} visitSubdirs = {};
	shared actual Boolean beforeDirectory(Directory dir) {
		// this subdirectory
		if (subdirectory) {
			visitSubdirs = visitSubdirs.chain({
					executorService.submit(object satisfies Callable<{<[MimeType, Integer, Integer]->{Image*}>*}> {
							shared actual {<[MimeType, Integer, Integer]->{Image*}>*} call() {
								value subdirectoryVisitor = ImageVisitor(executorService);
								dir.path.visit(subdirectoryVisitor);
								return subdirectoryVisitor.awaitTermination();
							}
						})
				});
			return false;
		} else {
			// this directory
			subdirectory = true;
			return true;
		}
	}
	shared actual void afterDirectory(Directory dir) {
		executorService.execute(object satisfies Runnable {
				shared actual void run() {
					value subdirsImages = visitSubdirs
						.collect((Future<{<[MimeType, Integer, Integer]->{Image*}>*}> visitSubdir) =>
							visitSubdir.get())
						.reduce(({<[MimeType, Integer, Integer]->{Image*}>*} partial,
							{<[MimeType, Integer, Integer]->{Image*}>*} element) {
							variable value merged = HashMap { entries = partial; };
							value it = element.iterator();
							while (!is Finished next = it.next()) {
								if (exists existingImages = merged[next.key]) {
									merged[next.key] = existingImages.chain(next.item);
								} else {
									merged[next.key] = next.item;
								}
							}
							return merged;
						});
					if (exists subdirsImages) {
						imageLists = HashMap { entries = subdirsImages; };
					}
					try (lock) {
						terminate = true;
						isTerminated.signal();
					}
				}
			});
	}
	shared actual void file(File file) {
		if (exists contentType = fromFile(file)) {
			value image = Image(file.path);
			if (is Integer width = image.width, is Integer height = image.height) {
				value key = [image.mimeType, width, height];
				if (exists list = imageLists[key]) {
					imageLists.put(key, list.chain({ image }));
				} else {
					imageLists.put(key, ArrayList<Image> { elements = { image }; });
				}
			}
		}
	}
	shared actual Boolean terminated => terminate;
	shared {<[MimeType, Integer, Integer]->{Image*}>*} awaitTermination(Anything onTermination(ExecutorService executorService) => null) {
		try (lock) {
			while (!terminate) {
				isTerminated.await();
			}
			onTermination(executorService);
			return imageLists;
		}
	}
}