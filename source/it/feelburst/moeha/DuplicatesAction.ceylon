import it.feelburst.moeha.image {
	MimeType
}

import java.lang {
	Runnable
}
import java.util.concurrent {
	Future,
	ExecutorService,
	Executors
}

shared class DuplicatesAction<Element>(
	{<[MimeType, Integer, Integer]->{Element*}>*} elements, 
	void do(Element->[Element*] duplicates)) 
	satisfies Runnable
	given Element satisfies Comparable<Element> {

	ExecutorService executorService = Executors.newFixedThreadPool(8);
	
	shared actual void run() {
		value noErrorsDuplicatesAction = elements.collect(([MimeType, Integer, Integer] mimeWidthHeight -> {Element*} elements) =>
			let (unpaired = elements.sequence())
			let (same = (Element lhs, Element rhs) => lhs <=> rhs == equal)
			let (filterPairWithSame = filterPair(same))
			let (mergePairWithSame = mergePair(same))
			executorService.submit(object satisfies Runnable {
				shared actual void run() {
					value paired = filterPairWithSame(unpaired);
					value duplicates = mergePairWithSame(paired);
					duplicates.each(do);
				}
			},true));
		if(!noErrorsDuplicatesAction.every((Future<Boolean> duplicatesFuture) => duplicatesFuture.get())) {
			log.error("An error occurred while processing the action.");
		}
		executorService.shutdown();
	}

	Element[2][] filterPair(Boolean filter(Element lhs, Element rhs))([Element*] elements) {
		variable Element[2][] filteredElements = [];
		(0 : elements.size-1).each((Integer i) {
			(i+1 : elements.size - (i + 1)).each((Integer j) {
				if (exists lhs = elements[i], exists rhs = elements[j]) {
					try {
						if (filter(lhs, rhs)) {
							filteredElements = filteredElements.withTrailing([lhs, rhs]);
						}
					} catch (Exception e) {
						log.error(e.message);
					}
				}
			});
		});
		return filteredElements;
	}
	
	{<Element->[Element*]>*} mergePair(Boolean merge(Element lhs,Element rhs))(Element[2][] elements) {
		variable {<Element->[Element*]>*} merged = []; 
		elements.each((Element[2] pair) {
			value lhs = pair.first;
			value rhs = pair.last;
			try {
				if (exists prevMerged = merged.find((Element l -> [Element*] r) => merge(l,lhs))) {
					merged = merged
							.filter((Element l -> [Element*] r) => !merge(l,lhs));
					value l = prevMerged.key;
					value r =
							if (prevMerged.item.contains(rhs) || l == rhs)
					then prevMerged.item
					else prevMerged.item.withTrailing(rhs);
					merged = merged.chain({l->r});
				} else {
					merged = merged.chain({lhs->[rhs]});
				}
			} catch (Exception e) {
				log.error(e.message);
			}
		});
		return merged;
	}
	
}
