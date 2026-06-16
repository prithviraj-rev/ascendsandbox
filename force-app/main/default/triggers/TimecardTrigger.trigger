trigger TimecardTrigger on SFDC_Timecard__c (before insert, before update, after insert, after update, after delete) {
    new TimecardTriggerHandler().execute();
}