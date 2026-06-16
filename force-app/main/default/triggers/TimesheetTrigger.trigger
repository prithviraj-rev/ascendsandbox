trigger TimesheetTrigger on Timesheet__c (after update) {
    new TimesheetTriggerHandler().execute();
}