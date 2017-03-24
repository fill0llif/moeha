import ceylon.logging {
	Logger,
	logger,
	addLogWriter,
	writeSimpleLog,
	info
}

Logger log =
	let (added = addLogWriter(writeSimpleLog))
		let (log = logger(`package it.feelburst.moeha.image`))
			let (priority = log.priority = info)
				log;
