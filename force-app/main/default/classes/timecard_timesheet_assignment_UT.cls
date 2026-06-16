@isTest
public class timecard_timesheet_assignment_UT {

    public static testmethod void TimecardTest(){
        Account a = new account(name='Test', BillingCountry = 'US', BillingState = 'AL');
        insert a;
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name='Resource'];
        
        Contact c = new Contact(LastName='Test',FirstName='Test', accountId=a.Id, RecordTypeId=lr[0].Id, Employment_Type__c='1099', MailingCountry = 'US', MailingState = 'AL');
        insert c;
        
        Profile P = [Select Id from Profile limit 1];
        insert new User(  firstname = 'Test',
                                lastName = 'Test',
                                email = 'test.test@testTTAUT.org',
                                Username = 'test.test@testTTAUT.org',
                                EmailEncodingKey = 'ISO-8859-1',
                                Alias = 'ttast',
                                TimeZoneSidKey = 'America/Los_Angeles',
                                LocaleSidKey = 'en_US',
                                LanguageLocaleKey = 'en_US',
                       			ProfileId = p.Id,
                       			ManagerId = UserInfo.getUserId());
        
        SFDC_Projects__c proj = new SFDC_Projects__c(Account__c = a.Id);       
        insert proj;
        
        SFDC_Assignment__c sfa = new SFDC_Assignment__c(resource__c=c.Id, projects__c=proj.Id, Start_Date__c=date.today().addDays(-20), End_Date__c=date.today().addDays(20), Number_Of_Hours__c=10);
        insert sfa;
        
        Project_Line_Item__c pli = new Project_Line_Item__c();
        pli.Project__c = proj.id;
        insert pli;
        
        
        SFDC_Timecard__c tc = new SFDC_Timecard__c();
        tc = new SFDC_Timecard__c(Assignment__c = sfa.Id, date__c=Date.today(), Project_Line_Item__c = pli.Id);        
        insert tc;
        
    }
}