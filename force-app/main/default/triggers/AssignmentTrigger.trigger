trigger AssignmentTrigger on SFDC_Assignment__c (after insert, after update) {
    new AssignmentTriggerHandler().execute();
}