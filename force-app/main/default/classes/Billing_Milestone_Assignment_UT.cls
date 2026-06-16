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
private class Billing_Milestone_Assignment_UT {

    static testMethod void myUnitTest() {
        Account ac = new account(name='Test', BillingState = 'IL');
        insert ac;
        SFDC_Projects__c p = new SFDC_Projects__c(Name='TEST PROJECT',Billing__c='T&M', Account__c=ac.id);
        insert p;
        Project_Line_Item__c pl = new Project_Line_Item__c(Name='TEST PROJECT LINE',Project__c=p.Id);
        insert pl;
        RecordType r = [Select Id from RecordType where Name='Resource'];
        Contact c = new Contact(LastName='Resource',FirstName='Test',RecordTypeId=r.Id);
        insert c;
        Date start=system.today();
        Date endD=system.today().addMonths(2);
        SFDC_Assignment__c a = new SFDC_Assignment__c(Projects__c=p.Id,Resource__c=c.Id,Start_Date__c=start,End_Date__c=endD);
        insert a;
        SFDC_Timecard__c t = new SFDC_Timecard__c(Name='TEST TIME CARD',Project_Line_Item__c=pl.id,Assignment__c=a.Id,date__c=start);
        insert t; 
    }
}