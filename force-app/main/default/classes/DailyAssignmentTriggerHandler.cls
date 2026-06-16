/******************************************************************************
// Summary:         The trigger handler class for Daily_Assignment__c custom object
// Test Class:      DailyAssignmentTriggerHandlerTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 06/10/2024 - created
*******************************************************************************/

public with sharing class DailyAssignmentTriggerHandler extends AbstractTrigger
{
    public override void beforeUpdate(List<SObject> records, List<SObject> oldRecords) {
        //checkLocked((List<Daily_Assignment__c>)records, (List<Daily_Assignment__c>)oldRecords);
        setLocked((List<Daily_Assignment__c>)records, (List<Daily_Assignment__c>)oldRecords);
    }

    public override void beforeDelete(List<SObject> oldRecords) {
        //checkLocked(null, (List<Daily_Assignment__c>)oldRecords);
    }

    public override void afterInsert(List<SObject> records) {
    	updateCardsDailyAssignment((List<Daily_Assignment__c>)records, null);
    }
    
    public override void afterUpdate(List<SObject> records, List<SObject> oldRecords) {
    	updateCardsDailyAssignment((List<Daily_Assignment__c>)records, (List<Daily_Assignment__c>)oldRecords);
    }
    /*
    private void checkLocked(List<Daily_Assignment__c> records, List<Daily_Assignment__c> oldRecords) {
        if(RPRFAssignmentService.isDailyAssignmentAutomationRan) return;
        
        if(records == null) {
            for(Daily_Assignment__c record : oldRecords) {
                if(record.Locked__c == true) {
                    record.addError('The Daily Assignment record is locked. You can\'t delete it.');
                }
            }
        } else {
            for(Integer i = 0; i < records.size(); i++) {
                if(records[i].Locked__c == true && oldRecords[i].Locked__c == true) {
                    records[i].addError('The Daily Assignment record is locked. You can\'t modify it.');
                }
            }
        }
    }
    */

    private void setLocked(List<Daily_Assignment__c> records, List<Daily_Assignment__c> oldRecords) {
        if(RPRFAssignmentService.isDailyAssignmentAutomationRan) return;

        for(Integer i = 0; i < records.size(); i++) {
            if(records[i].Actual_Hours__c != oldRecords[i].Actual_Hours__c || records[i].Projected_Hours__c != oldRecords[i].Projected_Hours__c) {
                records[i].Locked__c = true;
                records[i].Lock_Reason__c = 'Locked due to manual Projected/Actual hours update by ' + UserInfo.getName();
                records[i].Locked_By__c = UserInfo.getUserId();
            }

            if(records[i].Locked__c == false) {
                records[i].Lock_Reason__c = null;
                records[i].Locked_By__c = null;
            }
        }
    }

    private void updateCardsDailyAssignment(List<Daily_Assignment__c> records, List<Daily_Assignment__c> oldRecords) {
        Map<Id, Daily_Assignment__c> oldMap = (oldRecords == null ? new Map<Id, Daily_Assignment__c>() : new Map<Id, Daily_Assignment__c>(oldRecords));
        Set<Id> assignmentsIds = new Set<Id>();
        Set<Date> dates = new Set<Date>();
        Map<String, String> mapDailyAssignments = new Map<String, String>();
        
        for (Daily_Assignment__c dailyAssignment : records) {
            Daily_Assignment__c oldDailyAssignment = (oldMap.get(dailyAssignment.Id) == null ? new Daily_Assignment__c() : oldMap.get(dailyAssignment.Id));
            if (dailyAssignment.Daily_Date__c != oldDailyAssignment?.Daily_Date__c || dailyAssignment.Assignment__c != oldDailyAssignment?.Assignment__c) {
                if (dailyAssignment.Daily_Date__c != null) dates.add(dailyAssignment.Daily_Date__c);
                if (oldDailyAssignment.Daily_Date__c != null) dates.add(oldDailyAssignment.Daily_Date__c);
                if (dailyAssignment.Assignment__c != null) assignmentsIds.add(dailyAssignment.Assignment__c);
                if (oldDailyAssignment.Assignment__c != null) assignmentsIds.add(oldDailyAssignment.Assignment__c);
                if (oldDailyAssignment.Assignment__c != null && oldDailyAssignment.Daily_Date__c != null) {
                    mapDailyAssignments.put(oldDailyAssignment.Assignment__c + String.valueOf(oldDailyAssignment.Daily_Date__c), 'clear');
                }

                mapDailyAssignments.put(dailyAssignment.Assignment__c + String.valueOf(dailyAssignment.Daily_Date__c), dailyAssignment.Id);
            }
        }

        if (assignmentsIds.size() == 0 || dates.size() == 0) return;

        List<SFDC_Timecard__c> updatedTimeCards = new List<SFDC_Timecard__c>();
        List<SFDC_Timecard__c> timeCards = [Select Date__c, Assignment__c, Daily_Assignment__c From SFDC_Timecard__c Where Assignment__c In :assignmentsIds And Date__c In :dates];
        for (SFDC_Timecard__c timeCard : timeCards) {
            String key = timeCard.Assignment__c + String.valueOf(timeCard.Date__c);
            String dailyAssignmentId = mapDailyAssignments.get(key);
            if (dailyAssignmentId == 'clear') {
                timeCard.Daily_Assignment__c = null;
                updatedTimeCards.add(timeCard);
            } else if (dailyAssignmentId != null) {
                timeCard.Daily_Assignment__c = dailyAssignmentId;
                updatedTimeCards.add(timeCard);
            }
        }

        try{
            AbstractTrigger.Disabled = true;
            update updatedTimeCards;
        }finally{
            AbstractTrigger.Disabled = false;
        }
    }
}