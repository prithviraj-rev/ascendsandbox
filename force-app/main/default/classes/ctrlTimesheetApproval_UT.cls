@isTest
public class ctrlTimesheetApproval_UT {
    @TestSetup
    public static void TestSetup() {
        Account acct = new Account(Name = 'Test Account', BillingState = 'IL');
        insert acct;
        
        SFDC_Projects__c pjt = new SFDC_Projects__c(Name = 'Test Project', Account__c = acct.id, Start_Date__c = system.today(), Project_Stage__c = 'Active');
        insert pjt;
        
        Project_Line_Item__c pli = new Project_Line_Item__c(Name = 'Test PLI', Project__c = pjt.Id, Est_Hours__c = 20);
        insert pli;
        
        date sdate = date.parse('11/11/2019');
        
        date asdate = date.parse('11/11/2019');
        
        date aedate = date.parse('11/18/2019');
        
        date tdate = date.parse('11/12/2019');
        
        Contact ct = new Contact(FirstName = 'Test', LastName = 'User', AccountId = acct.id, recordtypeId = '01230000000p2xfAAA');
        insert ct;
        
        SFDC_Assignment__c asgn = new SFDC_Assignment__c(Name = 'Test Assignment', Projects__c = pjt.id, Start_Date__c = asdate, End_Date__c = aedate, Number_Of_Hours__c = 20, Resource__c = ct.id);
        insert asgn;
        
        
        SFDC_Timecard__c tcl = new SFDC_Timecard__c(Assignment__c = asgn.id, Date__c = tdate, Hours__c = 1, Project_Line_Item__c = pli.id);
        insert tcl;
        
    }
    
    static testMethod void TestController() {
        List<Timesheet__c> c = [SELECT Id FROM Timesheet__c];
        
        ctrlTimesheetApproval controller = new ctrlTimesheetApproval();
        
        controller.tsId = c[0].Id;
        
        decimal total = controller.gettotal();
        
        System.assert(controller.getTis().size() == 1);
        System.assert(controller.gettCards().size() == 1);
        
    }
    
}