/******************************************************************************
// Summary:         The trigger handler class for SFDC_Assignment__c custom object
// Test Class:      AssignmentTriggerHandlerTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 05/09/2024 - created
*******************************************************************************/

public with sharing class AssignmentTriggerHandler extends AbstractTrigger
{
    public override void afterInsert(List<SObject> records) {
    	processDailyAssignments((List<SFDC_Assignment__c>)records, null);
    }

    public override void afterUpdate(List<SObject> records, List<SObject> oldRecords) {
    	processDailyAssignments((List<SFDC_Assignment__c>)records, (List<SFDC_Assignment__c>)oldRecords);
    }
    
    private void processDailyAssignments(List<SFDC_Assignment__c> records, List<SFDC_Assignment__c> oldRecords) {
        List<ID> assignmentsIds = new List<ID>();
        for(Integer i = 0; i < records.size(); i++) {
            if(records[i].Inactive__c == true) continue;

            if(oldRecords == null || records[i].Resource__c != oldRecords[i].Resource__c || records[i].Number_Of_Hours__c != oldRecords[i].Number_Of_Hours__c ||
                records[i].Daily_Max__c != oldRecords[i].Daily_Max__c || records[i].Start_Date__c != oldRecords[i].Start_Date__c || records[i].End_Date__c != oldRecords[i].End_Date__c) 
            {
                assignmentsIds.add(records[i].Id);
            }
        }

        if(!assignmentsIds.isEmpty()) {
            QueueService.start('recalculateProjectedHours', assignmentsIds, 'RPRFAssignmentService');
        }
    }
}