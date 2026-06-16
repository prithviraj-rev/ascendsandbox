@isTest
private class ctrlTimecardEntry_UT {

    static testMethod void ctrlTimecardEntryTest() {
        Account a = new account(name='Test', BillingCountry = 'US', BillingState = 'AL');
        insert a;
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name='Resource'];
        Contact c = new Contact(LastName='Test', accountId=a.Id, RecordTypeId=lr[0].Id, MailingCountry = 'US', MailingState = 'AL');
        insert c;

        SFDC_Projects__c p = new SFDC_Projects__c(name='test', Account__c = a.Id);
        insert p;
        Project_Line_Item__c pli = new Project_Line_Item__c(name='test', project__c=p.Id);
        insert pli;

        SFDC_Assignment__c ass = new SFDC_Assignment__c();
        ass.resource__c=c.Id;
        ass.Start_Date__c=date.today().addDays(-20); 
        ass.End_Date__c=date.today().addDays(20);
        ass.Number_Of_Hours__c=10;
        ass.Projects__c = p.id;
        insert ass;
        
        Contact[] cList = ctrlTimecardEntry.getResources();
        
        ctrlTimecardEntry.JoinedAssignmentLineItem[] assignmentItems = ctrlTimecardEntry.getLineItems( c.Id, ass.Start_Date__c, ass.End_Date__c );

        string timecardId = ctrlTimecardEntry.createTimecard( ass.Id, pli.Id, date.today(), 1, true, 'test class');
        
        SFDC_Timecard__c[] tcList = ctrlTimecardEntry.getTimecards(c.Id, date.today(), date.today() );
  
        ctrlTimecardEntry.updateTimecard(timecardId, 2, false, 'update description test' );
 
        //cover insert failure
        string timecardFail = ctrlTimecardEntry.createTimecard( a.Id, pli.Id, date.today(), 1, true, 'test class');
    
 
     }
}