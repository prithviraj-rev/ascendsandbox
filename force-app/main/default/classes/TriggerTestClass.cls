/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class TriggerTestClass {

    static testMethod void Assignment_DailyAssignment_Trigger() {
    	Date s=date.newinstance(2013,12,22);
    	Date e=date.newinstance(2013,12,27);
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' limit 1];
        Id i=lr[0].id;
        Contact c=new Contact(RecordTypeId=i, LastName='ADAT_Test_Resource_Contact');
        insert c;
        SFDC_Assignment__c assign=new SFDC_Assignment__c(Start_Date__c=s, End_Date__c=e, Resource__c=c.Id,Number_Of_Hours__c=10);
        insert assign; 
        assign.End_Date__c=e.addDays(2);
        update assign;
    }
}