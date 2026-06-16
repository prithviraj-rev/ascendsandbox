@isTest
private class timecard_summary_assignment_UT {

    static testMethod void myUnitTest() {
        Account a = new account(name='Test', BillingCountry = 'US', BillingState = 'AL');
        insert a;
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name='Resource'];
        
        Contact c = new Contact(LastName='Test', accountId=a.Id, RecordTypeId=lr[0].Id, MailingCountry = 'US', MailingState = 'AL');
        insert c;
        
        SFDC_Projects__c proj = new SFDC_Projects__c(Account__c=a.Id);       
        insert proj;
        
        SFDC_Assignment__c ass = new SFDC_Assignment__c();
        ass.resource__c=c.Id;
        ass.projects__c=proj.id;
        ass.Start_Date__c=date.today().addDays(-20); 
        ass.End_Date__c=date.today().addDays(20);
        ass.Number_Of_Hours__c=10;
        
        insert ass;
        
        Project_Line_Item__c pli = new Project_Line_Item__c();
        pli.Project__c = proj.id;
        insert pli;
        
/*      Timecard_Summary__c nts = new Timecard_Summary__c(resource__c=c.id, 
                                                            start_date__c=ass.Start_Date__c,
                                                            end_date__c=ass.end_date__c,
                                                            status__c='New');
        insert nts;
    */  
        list<SFDC_Timecard__c> tc = new list<SFDC_Timecard__c>();
        SFDC_Timecard__c tcx = new SFDC_Timecard__c();
        tcx.Assignment__c = ass.Id;
        tcx.date__c=Date.today();
        tcx.Project_Line_Item__c = pli.Id;
        tc.add(tcx);        
        tcx = new SFDC_Timecard__c();
        tcx.Assignment__c = ass.Id;
        tcx.date__c=Date.today();
        tcx.Project_Line_Item__c = pli.Id;
        tc.add(tcx);        
        insert tc;
        
        list<Timecard_Summary__c> ts = [select id, start_date__c, end_date__c, resource__c from Timecard_Summary__c where resource__c=:c.Id];
        system.debug(ts);
        list<SFDC_Timecard__c> ltc = [select id, timecard_summary__c from sfdc_timecard__c where assignment__c=:ass.Id];
        system.debug(ltc);
    }
}