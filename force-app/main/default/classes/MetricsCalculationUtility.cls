public class MetricsCalculationUtility {
	// constants
	static final String CASEHISTORY_MATRIXFIELD = 'TimeReported__c';

	@InvocableMethod(label = 'Metrics Calculation Utility')
	public static List<FlowOutputs> execute(List<FlowInputs> flowInputs) {
		List<FlowOutputs> returnList = new List<FlowOutputs> ();
		List<SObject> newHistoryRecordsList = new List<SObject>();
		String parentObject;
		String childObject;
		String parentObjFieldName;

		for (FlowInputs input : flowInputs) {
			newHistoryRecordsList.addAll(input.newHistoryRecordsListIn);
			parentObject = input.parentObjectIn;
			childObject = input.childObjectIn;
			parentObjFieldName = input.parentObjFieldNameIn;
		}

		calculateTimeReported(newHistoryRecordsList, parentObject, childObject, parentObjFieldName);

		FlowOutputs flowOut = new FlowOutputs();
		flowOut.successMessageOut = 'complete';
		returnList.add(flowOut);

		return returnList;
	}

	/**
	* ____________________________________________________
	* Method to calculate time reported on substatus change and Case History record creation
	* ____________________________________________________
	* @param	oldHistoryRecordMap		DESCRIPTION : A map of IDs to the old versions of the SObject records
	* @param	newHistoryRecordsList	DESCRIPTION : A List of new SObject records
	* @param	parentObject			DESCRIPTION : Parent relation object like Case API names to be passed
	* @param	childObject				DESCRIPTION : Child relation object like CaseHistory__c API names to be passed
	* @param	parentObjFieldName		DESCRIPTION : Parent relation Lookup/Master field API Name eg. CaseId__c
	* @return	TYPE	List<SObject>
	* ____________________________________________________________________
	**/
	public static void calculateTimeReported(List<SObject> newHistoryRecordsList, String parentObject, String childObject, String parentObjFieldName) {
		String recordTypeName;
		Set<String> parentRecordIdSet = new Set<String>(); // Set to store all parent Object Record Ids eg. Case
		Set<String> parentRecordAccountIdSet = new Set<String>(); // Set to store all parent Object Account Record Ids
		Map<String, String> sobjectIdRecordTypeMap = new Map<String, String>(); // a map to store parent record ID and its recordType DeveloperName
		Set<String> recordTypeSet = new Set<String>(); // A set to store all splitted recordType name from custom metadata record
		Map<String, Metrics_Calculations__mdt> mCalculationsMap = new Map<String, Metrics_Calculations__mdt>();// Custom Metadata records retrieval
		List<SObject> objToupdateList = new List<SObject>(); // Create a List Of SObject with records which needs to be updated
		Boolean metricsCalcRecordsUtilizeRT = false; 
        
		try {
			/* Iterate on all Metadata records and create a map with Unique Key Value Pair Where Key =
			* (parentObject + childObject + ChangedField) and Value = Metrics_Calculations__mdt metadata record
			*/
			for (Metrics_Calculations__mdt mCalc : Metrics_Calculations__mdt.getAll().values()) {
				String key = mCalc.parentObject__c + '_' + mCalc.childObject__c + '_' + mCalc.ChangedField__c;

				system.debug('mCalc.parentObject__c: '+mCalc.parentObject__c);
                system.debug('parentObject: '+parentObject);
                system.debug(mCalc.parentObject__c == parentObject);
                system.debug('mCalc.childObject__c: '+mCalc.childObject__c);
                system.debug('childObject: '+childObject);
                system.debug(mCalc.childObject__c == childObject);
                system.debug('mCalc.RecordType__c: '+mCalc.RecordType__c);
                system.debug(mCalc.RecordType__c != null);
                if (mCalc.parentObject__c == parentObject && mCalc.childObject__c == childObject &&  mCalc.RecordType__c != null) {
					String recordTypeStr = String.valueOf(mCalc.RecordType__c);
					recordTypeSet.addAll(recordTypeStr.split(','));
					metricsCalcRecordsUtilizeRT = true; 
				}
				mCalculationsMap.put(key, mCalc);
			}

			// Iterate on all modified records and save all Main Object (Parent) record Ids in a set
			for (SObject obj : newHistoryRecordsList) {
				parentRecordIdSet.add(String.valueOf(obj.get(parentObjFieldName)));
			}

			// Iterate to store parent record ID and its recordType DeveloperName in sobjectIdRecordTypeMap map
			for (SObject obj : Database.query('select Id ' + (metricsCalcRecordsUtilizeRT ? ', RecordTypeId' : '') + ' from ' + parentObject + ' where Id in :parentRecordIdSet')) {
				if (metricsCalcRecordsUtilizeRT) {
					sobjectIdRecordTypeMap.put((String)obj.get('Id'), (String)obj.get('RecordTypeId'));
				}
			}

			Set<String> changedFieldsSet = new Set<String>();
			for (SObject obj : newHistoryRecordsList) {
				changedFieldsSet.add((String)obj.get('ChangedField__c'));
			}

			// Get second last history record with substatus change which will be used for calcualting the time difference
			Map<String, SObject> sobjectwithHistoryMap = getSecondLastModifiedRecord(parentRecordIdSet, childObject, parentObjFieldName, changedFieldsSet);

			Map<Id, RecordTypeInfo> rtInfoMap;
			if (metricsCalcRecordsUtilizeRT) {
				Id parentRecId = (Id)newHistoryRecordsList[0].get(parentObjFieldName);
				rtInfoMap = parentRecId.getSobjectType().getDescribe().getRecordTypeInfosById();
			}

			/* Iterate on all new Records and match with unique Key created above (parentObject + childObject + ChangedField)
			if map contains the value then Pull the field mapping (Mapped Custom field API Name) from metadata which needs to be
			calculated and set the Calculated difference value on that field.
			*/
			for (SObject obj : newHistoryRecordsList) {
				system.debug('sobjectIdRecordTypeMap.get((String)obj.get(parentObjFieldName)): '+sobjectIdRecordTypeMap.get((String)obj.get(parentObjFieldName)));    
				system.debug('parentObjFieldName: '+parentObjFieldName);                         
				if (metricsCalcRecordsUtilizeRT) {
					recordTypeName = rtInfoMap.get(sobjectIdRecordTypeMap.get((String)obj.get(parentObjFieldName))).getDeveloperName();
				}

				// Calculation Logic to be executed only for the matching recordType of Parent record and Custom Metadata stored recordType developerName
				system.debug('recordTypeSet: '+recordTypeSet);
				system.debug('recordTypeName: '+recordTypeName);
				system.debug('metricsCalcRecordsUtilizeRT: '+metricsCalcRecordsUtilizeRT);
				if (recordTypeSet.contains(recordTypeName) || !metricsCalcRecordsUtilizeRT) { 
					String key = parentObject + '_' + childObject + '_' + String.valueOf(obj.get('ChangedField__c'));
					if (!mCalculationsMap.containsKey(key)) {
						key = parentObject + '_' + childObject + '_' + String.valueOf(obj.get('ChangedField__c'));
					}

					// check if custom metadata map contains key prepared from history record
					if (mCalculationsMap.containsKey(key)) {
						DateTime lmd; // LastModifiedDate of second last history record
						String historyKey = obj.get(parentObjFieldName) + '_' + obj.get('ChangedField__c'); 
                        if (!sobjectwithHistoryMap.isEmpty() && sobjectwithHistoryMap.containsKey(historyKey)) {
							lmd = (DateTime)sobjectwithHistoryMap.get(historyKey).get('LastModifiedDate'); 
                        } else {
							lmd = null;
						}

						Id businessHourId;
						if (mCalculationsMap.get(key).BusinessHourId__c.startsWith('01m')) {
							businessHourId = mCalculationsMap.get(key).BusinessHourId__c;
						} else {
							String businessHourStr = mCalculationsMap.get(key).BusinessHourId__c;
							List<BusinessHours> busHourList = [select Id from BusinessHours where Name = :businessHourStr Limit 1];
							businessHourId = busHourList[0].Id;
						}

						// Set calculated difference under field TimeReported__c
						obj.put(CASEHISTORY_MATRIXFIELD, getCalculatedTime(lmd, DateTime.now(), businessHourId, mCalculationsMap.get(key).TimeReportedUnits__c, mCalculationsMap.get(key).UnroundedDays__c, mCalculationsMap.get(key).X24HourDay__c));
						objToupdateList.add(obj);
					} else {
						objToupdateList.add(obj);
					}
				} else {
					objToupdateList.add(obj);
				}
			}
			if (!objToupdateList.isEmpty()) {
				insert objToupdateList;
			}
		} catch (Exception e) {
			System.debug('Exception Thrown Class : MetricsCalculationUtility : ' + e.getMessage() + ' -- ' + e.getLineNumber());
		}
	}

	@TestVisible
	private static Map<String, SObject> getSecondLastModifiedRecord(Set<String> parentRecordIdSet, String childObject, String parentObjFieldName, Set<String> changedFieldsSet) {
		// Retrieve all History record except the one which is recently created
		List<SObject> historyRecordList = Database.Query('select LastModifiedDate, ChangedField__c, OldValue__c, NewValue__c,' + parentObjFieldName + ' from ' + childObject + ' where ' + parentObjFieldName + ' in :parentRecordIdSet and ChangedField__c in :changedFieldsSet order by LastModifiedDate desc');
		Map<String, SObject> sobjectwithHistoryMap = new Map<String, SObject>(); // map to store parent

		for (SObject rec : historyRecordList){
			String historyKey = rec.get(parentObjFieldName) + '_' + rec.get('ChangedField__c'); 
			if (sobjectwithHistoryMap.isEmpty() || !sobjectwithHistoryMap.containsKey(historyKey)) {
				sobjectwithHistoryMap.put(historyKey, rec);
			}
		}
		return sobjectwithHistoryMap;
	}

	@TestVisible
	private static Decimal getCalculatedTime(DateTime lastModifiedTime, DateTime endDate, String businessHourId, String conversionFormat, Boolean unroundedDays, Boolean fullDay) {
		// if Case History Record is fresh new then return reported time as 0
		if (lastModifiedTime == null) {
			return 0.00;
		}
        
        Date lmDate = lastModifiedTime.date();
        Date eDate = endDate.date();
        Integer holidayCount = 0;
        
        for (Company_Holiday__c ch : [select Id, Date__c from Company_Holiday__c where Date__c >= :lmDate and Date__c <= :eDate]){
            if (ch.Date__c == eDate) {
                endDate = Datetime.newInstance(eDate.year(), eDate.month(), eDate.day()-1, 23, 59, 59);
            } else if (ch.Date__c == lmDate) {
                lastModifiedTime = Datetime.newInstance(lmDate.year(), lmDate.month(), lmDate.day(), 23, 59, 59);
            } else {
                holidayCount += 1;
            }
        }
        
        if (lastModifiedTime > endDate) {
            return 0;
        }

        Decimal milisc = BusinessHours.diff(businessHourId, lastModifiedTime, endDate);
        if (holidayCount > 0) {
            if (fullDay) {
                milisc = milisc - (holidayCount * 86400000);
            } else {
                milisc = milisc - (holidayCount * 43200000);
            }
        }
        Decimal mins = milisc / 60000;
		Decimal hours = (mins / 60).setScale(2);
		Decimal days;
		if (fullDay) {
			days = (hours / 24).setScale(2);
		} else {
			days = (hours / 12).setScale(2);
		}
		if (!unroundedDays) {
			days = days.round(System.RoundingMode.FLOOR);
        }
        system.debug('milisc: '+milisc);
        system.debug('mins: '+mins);
        system.debug('hours: '+hours);
        system.debug('days: '+days);
        
        if (conversionFormat == 'Integer Minutes') {
            return Integer.valueOf(mins);
        } else if (conversionFormat == 'Decimal Minutes') {
            return mins.setScale(2);
        } else if (conversionFormat == 'Integer Hours') {
            return Integer.valueOf(hours);
        } else if (conversionFormat == 'Decimal Hours') {
            return hours.setScale(2);
        } else if (conversionFormat == 'Integer Days') {
            return Integer.valueOf(days);
        } else if (conversionFormat == 'Decimal Days') {
            system.debug(' return days: '+days);
            return days.setScale(2);
		} else {
			return null;
		}
	}

	public static List<Decimal> calculateTime(List<CalculationData> dataList, String parentObject, String childObject) {
		List<Decimal> outputList = new List<Decimal>();
		Set<String> recordTypeSet = new Set<String>(); // A set to store all splitted RecordType name from Custom Metadata record
		Map<String, Metrics_Calculations__mdt> mCalculationsMap = new Map<String, Metrics_Calculations__mdt>(); // Custom Metadata records retrieval
		Map<String, Id> businessHourMap = new Map<String, Id>(); // Map identifying businessHourIds per DeveloperName

		try {
			// Prevent function from proceeding if null values are in the CalculationData
			List<String> nullValues = new List<String>();
			for (CalculationData data : dataList) {
				if (data.startDate == null) {
					nullValues.add('startDate');
				}
				if (data.endDate == null) {
					nullValues.add('endDate');
				}
				if (data.changedField == null) {
					nullValues.add('changedField');
				}
				if (nullValues.size() > 0) {
					throw new IllegalArgumentException('CalculationData object contains null data in necessary fields (' + String.join(nullValues, ', ') + ')');
				}
			}

			// Iterate on all Metadata records and create a map with unique key-value pair
			// - Key = (ParentObject + ChildObject + ChangedField)
			// - Value = Metrics_Calculations__mdt metadata record
			Set<String> businessHourStrSet = new Set<String>();
			for (Metrics_Calculations__mdt mCalc : Metrics_Calculations__mdt.getAll().values()) {
				String key = mCalc.ParentObject__c + '_' + mCalc.ChildObject__c + '_' + mCalc.ChangedField__c;

				if (mCalc.ParentObject__c == parentObject && mCalc.ChildObject__c == childObject && mCalc.RecordType__c != null) {
					recordTypeSet.addAll(String.valueOf(mCalc.RecordType__c).split(','));
				}
				mCalculationsMap.put(key, mCalc);
				businessHourStrSet.add(mCalc.BusinessHourId__c);
			}

			// Pre-calculate the BusinessHour Ids per DeveloperName
			for (BusinessHours businessHour : [select Id, Name from BusinessHours where Name in :businessHourStrSet]) {
				businessHourMap.put(businessHour.Name, businessHour.Id);
			}

			// Iterate on all CalculationData and match with unique key created above (ParentObject + ChildObject + ChangedField)
			// - If map contains the value then pull the field mapping (Mapped Custom field API Name) from metadata which needs to be calculated and add the calculated difference value to the output list.
			for (CalculationData data : dataList) {
				Decimal output = null;
				String recordTypeName = data.recordTypeDeveloperName;

				// Calculation Logic to be executed only for the matching recordType of parent record and Custom Metadata stored RecordType DeveloperName
				if (recordTypeSet.isEmpty() || recordTypeSet.contains(recordTypeName)) {
					String key = parentObject + '_' + childObject + '_' + data.changedField;

					// Check if custom metadata map contains key prepared from data record
					if (mCalculationsMap.containsKey(key)) {
						Metrics_Calculations__mdt mCalc = mCalculationsMap.get(key);
						Id businessHourId;
						if (mCalc.BusinessHourId__c.startsWith('01m')) {
							businessHourId = mCalc.BusinessHourId__c;
						} else {
							businessHourId = businessHourMap.get(mCalc.BusinessHourId__c);
						}

						// Add calculated difference as result for this CalculationData
						system.debug('data.startDate: '+data.startDate);
						system.debug('data.endDate: '+data.endDate);
						system.debug('businessHourId: '+businessHourId);
						system.debug('mCalc.TimeReportedUnits__c: '+mCalc.TimeReportedUnits__c);
						system.debug('mCalc.UnroundedDays__c: '+mCalc.UnroundedDays__c);
						system.debug('mCalc.X24HourDay__c: '+mCalc.X24HourDay__c);
						output = getCalculatedTime(data.startDate, data.endDate, businessHourId, mCalc.TimeReportedUnits__c, mCalc.UnroundedDays__c, mCalc.X24HourDay__c);
					}
				}
				outputList.add(output);
			}
			return outputList;
		} catch (Exception e) {
			System.debug('Exception Thrown Class : MetricsCalculationUtility.calculateTime : ' + e.getMessage() + ' -- ' + e.getLineNumber());
			return new List<Decimal>();
		}
	}
    
    public static List<CalculationData> getCalculationData(List<SObject> newHistoryRecordsList, String parentObject, String childObject, String parentObjFieldName) {
		List<CalculationData> outputList = new List<CalculationData>();
		Set<String> parentRecordIdSet = new Set<String>(); // Set to store all parent Object Record Ids eg. Case
		Set<String> changedFieldsSet = new Set<String>();
		Map<String, String> sobjectIdRecordTypeMap = new Map<String, String>(); // A map to store parent record ID and its recordType DeveloperName

		try {
			// Iterate on all modified records and save all Main Object (Parent) record Ids in a set
			for (SObject obj : newHistoryRecordsList) {
				parentRecordIdSet.add(String.valueOf(obj.get(parentObjFieldName)));
				changedFieldsSet.add((String)obj.get('ChangedField__c'));
			}

			// Iterate to store parent record ID and its recordType DeveloperName in sobjectIdRecordTypeMap map
			for (SObject obj : Database.query('select Id , RecordTypeId' + ' from ' + parentObject + ' where Id in :parentRecordIdSet')) {
				sobjectIdRecordTypeMap.put((String)obj.get('Id'), (String)obj.get('RecordTypeId'));
			}

			// Get second last history record with substatus change which will be used for calcualting the time difference
			Map<String, SObject> sobjectwithHistoryMap = getSecondLastModifiedRecord(parentRecordIdSet, childObject, parentObjFieldName, changedFieldsSet);

			Map<Id, RecordTypeInfo> rtInfoMap = ((Id)newHistoryRecordsList[0].get(parentObjFieldName)).getSobjectType().getDescribe().getRecordTypeInfosById();

			/* Iterate on all new Records and match with unique Key created above (parentObject + childObject + ChangedField)
			if map contains the value then Pull the field mapping (Mapped Custom field API Name) from metadata which needs to be
			calculated and set the Calculated difference value on that field.
			*/
			for (SObject obj : newHistoryRecordsList) {
				String recordTypeName = rtInfoMap.get(sobjectIdRecordTypeMap.get((String)obj.get(parentObjFieldName))).getDeveloperName();

				DateTime lmd = null;  // LastModifiedDate of second last history record
				String historyKey = obj.get(parentObjFieldName) + '_' + obj.get('ChangedField__c');
				if (!sobjectwithHistoryMap.isEmpty() && sobjectwithHistoryMap.containsKey(historyKey)) {
					lmd = (DateTime)sobjectwithHistoryMap.get(historyKey).get('LastModifiedDate');
				}

				outputList.add(new CalculationData(
					lmd != null ? lmd : DateTime.now(),
					DateTime.now(),
					String.valueOf(obj.get('ChangedField__c')),
					recordTypeName
				));
			}
			return outputList;
		} catch (Exception e) {
			System.debug('Exception Thrown Class : MetricsCalculationUtility.getCalculationData : ' + e.getMessage() + ' -- ' + e.getLineNumber());
			return new List<CalculationData>();
		}
	}
	
	public class CalculationData {
		public DateTime startDate;
		public DateTime endDate;
		public String changedField;
		public String RecordTypeDeveloperName;

		public CalculationData(DateTime startDate, DateTime endDate, String changedField, String recordTypeDeveloperName) {
			this.startDate = startDate;
			this.endDate = endDate;
			this.changedField = changedField;
			this.recordTypeDeveloperName = recordTypeDeveloperName;
		}
	}

	//input details that comes to apex from flow
	public class FlowInputs {
		@InvocableVariable(label = 'List of New History Records' required = true)
		public List<Sobject> newHistoryRecordsListIn;

		@InvocableVariable(label = 'Parent Object API Name' required = true)
		public String parentObjectIn;

		@InvocableVariable(label = 'History Object API Name' required = true)
		public String childObjectIn;

		@InvocableVariable(label = 'Lookup Field (API name) to Parent Object"' required = true)
		public String parentObjFieldNameIn;
	}

	public class FlowOutputs {
		@InvocableVariable(label = 'RecordType Id (Single)')
		public String successMessageOut;
	}
}