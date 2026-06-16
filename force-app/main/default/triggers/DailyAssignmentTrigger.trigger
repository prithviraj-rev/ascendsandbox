trigger DailyAssignmentTrigger on Daily_Assignment__c (before update, before delete, after insert, after update) {
    new DailyAssignmentTriggerHandler().execute();
}