/******************************************************************************
// Summary:         The trigger handler class for Timesheet__c custom object
// Test Class:      TimesheetTriggerHandlerTest

// Modification Log: (Name - Change Summary - Initial)
====================
Roman Bulgakov - 05/30/2024 - created
*******************************************************************************/

public with sharing class TimesheetTriggerHandler extends AbstractTrigger
{
    public override void afterUpdate(List<SObject> records, List<SObject> oldRecords) {
        processDailyAssignmentTimesheet((List<Timesheet__c>)records, (List<Timesheet__c>)oldRecords);
    }

    private void processDailyAssignmentTimesheet(List<Timesheet__c> records, List<Timesheet__c> oldRecords) {
        List<Timesheet__c> actualRecords = new List<Timesheet__c>();
        for(Integer i = 0; i < records.size(); i++) {
            if (records[i].Status__c != oldRecords[i].Status__c && records[i].Status__c == 'Approved') {
                actualRecords.add(records[i]);
            }
        }

        if (actualRecords.isEmpty()) return;

        RPRFAssignmentService.getInstance().processApprovedTimesheets(actualRecords);
   }    
}