/******************************************************************************
// Summary:         The trigger handler class for SFDC_Timecard__c custom object
// Test Class:      TimecardTriggerHandlerTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 05/09/2024 - created
*******************************************************************************/

public with sharing class TimecardTriggerHandler extends AbstractTrigger
{
    public override void beforeInsert(List<SObject> records) {
    	populateDailyAssignment((List<SFDC_Timecard__c>)records, null);
    }
    
    public override void beforeUpdate(List<SObject> records, List<SObject> oldRecords) {
    	populateDailyAssignment((List<SFDC_Timecard__c>)records, (List<SFDC_Timecard__c>)oldRecords);
    }

    public override void afterInsert(List<SObject> records) {
    	processFTOTimecards((List<SFDC_Timecard__c>)records, null);
    }
    
    public override void afterUpdate(List<SObject> records, List<SObject> oldRecords) {
    	processFTOTimecards((List<SFDC_Timecard__c>)records, (List<SFDC_Timecard__c>)oldRecords);
    }

    public override void afterDelete(List<SObject> oldRecords) {
    	processFTOTimecards(null, (List<SFDC_Timecard__c>)oldRecords);
    }

    /*
    private void processDailyAssignmentTimecards(List<SFDC_Timecard__c> records, List<SFDC_Timecard__c> oldRecords) {
        Map<ID, Project_Line_Item__c> holidaysProjectLines = new Map<ID, Project_Line_Item__c>(RPRFResourceService.getInstance().getHolidaysProjectLines());
        
        List<SFDC_Timecard__c> cards = (records != null ? records : oldRecords);
        Set<ID> assignmentsIds = new Set<ID>();
        for(SFDC_Timecard__c card : cards) {
            assignmentsIds.add(card.Assignment__c);
        }

        if(assignmentsIds.isEmpty()) return;

        Map<ID, SFDC_Assignment__c> assignments = new Map<ID, SFDC_Assignment__c>([select Resource__c from SFDC_Assignment__c where Id in :assignmentsIds]);

        Set<Date> addedDaysOff = new Set<Date>();
        Set<Date> removedDaysOff = new Set<Date>();
        Map<ID, Set<Date>> resourceAddedDaysOff = new Map<ID, Set<Date>>();
        Map<ID, Set<Date>> resourceRemovedDaysOff = new Map<ID, Set<Date>>();

        for(Integer i = 0; i < cards.size(); i++) {
            Project_Line_Item__c holidaysProjectLine = holidaysProjectLines.get(cards[i].Project_Line_Item__c);
            if(holidaysProjectLine == null) continue;

            ID resourceId = assignments.get(cards[i].Assignment__c)?.Resource__c;
            if(resourceId == null) continue;

            if(holidaysProjectLine.Name == 'FTO') {
                if(oldRecords == null) {
                    if(!resourceAddedDaysOff.containsKey(resourceId)) resourceAddedDaysOff.put(resourceId, new Set<Date>());
                    resourceAddedDaysOff.get(resourceId).add(cards[i].Date__c);
                }else if(records == null) {
                    if(!resourceRemovedDaysOff.containsKey(resourceId)) resourceRemovedDaysOff.put(resourceId, new Set<Date>());
                    resourceRemovedDaysOff.get(resourceId).add(cards[i].Date__c);
                }else {
                    resourceId = assignments.get(records[i].Assignment__c)?.Resource__c;
                    ID oldResourceId = assignments.get(oldRecords[i].Assignment__c)?.Resource__c;

                    if(resourceId != oldResourceId || records[i].Date__c != oldRecords[i].Date__c) {
                        if(records[i].Date__c != null && resourceId != null) {
                            if(!resourceAddedDaysOff.containsKey(resourceId)) resourceAddedDaysOff.put(resourceId, new Set<Date>());
                            resourceAddedDaysOff.get(resourceId).add(records[i].Date__c);
                        }
                        
                        if(oldRecords[i].Date__c != null && oldResourceId != null) {
                            if(!resourceRemovedDaysOff.containsKey(oldResourceId)) resourceRemovedDaysOff.put(oldResourceId, new Set<Date>());
                            resourceRemovedDaysOff.get(oldResourceId).add(oldRecords[i].Date__c);
                        }
                    }
                }
            }
        }

        RPRFAssignmentService.getInstance().clearDailyAssignments(addedDaysOff);
        RPRFAssignmentService.getInstance().clearDailyAssignments(resourceAddedDaysOff);
        
        if(!resourceRemovedDaysOff.isEmpty()) {
            QueueService.start('createResourceDailyAssignments', new Map<String, Object> {'data' => resourceRemovedDaysOff}, 'RPRFAssignmentService');
        }
    }*/

    private void processFTOTimecards(List<SFDC_Timecard__c> records, List<SFDC_Timecard__c> oldRecords) {
        Map<ID, Project_Line_Item__c> holidaysProjectLines = new Map<ID, Project_Line_Item__c>(RPRFResourceService.getInstance().getHolidaysProjectLines());
        
        List<SFDC_Timecard__c> cards = (records != null ? records : oldRecords);
        Set<ID> assignmentsIds = new Set<ID>();
        for(SFDC_Timecard__c card : cards) {
            assignmentsIds.add(card.Assignment__c);
        }

        if(assignmentsIds.isEmpty()) return;

        Map<ID, SFDC_Assignment__c> assignments = new Map<ID, SFDC_Assignment__c>([select Resource__c from SFDC_Assignment__c where Id in :assignmentsIds]);
        Map<ID, Set<Date>> resourcesDates = new Map<ID, Set<Date>>();

        for(Integer i = 0; i < cards.size(); i++) {
            Project_Line_Item__c holidaysProjectLine = holidaysProjectLines.get(cards[i].Project_Line_Item__c);
            if(holidaysProjectLine == null) continue;

            ID resourceId = assignments.get(cards[i].Assignment__c)?.Resource__c;
            if(resourceId == null) continue;

            if(holidaysProjectLine.Name == RPRFResourceService.PTO_PROJECT_NAME) {
                if(oldRecords == null) {
                    if(!resourcesDates.containsKey(resourceId)) resourcesDates.put(resourceId, new Set<Date>());
                    resourcesDates.get(resourceId).add(cards[i].Date__c);
                }else if(records == null) {
                    if(!resourcesDates.containsKey(resourceId)) resourcesDates.put(resourceId, new Set<Date>());
                    resourcesDates.get(resourceId).add(cards[i].Date__c);
                }else {
                    resourceId = assignments.get(records[i].Assignment__c)?.Resource__c;
                    ID oldResourceId = assignments.get(oldRecords[i].Assignment__c)?.Resource__c;

                    if(resourceId != oldResourceId || records[i].Date__c != oldRecords[i].Date__c) {
                        if(records[i].Date__c != null && resourceId != null) {
                            if(!resourcesDates.containsKey(resourceId)) resourcesDates.put(resourceId, new Set<Date>());
                            resourcesDates.get(resourceId).add(records[i].Date__c);
                        }
                        
                        if(oldRecords[i].Date__c != null && oldResourceId != null) {
                            if(!resourcesDates.containsKey(oldResourceId)) resourcesDates.put(oldResourceId, new Set<Date>());
                            resourcesDates.get(oldResourceId).add(oldRecords[i].Date__c);
                        }
                    }
                }
            }
        }

        if(resourcesDates.isEmpty()) return;

        assignments = new Map<ID, SFDC_Assignment__c>(RPRFAssignmentService.getInstance().getAssignmentsByResourcesAndDates(resourcesDates));
        if(!assignments.isEmpty()) {
            QueueService.start('recalculateProjectedHours', new List<ID>(assignments.keySet()), 'RPRFAssignmentService');
        }
    }

    private void populateDailyAssignment(List<SFDC_Timecard__c> records, List<SFDC_Timecard__c> oldRecords) {
        Map<Id, SFDC_Timecard__c> oldMap = (oldRecords == null ? new Map<Id, SFDC_Timecard__c>() : new Map<Id, SFDC_Timecard__c>(oldRecords));
        Set<Id> assignmentsIds = new Set<Id>();
        Set<Date> dates = new Set<Date>();
        
        for (SFDC_Timecard__c timecard : records) {
            SFDC_Timecard__c oldTimecard = oldMap.get(timecard.Id);
            if (timecard.Daily_Assignment__c == null || timecard.Date__c != oldTimecard?.Date__c || timecard.Assignment__c != oldTimecard?.Assignment__c) {
                if (timecard.Date__c != null) dates.add(timecard.Date__c);
                if (timecard.Assignment__c != null) assignmentsIds.add(timecard.Assignment__c);
            }
        }

        if (assignmentsIds.size() == 0 || dates.size() == 0) return;

        Map<String, Id> mapDailyAssignments = new Map<String, Id>();
        List<Daily_Assignment__c> dailyAssignments = [Select Daily_Date__c, Assignment__c From Daily_Assignment__c Where Assignment__c In :assignmentsIds And Daily_Date__c In :dates];
        for (Daily_Assignment__c dailyAssignment : dailyAssignments) {
            String key = dailyAssignment.Assignment__c + String.valueOf(dailyAssignment.Daily_Date__c);
            mapDailyAssignments.put(key, dailyAssignment.Id);
        }

        for (SFDC_Timecard__c timecard : records) {
            SFDC_Timecard__c oldTimecard = oldMap.get(timecard.Id);
            if (timecard.Daily_Assignment__c == null || timecard.Date__c != oldTimecard?.Date__c || timecard.Assignment__c != oldTimecard?.Assignment__c) {
                String key = timecard.Assignment__c + String.valueOf(timecard.Date__c);
                timecard.Daily_Assignment__c = mapDailyAssignments.get(key);
            }
        }
    }
}