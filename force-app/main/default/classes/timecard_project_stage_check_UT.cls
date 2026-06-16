@isTest
public class timecard_project_stage_check_UT {
    
    public static testmethod void TimecardTest(){
        Account a = new account(name='Test', BillingCountry = 'US', BillingState = 'AL');
        insert a;
        list<RecordType> lr=[Select Id from RecordType where SobjectType='Contact' and name='Resource'];
        
        Contact c = new Contact(LastName='Test', accountId=a.Id, RecordTypeId=lr[0].Id, MailingCountry = 'US', MailingState = 'AL');
        insert c;
        
        SFDC_Projects__c proj = new SFDC_Projects__c(Account__c=a.Id);       
        insert proj;
        
        SFDC_Assignment__c ass = new SFDC_Assignment__c(resource__c=c.Id, projects__c=proj.Id, Start_Date__c=date.today().addDays(-20), End_Date__c=date.today().addDays(20), Number_Of_Hours__c=10);
        insert ass;
        
        Project_Line_Item__c pli = new Project_Line_Item__c();
        pli.Project__c = proj.id;
        insert pli;
        
        
        SFDC_Timecard__c tc = new SFDC_Timecard__c();
        tc = new SFDC_Timecard__c(Assignment__c = ass.Id, date__c=Date.today(), Project_Line_Item__c = pli.Id);        
        insert tc;
        
        proj.Project_Stage__c='On Hold';
        update proj;
        
        tc = new SFDC_Timecard__c();
        tc = new SFDC_Timecard__c(Assignment__c = ass.Id, date__c=Date.today(), Project_Line_Item__c = pli.Id);        
        try {
        insert tc;
        } catch (System.DMLException de){
            //DML exception should be project ineligible
            system.debug(de);
        }
    }
}