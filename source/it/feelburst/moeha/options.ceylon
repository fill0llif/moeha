import ceylon.file {
	Path,
	parsePath,
	Directory,
	Nil
}
import ceylon.collection {
	MutableMap
}

abstract class Option(
	shared String option,
	shared Boolean optional = false,
	shared Path|Boolean|Null default(Map<Option,Path|Boolean|Null> options) => null) of inDirOption | outDirOption | updateOption {
	shared formal Path|Boolean|Null parseValue(String arg);
	shared formal void onOptionNotFound();
	
	shared Path? parseDirPath(String arg) {
		value pathname = String(arg.skip(option.size + 1));
		value path = parsePath(pathname);
		switch (resource = path.resource)
		case (is Directory) {
			log.info("Pathname '``pathname``' found.");
			return path;
		}
		case (is Nil) {
			log.error("Pathname '``pathname``' does not exist.");
			return null;
		}
		else {
			log.error("Pathname '``pathname``' is not a directory.");
			return null;
		}
	}
	
	shared Boolean? parseFlag(String arg) {
		value rawFlag = String(arg.skip(option.size + 1));
		if (rawFlag.empty) {
			return true;
		} else {
			value flag = Boolean.parse(rawFlag);
			if (is Boolean flag) {
				return flag;
			} else {
				log.error(flag.message);
				return null;
			}
		}
	}
	
	shared <Option->Path|Boolean|Null> process(String[] args) {
		if (exists entry = args.find((String element) => element.startsWith(option))) {
			value val = parseValue(entry);
			return this -> val;
		} else {
			onOptionNotFound();
			return this -> null;
		}
	}
	
	shared void processDefault(MutableMap<Option,Path|Boolean|Null> options) {
		if (options[this] is Null, optional) {
			options[this] = default(options);
		}
	}
	
	shared actual Boolean equals(Object that) {
		if (is Option that) {
			return option == that.option;
		} else {
			return false;
		}
	}
	
	shared actual Integer hash => option.hash;
	
	shared actual String string => option;
}

object inDirOption extends Option("--in-dir") {
	shared actual Path|Boolean|Null parseValue(String arg) => parseDirPath(arg);
	shared actual void onOptionNotFound() => log.error("No input directory found.");
}
object outDirOption extends Option("--out-dir", true, (Map<Option,Path|Boolean|Null> options) => options[inDirOption]) {
	shared actual Path|Boolean|Null parseValue(String arg) => parseDirPath(arg);
	shared actual void onOptionNotFound() => log.info("No output directory found.");
}
object updateOption extends Option("--update", true, (Map<Option,Path|Boolean|Null> options) => true) {
	shared actual Path|Boolean|Null parseValue(String arg) => parseFlag(arg);
	shared actual void onOptionNotFound() => log.warn("No update flag found.");
}
