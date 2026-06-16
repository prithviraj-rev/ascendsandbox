global class populateCaseTimeOpenBatch implements Database.Batchable<SObject> {
	global String m_Query;
	Id appCasesId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('App_Cases').getRecordTypeId();
	
	global List<Case> start(Database.BatchableContext BC) {
		DateTime rightNow =  DateTime.now();
		DateTime days = rightNow.addHours(-72);
		//m_Query = 'select Id, OldValue__c, NewValue__c, ChangedField__c, TimeReported__c, IsTimeSpentTracker__c, CaseId__c, CreatedDate, CaseRecordType__c';
		//m_Query += ' from DurationTracking__c where CaseId__c != null and (CaseId__r.IsClosed = FALSE or CaseId__r.ClosedDate > :days) order by CreatedDate desc';
		m_Query = 'select Id, Status, ClosedDate, CreatedDate, Account.BillingCountry, IsClosed, CaseNumber, RecordType.DeveloperName';
        m_Query += ' from Case where AccountId != null and ((Status = \'Closed\' and ClosedDate > :days) or Status != \'Closed\') and RecordTypeId = :appCasesId';
        
        if (Test.isRunningTest()) {
			m_Query = 'select Id, Status, ClosedDate, CreatedDate, Account.BillingCountry, IsClosed, CaseNumber, RecordType.DeveloperName'
			+ ' from Case where RecordTypeId = :appCasesId';
		}
		return Database.query(m_Query);
	}

	//global void execute(Database.BatchableContext BC, List<DurationTracking__c> dtLists) {
	global void execute(Database.BatchableContext BC, List<Case> caseLists) {
		Set<Id> caseIdSet = new Set<Id>();
		for (Case obj : caseLists) {
				caseIdSet.add(obj.Id);
		}
		List <DurationTracking__c> caseHistory = [
			select IsTimeSpentTracker__c, CreatedDate, OldValue__c, CaseId__c, NewValue__c, TimeReported__c
			from DurationTracking__c
			where ChangedField__c = 'Status' and CaseId__c in :caseIdSet
			order by CreatedDate desc
		];
		//Map<Id, DurationTracking__c> mapOnHoldHistory = getUnderInvestigationHistoryMap(caseHistory);
		Map<Id, DurationTracking__c> mapTimeSpentTrackerHistory = getTimeSpentTrackerHistoryMap(caseHistory);

		List<DurationTracking__c> recalculatedHistory = new List<DurationTracking__c>();

		List<MetricsCalculationUtility.CalculationData> dataList = new List<MetricsCalculationUtility.CalculationData>();
        for (Case caseVar : caseLists) {
            DurationTracking__c lastHistory = mapTimeSpentTrackerHistory.get(caseVar.Id);
            Datetime startDate;
            if (lastHistory == null) {
                startDate = caseVar.CreatedDate;
            } else {
                startDate = lastHistory.CreatedDate;
            }
            dataList.add(new MetricsCalculationUtility.CalculationData(startDate, Datetime.now(), 'Status', 'App_Cases'));
        }
		List<Decimal> timeList = MetricsCalculationUtility.calculateTime(dataList, 'Case', 'DurationTracking__c');
		for (Integer i = 0; i < timeList.size(); i++) {
			if (timeList[i] != null) {
				Case caseVar = caseLists[i];
				DurationTracking__c timeSpentTracker = mapTimeSpentTrackerHistory.get(caseVar.Id);
				if (timeSpentTracker == null || timeSpentTracker.IsTimeSpentTracker__c == false) {
                    timeSpentTracker = new DurationTracking__c();
                    timeSpentTracker.CaseId__c = caseVar.Id;
                    timeSpentTracker.ChangedField__c = 'Status';
                    timeSpentTracker.OldValue__c = caseVar.Status;
                    timeSpentTracker.NewValue__c = null;
                    timeSpentTracker.IsTimeSpentTracker__c = true;
                    timeSpentTracker.CaseRecordType__c = caseVar.RecordType.DeveloperName;
                }
                timeSpentTracker.TimeReported__c = timeList[i];
                recalculatedHistory.add(timeSpentTracker);
			}
		}
		system.debug(recalculatedHistory);
		upsert recalculatedHistory;
	}

	/*private Map<Id, DurationTracking__c> getUnderInvestigationHistoryMap(List<DurationTracking__c> caseHistory) {
		Map<Id, DurationTracking__c> mapHistoryByCase = new Map<Id, DurationTracking__c>();
		for (DurationTracking__c obj : caseHistory) {
			if (obj.IsTimeSpentTracker__c == true) {
				continue;
			}
			if (mapHistoryByCase.get(obj.CaseId__c) == null) {
				mapHistoryByCase.put(obj.CaseId__c, obj);
			}
		}
		return mapHistoryByCase;
	}*/

	private Map<ID, DurationTracking__c> getTimeSpentTrackerHistoryMap(List<DurationTracking__c> caseHistory) {
		Map<Id, DurationTracking__c> mapHistoryByCase = new Map<Id, DurationTracking__c>();
        for (DurationTracking__c obj : caseHistory) {
            if (mapHistoryByCase.get(obj.CaseId__c) == null) {
                mapHistoryByCase.put(obj.CaseId__c, obj);
            }
        }
		return mapHistoryByCase;
	}

	global void finish(Database.BatchableContext BC) {
	}
}